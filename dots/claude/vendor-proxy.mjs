/**
 * vendor-proxy — prove what a gateway did to your request.
 *
 * A zero-dependency recording proxy for debugging a *misbehaving* upstream —
 * the corporate/vendor gateway that fronts Bedrock and exposes it as both
 * `/anthropic/v1/messages` and `/openai/v1/chat/completions`. It forwards every
 * byte untouched, streams the reply straight back so your agent is unaffected,
 * and captures the exchange verbatim: raw request, raw response, response
 * headers, and per-chunk arrival timings.
 *
 * Then it runs conformance checks and tells you what the gateway got wrong:
 * missing token usage, dropped reasoning, prompt caching that silently no-ops,
 * malformed SSE, buffered "streaming".
 *
 * Every finding is provable from the capture alone — there is no known-good
 * upstream to compare against, so a check either proves fault from a single
 * exchange or from two consecutive ones. Nothing here needs a reference server.
 *
 * Run:
 *   UPSTREAM_URL=https://gateway.corp.example node vendor-proxy.mjs
 *
 * Point clients at it, keeping whatever subpath they already use:
 *   ANTHROPIC_BASE_URL=http://localhost:8788/anthropic  claude
 *   OPENAI_BASE_URL=http://localhost:8788/openai/v1     <other agent>
 *
 * The incoming path is appended to UPSTREAM_URL's path, so pointing at the
 * gateway *root* lets one proxy serve every API shape at once.
 *
 * Env:
 *   UPSTREAM_URL   gateway base URL (required in practice; default: Anthropic)
 *   PORT           listen port (default 8788)
 *   LOG_DIR        capture directory (default ./logs-vendor)
 *   QUIET=1        suppress the per-request console summary
 *   NODE_EXTRA_CA_CERTS=/path/corp-ca.pem   for TLS-intercepting networks
 *
 * Zero runtime dependencies — Node built-ins only. Requires Node 18+.
 */

import http from "node:http";
import https from "node:https";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const PORT = Number(process.env.PORT ?? 8788);
const UPSTREAM = new URL(process.env.UPSTREAM_URL ?? "https://api.anthropic.com");
const HERE = path.dirname(fileURLToPath(import.meta.url));
const LOG_DIR = process.env.LOG_DIR ?? path.join(HERE, "logs-vendor");
const QUIET = process.env.QUIET === "1";

/** Header values that must never reach disk. Applies to the raw capture too —
 * these files are evidence you may end up pasting into a vendor ticket. */
const REDACT = new Set(["authorization", "x-api-key", "api-key", "proxy-authorization", "cookie", "set-cookie"]);

const sha = (s) => crypto.createHash("sha256").update(s).digest("hex").slice(0, 12);
const bytes = (n) => `${n.toLocaleString()} B`;
const ms = (n) => `${Math.round(n)} ms`;

// ---------------------------------------------------------------------------
// Findings — the vocabulary of "what the gateway got wrong"
// ---------------------------------------------------------------------------

/**
 * Codes are stable and greppable: `grep cache.stable_prefix_no_hit index.jsonl`
 * across a session is how you catch an *intermittent* fault.
 *
 * Findings collapse by code. A structural fault in an SSE stream is per-frame by
 * nature — one missing `event:` line means all 200 are missing — and reporting
 * it 200 times buries every other finding. One line with a count says the same
 * thing, and the first few instances are kept so the report still shows where.
 */
function newFindings() {
  const list = [];
  const byCode = new Map();
  const add = (level) => (code, msg, detail) => {
    const seen = byCode.get(code);
    if (seen) {
      seen.count++;
      if (seen.others.length < 4 && msg !== seen.msg) seen.others.push(msg);
      return;
    }
    const entry = { level, code, msg, detail, count: 1, others: [] };
    byCode.set(code, entry);
    list.push(entry);
  };
  return { list, fail: add("fail"), warn: add("warn"), info: add("info") };
}

const LEVEL_MARK = { fail: "✗", warn: "!", info: "·" };
const LEVEL_RANK = { fail: 0, warn: 1, info: 2 };

// ---------------------------------------------------------------------------
// SSE parsing — offsets and arrival times included
// ---------------------------------------------------------------------------

/**
 * Parse an SSE stream into frames, carrying each frame's byte offset so we can
 * map it back to the network chunk it arrived in.
 *
 * This deliberately keeps the `event:` name separate from the JSON payload.
 * A gateway that re-serialises events often drops the name or lets it drift out
 * of sync with `data.type` — invisible if you only parse `data:` lines, fatal to
 * SDKs that dispatch on the event name.
 */
function parseSSE(text) {
  const frames = [];
  const re = /\r?\n\r?\n/g;
  let start = 0, m, offset = 0;

  const pushFrame = (raw, sep, unterminated) => {
    const frame = { data: null, event: null, comments: [], unknownFields: [], raw, unterminated };
    const dataLines = [];
    for (const line of raw.split(/\r?\n/)) {
      if (line === "") continue;
      if (line.startsWith(":")) { frame.comments.push(line.slice(1).trim()); continue; }
      const idx = line.indexOf(":");
      const field = idx === -1 ? line : line.slice(0, idx);
      const value = idx === -1 ? "" : line.slice(idx + 1).replace(/^ /, "");
      if (field === "data") dataLines.push(value);
      else if (field === "event") frame.event = value;
      else if (field === "id" || field === "retry") { /* spec fields, ignored */ }
      else frame.unknownFields.push(field);
    }
    frame.dataRaw = dataLines.join("\n");
    if (frame.dataRaw !== "" || frame.event) {
      frame.byteEnd = offset + Buffer.byteLength(raw) + Buffer.byteLength(sep);
      if (frame.dataRaw && frame.dataRaw !== "[DONE]") {
        try { frame.data = JSON.parse(frame.dataRaw); } catch (e) { frame.parseError = e.message; }
      }
      frames.push(frame);
    }
    offset += Buffer.byteLength(raw) + Buffer.byteLength(sep);
  };

  while ((m = re.exec(text))) {
    pushFrame(text.slice(start, m.index), m[0], false);
    start = re.lastIndex;
  }
  if (start < text.length) pushFrame(text.slice(start), "", true);
  return frames;
}

/** Stamp each frame with the wall-clock time of the network chunk that completed
 * it. If every frame lands in one chunk, the gateway buffered the stream. */
function attachArrival(frames, chunkLog) {
  let ci = 0, cum = 0;
  const bounds = chunkLog.map((c) => (cum += c.size));
  for (const f of frames) {
    while (ci < bounds.length - 1 && bounds[ci] < f.byteEnd) ci++;
    f.arrival = chunkLog[ci]?.t ?? 0;
    f.chunkIndex = ci;
  }
}

// ---------------------------------------------------------------------------
// Prefix segmentation — the basis of every caching verdict
// ---------------------------------------------------------------------------

/**
 * Break a request into the ordered segments a cache prefix is built from.
 * Anthropic caches on `tools → system → messages`, in that order, so a byte
 * change anywhere invalidates everything after it. Hashing per segment lets us
 * report *where* a prefix diverged rather than merely that it did.
 */
function anthropicSegments(req) {
  const segs = [];
  const push = (label, value, cache) =>
    segs.push({ label, text: JSON.stringify(value ?? null), cache: !!cache });

  for (const [i, t] of (req.tools ?? []).entries()) push(`tool[${i}] ${t?.name ?? "?"}`, t, t?.cache_control);
  if (typeof req.system === "string") push("system", req.system, false);
  else if (Array.isArray(req.system)) req.system.forEach((b, i) => push(`system[${i}]`, b, b?.cache_control));
  else if (req.system) push("system", req.system, req.system?.cache_control);

  for (const [i, msg] of (req.messages ?? []).entries()) {
    if (Array.isArray(msg?.content)) {
      msg.content.forEach((b, j) => push(`msg[${i}].${j} ${msg.role}/${b?.type ?? "?"}`, b, b?.cache_control));
    } else {
      push(`msg[${i}] ${msg?.role ?? "?"}`, msg?.content, false);
    }
  }
  return segs;
}

/** OpenAI has no explicit breakpoints — caching is automatic on the longest
 * common prefix, which makes "where did it diverge" the *only* diagnostic. */
function openaiSegments(req) {
  const segs = [];
  const push = (label, value) => segs.push({ label, text: JSON.stringify(value ?? null), cache: false });
  for (const [i, t] of (req.tools ?? []).entries()) push(`tool[${i}] ${t?.function?.name ?? t?.name ?? "?"}`, t);
  for (const [i, m] of (req.messages ?? []).entries()) push(`msg[${i}] ${m?.role ?? "?"}`, m);
  return segs;
}

/** Remembers the previous request per conversation so we can diff prefixes.
 * Keyed by flavor+model+first-segment hash, which keeps a subagent's traffic
 * from being mistaken for the main agent's. In memory only — restarting the
 * proxy simply costs you one baseline request. */
const prefixMemory = new Map();

function diffPrefix(flavor, model, segs) {
  if (!segs.length) return null;
  const hashes = segs.map((s) => sha(s.text));
  const sizes = segs.map((s) => Buffer.byteLength(s.text));
  const total = sizes.reduce((a, b) => a + b, 0);
  const key = `${flavor}|${model}|${hashes[0]}`;
  const prev = prefixMemory.get(key);
  prefixMemory.set(key, { hashes, sizes, labels: segs.map((s) => s.label) });

  if (!prev) return { baseline: true, total, segments: segs.length };

  let common = 0;
  while (common < hashes.length && common < prev.hashes.length && hashes[common] === prev.hashes[common]) common++;
  const commonBytes = sizes.slice(0, common).reduce((a, b) => a + b, 0);
  return {
    baseline: false,
    total,
    segments: segs.length,
    common,
    commonBytes,
    reusablePct: total ? (commonBytes / total) * 100 : 0,
    divergedAt: common < hashes.length ? segs[common].label : null,
    prevLabelAt: common < prev.labels.length ? prev.labels[common] : null,
    prevSegments: prev.hashes.length,
  };
}

// ---------------------------------------------------------------------------
// Anthropic /v1/messages analysis
// ---------------------------------------------------------------------------

const ANTHROPIC_EVENTS = new Set([
  "message_start", "message_delta", "message_stop", "content_block_start",
  "content_block_delta", "content_block_stop", "ping", "error",
]);

function analyzeAnthropic(req, resp, f) {
  const segs = anthropicSegments(req);
  const breakpoints = segs.map((s, i) => (s.cache ? i : -1)).filter((i) => i >= 0);
  const prefix = diffPrefix("anthropic", req?.model ?? "?", segs);

  const wantsStream = req?.stream === true;
  const isSSE = (resp.contentType ?? "").includes("text/event-stream");
  let usage = null, stopReason = null, thinkingBlocks = 0, signedThinking = 0, textBlocks = 0, toolUses = 0;

  if (resp.status >= 400) {
    checkErrorShape(resp, f, "anthropic");
  } else if (wantsStream && !isSSE) {
    f.fail("stream.not_streamed", `stream:true requested but response content-type is "${resp.contentType ?? "(none)"}"`);
  }

  if (isSSE) {
    const frames = resp.frames;
    ({ usage, stopReason, thinkingBlocks, signedThinking, textBlocks, toolUses } = anthropicStreamChecks(req, frames, f));
    checkBuffering(resp, frames, f);
  } else if (resp.status < 400) {
    const body = resp.json;
    if (!body) {
      f.fail("body.unparseable", "non-streaming response body is not JSON", resp.text.slice(0, 400));
    } else {
      usage = body.usage ?? null;
      stopReason = body.stop_reason ?? null;
      for (const b of body.content ?? []) {
        if (b?.type === "thinking") { thinkingBlocks++; if (b.signature) signedThinking++; }
        if (b?.type === "text") textBlocks++;
        if (b?.type === "tool_use") toolUses++;
      }
      for (const field of ["id", "model", "role", "content", "stop_reason", "usage"]) {
        if (body[field] === undefined) f.fail("body.missing_field", `response is missing required field "${field}"`);
      }
      if (!usage) f.fail("usage.absent", "no usage object on the response");
      checkServedModel(req?.model, body.model, f);
    }
  }

  checkAnthropicUsage(usage, breakpoints.length, prefix, f);
  checkAnthropicThinking(req, thinkingBlocks, signedThinking, f);
  checkThinkingRoundTrip(req, f);

  return { usage, stopReason, prefix, breakpoints, segs, blocks: { thinkingBlocks, textBlocks, toolUses } };
}

/** Walk the event stream as a state machine. The Anthropic stream has a strict
 * shape; SDKs assume it. Each violation here is a concrete line for a ticket. */
function anthropicStreamChecks(req, frames, f) {
  let usage = null, stopReason = null, served = null;
  let thinkingBlocks = 0, signedThinking = 0, textBlocks = 0, toolUses = 0;
  const openBlocks = new Map();
  const seen = [];
  let nextIndex = 0;

  for (const [i, fr] of frames.entries()) {
    if (fr.dataRaw === "[DONE]") {
      f.warn("sse.done_sentinel", "stream sends `data: [DONE]`; the Anthropic API does not — SDKs ignore it, but it signals an OpenAI-shaped translation layer");
      continue;
    }
    if (fr.parseError) { f.fail("sse.bad_json", `frame ${i} has unparseable JSON data`, fr.parseError); continue; }
    if (!fr.data) continue;
    const type = fr.data.type;
    seen.push(type);

    if (!fr.event) f.fail("sse.no_event_name", `frame ${i} (${type}) has no \`event:\` line — SDKs dispatching on event name will drop it`);
    else if (fr.event !== type) f.fail("sse.event_name_mismatch", `frame ${i}: \`event: ${fr.event}\` but \`data.type: ${type}\``);
    if (!ANTHROPIC_EVENTS.has(type)) f.warn("sse.unknown_event", `frame ${i}: unrecognised event type "${type}"`);
    if (fr.unterminated) f.fail("sse.truncated", `stream ends mid-frame (frame ${i}, ${type}) — the connection was cut before the frame terminator`);
    if (fr.unknownFields.length) f.warn("sse.unknown_field", `frame ${i} has non-spec SSE fields: ${fr.unknownFields.join(", ")}`);

    switch (type) {
      case "message_start":
        if (i !== 0) f.fail("sse.order", `message_start is frame ${i}, must be first`);
        served = fr.data.message?.model ?? null;
        if (fr.data.message?.usage) usage = { ...fr.data.message.usage };
        else f.fail("usage.no_message_start_usage", "message_start carries no usage — input/cache token counts are lost here");
        break;
      case "content_block_start": {
        const idx = fr.data.index;
        if (idx !== nextIndex) f.warn("sse.index_gap", `content_block_start index ${idx}, expected ${nextIndex}`);
        nextIndex = idx + 1;
        const bt = fr.data.content_block?.type;
        openBlocks.set(idx, { type: bt, signature: false });
        if (bt === "thinking") thinkingBlocks++;
        if (bt === "text") textBlocks++;
        if (bt === "tool_use") toolUses++;
        break;
      }
      case "content_block_delta": {
        const blk = openBlocks.get(fr.data.index);
        if (!blk) f.fail("sse.delta_without_start", `content_block_delta for index ${fr.data.index} with no matching content_block_start`);
        else if (fr.data.delta?.type === "signature_delta" && fr.data.delta.signature) { blk.signature = true; }
        break;
      }
      case "content_block_stop":
        if (!openBlocks.has(fr.data.index)) f.fail("sse.stop_without_start", `content_block_stop for unopened index ${fr.data.index}`);
        else {
          const blk = openBlocks.get(fr.data.index);
          if (blk.type === "thinking" && blk.signature) signedThinking++;
          openBlocks.delete(fr.data.index);
        }
        break;
      case "message_delta":
        if (fr.data.delta?.stop_reason) stopReason = fr.data.delta.stop_reason;
        if (fr.data.usage) usage = { ...(usage ?? {}), ...fr.data.usage };
        else f.fail("usage.no_message_delta_usage", "message_delta carries no usage — output_tokens are lost here");
        break;
      case "error":
        f.fail("stream.error_event", `stream carried an error event: ${JSON.stringify(fr.data.error ?? fr.data)}`);
        break;
    }
  }

  if (seen[0] !== "message_start") f.fail("sse.no_message_start", "stream never sent message_start");
  if (seen[seen.length - 1] !== "message_stop") f.fail("sse.no_message_stop", `stream ends with "${seen[seen.length - 1] ?? "(nothing)"}", not message_stop`);
  if (openBlocks.size) f.fail("sse.unclosed_block", `${openBlocks.size} content block(s) never received content_block_stop: indexes ${[...openBlocks.keys()].join(", ")}`);
  if (!seen.includes("message_delta")) f.fail("sse.no_message_delta", "stream never sent message_delta — no stop_reason and no output token count");
  if (!stopReason) f.fail("stop.absent", "no stop_reason anywhere in the stream");
  checkServedModel(req?.model, served, f);

  return { usage, stopReason, thinkingBlocks, signedThinking, textBlocks, toolUses };
}

/**
 * The caching verdict. Assigning blame needs two facts we already have: whether
 * you asked for caching, and whether the prefix you sent was byte-stable since
 * the last request. Stable prefix + zero reads is the gateway; unstable prefix
 * is your client. Nothing else can produce a cache miss.
 */
function checkAnthropicUsage(usage, breakpointCount, prefix, f) {
  if (!usage) return;
  const has = (k) => usage[k] !== undefined && usage[k] !== null;

  if (!has("input_tokens")) f.fail("usage.no_input_tokens", "usage has no input_tokens");
  if (!has("output_tokens")) f.fail("usage.no_output_tokens", "usage has no output_tokens");

  const cacheFields = has("cache_read_input_tokens") || has("cache_creation_input_tokens");
  if (breakpointCount > 0 && !cacheFields) {
    f.fail("cache.no_usage_fields",
      `${breakpointCount} cache_control breakpoint(s) sent, but usage reports neither cache_read_input_tokens nor cache_creation_input_tokens — the gateway is not surfacing cache accounting`);
  }

  const read = usage.cache_read_input_tokens ?? 0;
  const created = usage.cache_creation_input_tokens ?? 0;

  if (breakpointCount > 0 && prefix && !prefix.baseline) {
    const stableThroughFirstBreakpoint = prefix.common >= 1 && prefix.reusablePct > 0;
    if (stableThroughFirstBreakpoint && read === 0 && created === 0 && cacheFields) {
      f.fail("cache.stable_prefix_no_hit",
        `prefix was byte-identical for the first ${prefix.common} of ${prefix.segments} segments (${prefix.reusablePct.toFixed(1)}% reusable) yet cache_read and cache_creation are both 0 — a stable prefix cannot miss on a conforming server`);
    } else if (!stableThroughFirstBreakpoint && read === 0) {
      f.warn("cache.prefix_unstable",
        `cache miss with a prefix that diverged at segment 0 — the client changed the very start of the request, so no cache could apply`);
    } else if (read > 0) {
      f.info("cache.hit", `cache_read_input_tokens=${read.toLocaleString()}`);
    }
  }

  if (prefix && !prefix.baseline && prefix.divergedAt && read === 0 && created > 0) {
    f.info("cache.write_only", `cache written (${created.toLocaleString()} tokens) but nothing read; prefix diverged at ${prefix.divergedAt}`);
  }
}

function checkAnthropicThinking(req, thinkingBlocks, signedThinking, f) {
  const wants = req?.thinking?.type === "enabled";
  if (!wants) return;
  if (thinkingBlocks === 0) {
    f.fail("think.absent",
      `thinking enabled (budget ${req.thinking.budget_tokens ?? "?"}) but the response contains no thinking blocks — the gateway dropped reasoning`);
  } else if (signedThinking === 0) {
    f.fail("think.unsigned",
      `${thinkingBlocks} thinking block(s) returned without a signature — these cannot be replayed on the next turn, which is what makes reasoning appear to work once and then break`);
  }
}

/** A missing signature only hurts on the *following* request, which is why this
 * class of bug looks intermittent. Catch it on the way out, too. */
function checkThinkingRoundTrip(req, f) {
  let unsigned = 0, total = 0;
  for (const m of req?.messages ?? []) {
    if (m?.role !== "assistant" || !Array.isArray(m.content)) continue;
    for (const b of m.content) {
      if (b?.type !== "thinking") continue;
      total++;
      if (!b.signature) unsigned++;
    }
  }
  if (unsigned) {
    f.warn("think.unsigned_in_history",
      `${unsigned} of ${total} assistant thinking block(s) in the request history have no signature — a previous response lost them`);
  }
}

// ---------------------------------------------------------------------------
// OpenAI /v1/chat/completions analysis
// ---------------------------------------------------------------------------

function analyzeOpenAI(req, resp, f) {
  const segs = openaiSegments(req);
  const prefix = diffPrefix("openai", req?.model ?? "?", segs);
  const wantsStream = req?.stream === true;
  const isSSE = (resp.contentType ?? "").includes("text/event-stream");
  let usage = null, finishReason = null, reasoningSeen = false, toolCalls = 0, textLen = 0;

  if (resp.status >= 400) {
    checkErrorShape(resp, f, "openai");
  } else if (wantsStream && !isSSE) {
    f.fail("stream.not_streamed", `stream:true requested but response content-type is "${resp.contentType ?? "(none)"}"`);
  }

  if (isSSE) {
    ({ usage, finishReason, reasoningSeen, toolCalls, textLen } = openaiStreamChecks(req, resp.frames, f));
    checkBuffering(resp, resp.frames, f);
  } else if (resp.status < 400) {
    const body = resp.json;
    if (!body) {
      f.fail("body.unparseable", "non-streaming response body is not JSON", resp.text.slice(0, 400));
    } else {
      usage = body.usage ?? null;
      const choice = body.choices?.[0];
      finishReason = choice?.finish_reason ?? null;
      reasoningSeen = !!(choice?.message?.reasoning_content ?? choice?.message?.reasoning);
      toolCalls = choice?.message?.tool_calls?.length ?? 0;
      textLen = (choice?.message?.content ?? "").length;
      if (!body.choices?.length) f.fail("body.no_choices", "response has no choices array");
      if (!finishReason) f.fail("stop.absent", "choices[0].finish_reason is missing");
      if (!usage) f.fail("usage.absent", "no usage object on a non-streaming response — this is unconditionally required");
    }
  }

  checkOpenAIUsage(req, usage, prefix, f);
  checkOpenAIReasoning(req, reasoningSeen, f);

  return { usage, finishReason, prefix, segs, blocks: { toolCalls, textLen, reasoningSeen } };
}

function openaiStreamChecks(req, frames, f) {
  let usage = null, finishReason = null, reasoningSeen = false, toolCalls = 0, textLen = 0;
  let sawDone = false, chunkCount = 0, sawRole = false, id = null, served = null;

  for (const [i, fr] of frames.entries()) {
    if (fr.dataRaw === "[DONE]") { sawDone = true; continue; }
    if (sawDone) f.fail("sse.data_after_done", `frame ${i} arrives after \`data: [DONE]\``);
    if (fr.parseError) { f.fail("sse.bad_json", `frame ${i} has unparseable JSON data`, fr.parseError); continue; }
    if (!fr.data) continue;
    if (fr.unterminated) f.fail("sse.truncated", `stream ends mid-frame (frame ${i}) — connection cut before the frame terminator`);

    const d = fr.data;
    chunkCount++;
    if (d.object && d.object !== "chat.completion.chunk") f.warn("body.object_type", `chunk ${i} has object "${d.object}", expected "chat.completion.chunk"`);
    for (const field of ["id", "model", "choices"]) {
      if (d[field] === undefined && !(field === "choices" && d.usage)) {
        f.warn("body.missing_field", `chunk ${i} is missing "${field}"`);
      }
    }
    if (id && d.id && d.id !== id) f.warn("body.id_drift", `chunk ${i} changes the completion id (${id} → ${d.id})`);
    id ??= d.id; served ??= d.model;

    if (d.usage) usage = { ...(usage ?? {}), ...d.usage };
    const choice = d.choices?.[0];
    if (!choice) continue;
    const delta = choice.delta ?? {};
    if (delta.role) sawRole = true;
    if (typeof delta.content === "string") textLen += delta.content.length;
    if (delta.reasoning_content || delta.reasoning) reasoningSeen = true;
    if (delta.tool_calls?.length) toolCalls = Math.max(toolCalls, ...delta.tool_calls.map((t) => (t.index ?? 0) + 1));
    if (choice.finish_reason) finishReason = choice.finish_reason;
  }

  if (!chunkCount) f.fail("sse.empty", "SSE response contained no data chunks");
  if (!sawDone) f.fail("sse.no_done", "stream never sent `data: [DONE]` — clients that wait for it will hang");
  if (!sawRole) f.warn("sse.no_role_delta", "no chunk carried delta.role — the first chunk should announce the assistant role");
  if (!finishReason) f.fail("stop.absent", "no chunk carried a finish_reason");
  checkServedModel(req?.model, served, f);

  return { usage, finishReason, reasoningSeen, toolCalls, textLen };
}

/**
 * OpenAI streaming omits usage *by design* unless the client opts in. Half of
 * all "the gateway lost my token counts" reports are actually a missing
 * `stream_options.include_usage` — so separate the two cases before blaming
 * anyone. The verdict differs: one is your client, the other is the gateway.
 */
function checkOpenAIUsage(req, usage, prefix, f) {
  const streaming = req?.stream === true;
  const askedForUsage = req?.stream_options?.include_usage === true;

  if (streaming && !askedForUsage) {
    f.info("usage.not_requested", "streaming request did not set stream_options.include_usage — per spec no usage will be sent; this is the client's omission, not the gateway's");
  } else if (streaming && askedForUsage && !usage) {
    f.fail("usage.include_usage_ignored", "stream_options.include_usage was true but no chunk carried a usage object — the gateway dropped it");
  }

  if (!usage) return;
  for (const k of ["prompt_tokens", "completion_tokens", "total_tokens"]) {
    if (usage[k] === undefined || usage[k] === null) f.fail("usage.missing_field", `usage has no ${k}`);
  }
  const cached = usage.prompt_tokens_details?.cached_tokens;
  if (cached === undefined) {
    if (prefix && !prefix.baseline && prefix.reusablePct > 50) {
      f.warn("cache.no_usage_fields",
        `${prefix.reusablePct.toFixed(1)}% of the prompt prefix was byte-identical to the previous request, but usage carries no prompt_tokens_details.cached_tokens — caching is either off or unreported`);
    }
  } else if (prefix && !prefix.baseline) {
    if (cached === 0 && prefix.reusablePct > 50) {
      f.fail("cache.stable_prefix_no_hit",
        `${prefix.common} of ${prefix.segments} leading segments were byte-identical to the previous request (${prefix.reusablePct.toFixed(1)}% of the prompt) yet cached_tokens is 0`);
    } else if (cached > 0) {
      f.info("cache.hit", `cached_tokens=${cached.toLocaleString()}`);
    }
  }
}

function checkOpenAIReasoning(req, reasoningSeen, f) {
  const wants = req?.reasoning_effort != null || req?.reasoning != null || req?.thinking != null;
  if (wants && !reasoningSeen) {
    f.fail("think.absent", "reasoning was requested but no chunk carried reasoning_content — the gateway dropped it");
  }
}

// ---------------------------------------------------------------------------
// Shared checks
// ---------------------------------------------------------------------------

/**
 * Did the gateway serve the model you asked for? Bedrock rewrites model ids
 * (`claude-sonnet-4` → `anthropic.claude-sonnet-4-...-v1:0`), so a literal
 * comparison is useless — but a *silent substitution* to a different model
 * family or version is a fault worth seeing, and it shows up as neither side
 * containing the other's distinguishing tokens.
 */
function checkServedModel(requested, served, f) {
  if (!requested || !served) return;
  const norm = (s) => String(s).toLowerCase().replace(/^(anthropic|us|eu|apac)\./, "").replace(/-v\d+:\d+$/, "");
  const [a, b] = [norm(requested), norm(served)];
  if (a === b || a.includes(b) || b.includes(a)) return;
  f.warn("model.substituted", `requested "${requested}" but the response reports "${served}"`);
}

/** A gateway that leaks a raw ALB/Bedrock error breaks client retry logic, which
 * keys off the error *shape*, not the status code. */
function checkErrorShape(resp, f, flavor) {
  const body = resp.json;
  if (!body) {
    f.fail("error.not_json", `HTTP ${resp.status} body is not JSON — clients cannot classify this error`, resp.text.slice(0, 400));
    return;
  }
  if (flavor === "anthropic") {
    if (body.type !== "error" || !body.error?.type || !body.error?.message) {
      f.fail("error.wrong_shape", `HTTP ${resp.status} is not Anthropic-shaped {type:"error",error:{type,message}}`, JSON.stringify(body).slice(0, 400));
    } else {
      f.info("error.upstream", `HTTP ${resp.status} ${body.error.type}: ${body.error.message}`);
    }
  } else {
    if (!body.error?.message) {
      f.fail("error.wrong_shape", `HTTP ${resp.status} is not OpenAI-shaped {error:{message,type,code}}`, JSON.stringify(body).slice(0, 400));
    } else {
      f.info("error.upstream", `HTTP ${resp.status} ${body.error.type ?? "?"}: ${body.error.message}`);
    }
  }
}

/** "Streaming" that arrives in one or two network chunks was buffered upstream.
 * The tell is the ratio of SSE frames to TCP chunks, plus a TTFB that sits
 * suspiciously close to the total duration. */
function checkBuffering(resp, frames, f) {
  const chunks = resp.chunkLog.length;
  if (frames.length >= 5 && chunks <= 2) {
    f.fail("stream.buffered",
      `${frames.length} SSE events arrived in ${chunks} network chunk(s) — the gateway buffered the whole response and flushed it at the end, so nothing actually streamed`);
  }
  if (resp.totalMs > 500 && resp.ttfbMs / resp.totalMs > 0.9 && frames.length >= 5) {
    f.warn("stream.late_first_byte",
      `first byte at ${ms(resp.ttfbMs)} of ${ms(resp.totalMs)} total (${((resp.ttfbMs / resp.totalMs) * 100).toFixed(0)}%) — the response was effectively complete before it started arriving`);
  }
}

// ---------------------------------------------------------------------------
// Report rendering
// ---------------------------------------------------------------------------

const fenceJson = (v) => "```json\n" + JSON.stringify(v, null, 2) + "\n```";

function renderFindings(list) {
  if (!list.length) return "_No findings._";
  const sorted = [...list].sort((a, b) => LEVEL_RANK[a.level] - LEVEL_RANK[b.level]);
  return sorted
    .map((x) => {
      const head = `- **${LEVEL_MARK[x.level]} \`${x.code}\`**${x.count > 1 ? ` ×${x.count}` : ""} — ${x.msg}`;
      const more = x.others.length ? x.others.map((m) => `\n  - ${m}`).join("") + (x.count > x.others.length + 1 ? `\n  - _…and ${x.count - x.others.length - 1} more_` : "") : "";
      const detail = x.detail ? `\n  \`\`\`\n  ${String(x.detail).replace(/\n/g, "\n  ")}\n  \`\`\`` : "";
      return head + more + detail;
    })
    .join("\n");
}

function renderPrefix(prefix, breakpoints, segs) {
  if (!prefix) return "_No segmentable prefix._";
  if (prefix.baseline) {
    return `_Baseline_: first request seen for this conversation (${prefix.segments} segments, ${bytes(prefix.total)}). Caching verdicts start with the next request.`;
  }
  const lines = [
    `- **stable prefix**: ${prefix.common} of ${prefix.segments} segments, ${bytes(prefix.commonBytes)} of ${bytes(prefix.total)} (**${prefix.reusablePct.toFixed(1)}% reusable**)`,
  ];
  if (prefix.divergedAt) {
    lines.push(`- **first divergence**: \`${prefix.divergedAt}\`` + (prefix.prevLabelAt && prefix.prevLabelAt !== prefix.divergedAt ? ` (previous request had \`${prefix.prevLabelAt}\` here)` : ""));
  } else {
    lines.push(`- **first divergence**: none — this request's prefix fully contains the previous one`);
  }
  if (breakpoints?.length) {
    lines.push(`- **cache_control breakpoints**: ${breakpoints.length} at segment(s) ${breakpoints.join(", ")}` +
      breakpoints.map((b) => `\n  - segment ${b} \`${segs[b].label}\` — prefix ${b < prefix.common ? "**stable** → a hit is required" : "**changed** → a miss is expected"}`).join(""));
  }
  return lines.join("\n");
}

function renderAnthropicRequest(req) {
  const parts = [];
  const sys = typeof req.system === "string" ? req.system
    : Array.isArray(req.system) ? req.system.map((b) => (typeof b?.text === "string" ? b.text : JSON.stringify(b))).join("\n\n")
    : req.system ? JSON.stringify(req.system) : null;
  if (sys) parts.push("### system\n\n" + "```\n" + sys + "\n```");
  if (req.tools?.length) {
    parts.push("### tools\n\n" + req.tools.map((t) => `- \`${t?.name ?? "?"}\` — ${bytes(Buffer.byteLength(JSON.stringify(t)))}`).join("\n") + "\n\n_Full schemas are in `request.json`._");
  }
  parts.push("### messages\n\n" + (req.messages ?? []).map((m, i) => {
    const body = Array.isArray(m.content)
      ? m.content.map((b) => renderAnthropicBlock(b)).join("\n\n")
      : String(m.content ?? "");
    return `<message index="${i}" role="${m.role}">\n\n${body}\n\n</message>`;
  }).join("\n\n"));
  return parts.join("\n\n");
}

function renderAnthropicBlock(b) {
  switch (b?.type) {
    case "text": return b.text ?? "";
    case "thinking": return `<thinking signature="${b.signature ? "present" : "MISSING"}">\n\n${b.thinking ?? ""}\n\n</thinking>`;
    case "tool_use": return `<tool-use name="${b.name}" id="${b.id ?? ""}">\n\n${fenceJson(b.input ?? {})}\n\n</tool-use>`;
    case "tool_result": {
      const inner = typeof b.content === "string" ? b.content
        : Array.isArray(b.content) ? b.content.map((x) => (x?.type === "text" ? x.text : `\`[${x?.type}]\``)).join("\n\n")
        : JSON.stringify(b.content);
      return `<tool-result id="${b.tool_use_id ?? ""}" is-error="${!!b.is_error}">\n\n${inner}\n\n</tool-result>`;
    }
    case "image": return `\`[image: ${b.source?.media_type ?? "?"}]\``;
    default: return fenceJson(b);
  }
}

function renderOpenAIRequest(req) {
  const parts = [];
  if (req.tools?.length) {
    parts.push("### tools\n\n" + req.tools.map((t) => `- \`${t?.function?.name ?? t?.name ?? "?"}\` — ${bytes(Buffer.byteLength(JSON.stringify(t)))}`).join("\n") + "\n\n_Full schemas are in `request.json`._");
  }
  parts.push("### messages\n\n" + (req.messages ?? []).map((m, i) => {
    const content = typeof m.content === "string" ? m.content
      : Array.isArray(m.content) ? m.content.map((p) => (p?.type === "text" ? p.text : `\`[${p?.type}]\``)).join("\n\n")
      : m.content == null ? "" : JSON.stringify(m.content);
    const calls = m.tool_calls?.length ? "\n\n" + m.tool_calls.map((c) => `<tool-call name="${c.function?.name}" id="${c.id}">\n\n\`\`\`json\n${c.function?.arguments ?? ""}\n\`\`\`\n\n</tool-call>`).join("\n\n") : "";
    return `<message index="${i}" role="${m.role}"${m.tool_call_id ? ` tool-call-id="${m.tool_call_id}"` : ""}>\n\n${content}${calls}\n\n</message>`;
  }).join("\n\n"));
  return parts.join("\n\n");
}

/** Reassemble the stream into something a human can read. Kept deliberately
 * lossy — `response.raw` next to it is the authoritative artifact. */
function renderStreamBody(flavor, frames) {
  const out = [];
  if (flavor === "anthropic") {
    const blocks = new Map();
    for (const fr of frames) {
      const d = fr.data;
      if (!d) continue;
      if (d.type === "content_block_start") blocks.set(d.index, { type: d.content_block?.type, name: d.content_block?.name, text: "" });
      else if (d.type === "content_block_delta" && blocks.has(d.index)) {
        const dd = d.delta ?? {};
        blocks.get(d.index).text += dd.text ?? dd.partial_json ?? dd.thinking ?? "";
      }
    }
    for (const [i, b] of [...blocks.entries()].sort((a, x) => a[0] - x[0])) {
      out.push(`<block index="${i}" type="${b.type}"${b.name ? ` name="${b.name}"` : ""}>\n\n${b.text}\n\n</block>`);
    }
  } else {
    let text = "", reasoning = "";
    const calls = new Map();
    for (const fr of frames) {
      const delta = fr.data?.choices?.[0]?.delta;
      if (!delta) continue;
      text += delta.content ?? "";
      reasoning += delta.reasoning_content ?? delta.reasoning ?? "";
      for (const tc of delta.tool_calls ?? []) {
        const k = tc.index ?? 0;
        if (!calls.has(k)) calls.set(k, { name: "", args: "" });
        if (tc.function?.name) calls.get(k).name += tc.function.name;
        if (tc.function?.arguments) calls.get(k).args += tc.function.arguments;
      }
    }
    if (reasoning) out.push(`<reasoning>\n\n${reasoning}\n\n</reasoning>`);
    if (text) out.push(`<content>\n\n${text}\n\n</content>`);
    for (const [k, c] of calls) out.push(`<tool-call index="${k}" name="${c.name}">\n\n\`\`\`json\n${c.args}\n\`\`\`\n\n</tool-call>`);
  }
  return out.length ? out.join("\n\n") : "_empty_";
}

function renderReport(ctx) {
  const { meta, resp, findings, analysis, flavor, req } = ctx;
  const counts = { fail: 0, warn: 0, info: 0 };
  for (const x of findings) counts[x.level]++;

  const parts = [
    `# ${meta.method} ${meta.path} → ${resp.status}`,
    "",
    "## verdict",
    "",
    `**${counts.fail} fail · ${counts.warn} warn · ${counts.info} info**`,
    "",
    renderFindings(findings),
    "",
    "## exchange",
    "",
    [
      `- **timestamp**: ${meta.timestamp}`,
      `- **flavor**: ${flavor}`,
      `- **upstream**: ${meta.upstreamUrl}`,
      `- **model**: ${req?.model ?? "?"}`,
      `- **stream requested**: ${req?.stream === true}`,
      `- **response content-type**: ${resp.contentType ?? "(none)"}`,
      `- **timing**: TTFB ${ms(resp.ttfbMs)} · total ${ms(resp.totalMs)}`,
      `- **transfer**: ${bytes(meta.reqBytes)} up · ${bytes(resp.bytes)} down · ${resp.chunkLog.length} network chunk(s)` + (resp.frames.length ? ` · ${resp.frames.length} SSE frame(s)` : ""),
      resp.aborted ? `- **aborted**: client disconnected mid-response` : null,
    ].filter(Boolean).join("\n"),
    "",
    "## usage",
    "",
    analysis?.usage ? fenceJson(analysis.usage) : "_none reported_",
    "",
    "## caching",
    "",
    renderPrefix(analysis?.prefix, analysis?.breakpoints, analysis?.segs),
    "",
    "## request",
    "",
    flavor === "anthropic" ? renderAnthropicRequest(req ?? {}) : renderOpenAIRequest(req ?? {}),
    "",
    "## response",
    "",
    resp.frames.length ? renderStreamBody(flavor, resp.frames) : (resp.json ? fenceJson(resp.json) : "```\n" + resp.text.slice(0, 20000) + "\n```"),
    "",
    "## response headers",
    "",
    "```\n" + resp.headerLines.join("\n") + "\n```",
    "",
    "---",
    "",
    "_Raw artifacts alongside this file: `request.json`, `response.raw`, `request.headers.txt`, `response.headers.txt`, `timing.json`._",
    "",
  ];
  return parts.join("\n");
}

function printSummary(dir, meta, resp, findings, flavor, analyzed) {
  if (QUIET) return;
  const tty = process.stdout.isTTY;
  const c = (code, s) => (tty ? `\x1b[${code}m${s}\x1b[0m` : s);
  const counts = { fail: 0, warn: 0 };
  for (const x of findings) if (counts[x.level] !== undefined) counts[x.level]++;

  const status = resp.status >= 400 ? c(31, resp.status) : c(32, resp.status);
  console.log(
    `\n[vendor-proxy] ${meta.method} ${meta.path} → ${status} · ${flavor} · ${ms(resp.totalMs)}` +
    ` · TTFB ${ms(resp.ttfbMs)} · ${resp.frames.length || "-"} events / ${resp.chunkLog.length} chunks`
  );
  for (const x of findings) {
    if (x.level === "info") continue;
    const color = x.level === "fail" ? 31 : 33;
    const label = x.count > 1 ? `${x.code} ×${x.count}` : x.code;
    console.log(`  ${c(color, LEVEL_MARK[x.level])} ${c(color, label.padEnd(30))} ${x.msg}`);
  }
  // Only claim conformance for traffic we actually checked — silence on an
  // unanalysed endpoint is not a pass.
  if (!counts.fail && !counts.warn) console.log(analyzed ? `  ${c(32, "✓")} conformant` : `  ${c(90, "·")} captured, no checks for this endpoint`);
  const rel = path.relative(process.cwd(), dir);
  console.log(`  → ${rel.startsWith("..") ? dir : rel}/report.md`);
}

// ---------------------------------------------------------------------------
// Capture
// ---------------------------------------------------------------------------

let SEQ = 0;

function flavorOf(reqPath) {
  if (reqPath.includes("count_tokens")) return "anthropic-count";
  if (reqPath.includes("/messages")) return "anthropic";
  if (reqPath.includes("/chat/completions")) return "openai";
  if (reqPath.includes("/responses")) return "openai-responses";
  return "other";
}

function redactHeaders(headers) {
  return Object.entries(headers).map(([k, v]) => {
    const val = Array.isArray(v) ? v.join(", ") : String(v ?? "");
    return `${k}: ${REDACT.has(k.toLowerCase()) ? `[REDACTED ${val.length} chars]` : val}`;
  });
}

/**
 * Force `identity`. Deleting Accept-Encoding is not enough: per RFC 9110 its
 * absence means *any* encoding is acceptable, so a gateway's nginx layer is free
 * to gzip and turn the capture into binary. We still gunzip defensively below,
 * because gateways ignore this too.
 */
function forwardHeaders(headers, body) {
  const out = { ...headers };
  delete out["host"];
  delete out["connection"];
  delete out["transfer-encoding"];
  delete out["content-length"];
  out["accept-encoding"] = "identity";
  if (body.length > 0) out["content-length"] = String(body.length);
  return out;
}

function decodeBody(buf, encoding) {
  if (!encoding || encoding === "identity") return buf;
  try {
    if (encoding.includes("gzip")) return zlib.gunzipSync(buf);
    if (encoding.includes("deflate")) return zlib.inflateSync(buf);
    if (encoding.includes("br")) return zlib.brotliDecompressSync(buf);
  } catch { /* fall through: keep the raw bytes */ }
  return buf;
}

function joinPath(basePath, reqPath) {
  const b = basePath.replace(/\/+$/, "");
  return b + reqPath;
}

/**
 * Persist first, analyse second. The capture is written before anything tries to
 * interpret it, so a parser crash on a malformed response — precisely the case
 * worth debugging — can never destroy the evidence.
 */
function capture(ctx) {
  const { meta, resp, flavor, reqBodyText } = ctx;
  const dir = path.join(LOG_DIR, `${meta.stamp}_${String(meta.seq).padStart(4, "0")}_${flavor}`);
  fs.mkdirSync(dir, { recursive: true });
  const w = (name, data) => fs.writeFileSync(path.join(dir, name), data);

  w("request.headers.txt", `${meta.method} ${meta.path}\n\n` + redactHeaders(meta.reqHeaders).join("\n") + "\n");
  w("request.json", reqBodyText);
  w("response.headers.txt", `HTTP ${resp.status}\n\n` + resp.headerLines.join("\n") + "\n");
  w("response.raw", resp.buffer);
  w("timing.json", JSON.stringify({
    startedAt: meta.timestamp,
    ttfbMs: resp.ttfbMs,
    totalMs: resp.totalMs,
    aborted: resp.aborted,
    chunks: resp.chunkLog.map((c) => ({ atMs: Math.round(c.t), size: c.size })),
  }, null, 2));

  return dir;
}

function appendIndex(dir, meta, resp, findings, flavor, analysis) {
  const line = JSON.stringify({
    ts: meta.timestamp,
    seq: meta.seq,
    dir: path.basename(dir),
    flavor,
    path: meta.path,
    model: meta.model,
    status: resp.status,
    ttfbMs: Math.round(resp.ttfbMs),
    totalMs: Math.round(resp.totalMs),
    chunks: resp.chunkLog.length,
    events: resp.frames.length,
    // `code` stays a bare prefix so a plain grep across the session still hits.
    fail: findings.filter((f) => f.level === "fail").map((f) => (f.count > 1 ? `${f.code} ×${f.count}` : f.code)),
    warn: findings.filter((f) => f.level === "warn").map((f) => (f.count > 1 ? `${f.code} ×${f.count}` : f.code)),
    usage: analysis?.usage ?? null,
    reusablePct: analysis?.prefix && !analysis.prefix.baseline ? Number(analysis.prefix.reusablePct.toFixed(1)) : null,
  });
  fs.appendFileSync(path.join(LOG_DIR, "index.jsonl"), line + "\n");
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

function handle(req, res) {
  const reqPath = req.url ?? "/";
  const flavor = flavorOf(reqPath);
  const seq = ++SEQ;
  const chunks = [];
  req.on("data", (c) => chunks.push(c));

  req.on("end", () => {
    const body = Buffer.concat(chunks);
    const started = process.hrtime.bigint();
    const since = () => Number(process.hrtime.bigint() - started) / 1e6;
    const meta = {
      seq,
      timestamp: new Date().toISOString(),
      stamp: new Date().toISOString().replace(/[:.]/g, "-").replace("Z", ""),
      method: req.method ?? "POST",
      path: reqPath,
      reqHeaders: req.headers,
      reqBytes: body.length,
      upstreamUrl: `${UPSTREAM.origin}${joinPath(UPSTREAM.pathname, reqPath)}`,
      model: null,
    };

    const transport = UPSTREAM.protocol === "http:" ? http : https;
    const upstream = transport.request(
      {
        protocol: UPSTREAM.protocol,
        hostname: UPSTREAM.hostname,
        port: UPSTREAM.port || (UPSTREAM.protocol === "http:" ? 80 : 443),
        path: joinPath(UPSTREAM.pathname, reqPath),
        method: req.method,
        headers: forwardHeaders(req.headers, body),
      },
      (up) => {
        const respChunks = [];
        const chunkLog = [];
        let ttfbMs = null;

        up.socket?.setNoDelay(true);
        res.socket?.setNoDelay(true);
        res.writeHead(up.statusCode ?? 502, up.headers);

        up.on("data", (c) => {
          ttfbMs ??= since();
          chunkLog.push({ t: since(), size: c.length });
          respChunks.push(c);
          res.write(c); // straight through: live latency is unaffected
        });

        const finish = (aborted) => {
          if (!aborted) res.end();
          const totalMs = since();
          const rawBuffer = Buffer.concat(respChunks);
          const encoding = String(up.headers["content-encoding"] ?? "");
          const decoded = decodeBody(rawBuffer, encoding);
          const text = decoded.toString("utf8");
          const contentType = String(up.headers["content-type"] ?? "");
          const isSSE = contentType.includes("text/event-stream");

          const resp = {
            status: up.statusCode ?? 0,
            headerLines: redactHeaders(up.headers),
            contentType,
            buffer: rawBuffer,
            text,
            bytes: rawBuffer.length,
            chunkLog,
            ttfbMs: ttfbMs ?? totalMs,
            totalMs,
            aborted,
            frames: [],
            json: null,
          };
          if (isSSE) {
            resp.frames = parseSSE(text);
            attachArrival(resp.frames, chunkLog);
          } else {
            try { resp.json = JSON.parse(text); } catch { /* leave null */ }
          }

          const reqBodyText = body.toString("utf8");
          let reqJson = null;
          try { reqJson = JSON.parse(reqBodyText); } catch { /* non-JSON request */ }
          meta.model = reqJson?.model ?? null;

          // Evidence first — everything below may throw on a malformed response.
          const dir = capture({ meta, resp, flavor, reqBodyText });

          const f = newFindings();
          let analysis = null;
          if (encoding && encoding !== "identity") {
            f.warn("transport.compressed", `upstream ignored \`accept-encoding: identity\` and returned ${encoding}; decoded for analysis`);
          }
          if (aborted) f.info("transport.aborted", "client disconnected before the response finished");

          let analyzed = true;
          try {
            if (reqJson && flavor === "anthropic") {
              analysis = analyzeAnthropic(reqJson, resp, f);
            } else if (reqJson && flavor === "openai") {
              analysis = analyzeOpenAI(reqJson, resp, f);
            } else if (reqJson && flavor === "anthropic-count") {
              if (resp.status >= 400) checkErrorShape(resp, f, "anthropic");
              else if (typeof resp.json?.input_tokens !== "number") {
                f.fail("count.no_input_tokens", "count_tokens response has no numeric input_tokens");
              }
            } else {
              // No format-specific checks, but an error response still has a
              // contract: whatever the endpoint, a 4xx/5xx must be JSON the
              // client can classify. A gateway leaking an HTML 500 breaks retry
              // logic everywhere, so never let this path report "conformant".
              analyzed = false;
              f.info(reqJson ? "skip.unanalyzed" : "skip.non_json_request",
                `${flavor} ${meta.method} ${meta.path} captured without format-specific checks`);
              if (resp.status >= 400) {
                analyzed = true;
                checkErrorShape(resp, f, flavor.startsWith("anthropic") ? "anthropic" : "openai");
              }
            }
          } catch (err) {
            f.fail("analyzer.crashed", `the analyzer threw on this exchange: ${err.message}`, err.stack);
          }

          try {
            fs.writeFileSync(path.join(dir, "report.md"), renderReport({ meta, resp, findings: f.list, analysis, flavor, req: reqJson ?? {} }));
            appendIndex(dir, meta, resp, f.list, flavor, analysis);
          } catch (err) {
            console.error(`[vendor-proxy] report failed (capture is intact in ${dir}): ${err.message}`);
          }
          printSummary(dir, meta, resp, f.list, flavor, analyzed);
        };

        up.on("end", () => finish(false));
        res.on("close", () => { if (!res.writableEnded) { up.destroy(); finish(true); } });
      }
    );

    upstream.on("error", (err) => {
      console.error(`[vendor-proxy] upstream error: ${err.message}`);
      if (!res.headersSent) res.writeHead(502, { "content-type": "application/json" });
      const shape = flavor.startsWith("anthropic")
        ? { type: "error", error: { type: "api_error", message: `vendor-proxy upstream error: ${err.message}` } }
        : { error: { message: `vendor-proxy upstream error: ${err.message}`, type: "api_error" } };
      res.end(JSON.stringify(shape));
    });

    if (body.length > 0) upstream.write(body);
    upstream.end();
  });
}

fs.mkdirSync(LOG_DIR, { recursive: true });
http.createServer(handle).listen(PORT, () => {
  console.log(`[vendor-proxy] listening on http://localhost:${PORT}`);
  console.log(`[vendor-proxy] upstream    ${UPSTREAM.origin}${UPSTREAM.pathname.replace(/\/+$/, "")}<incoming path>`);
  console.log(`[vendor-proxy] captures    ${LOG_DIR}`);
  console.log(`[vendor-proxy] point clients at this host, keeping their usual subpath:`);
  console.log(`[vendor-proxy]   ANTHROPIC_BASE_URL=http://localhost:${PORT}/anthropic claude`);
  console.log(`[vendor-proxy]   OPENAI_BASE_URL=http://localhost:${PORT}/openai/v1`);
});
