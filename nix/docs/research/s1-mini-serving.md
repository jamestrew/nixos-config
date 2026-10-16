# Serving S1-mini locally

Researched and trialled 2026-10-16 on the NixOS desktop.

## Recommendation

Use the publisher's Q4_K_M GGUF on CPU, without a Python/GPU serving stack. For Handy 0.9.8, prefer **llama-server with a tiny dedicated Jinja template** that injects the required system message and non-thinking assistant prefix. Plain `llama-server` requires the client to supply the system role. These are integration recommendations, not machine benchmarks. [Publisher GGUF documentation](https://huggingface.co/superwhisper/s1-mini-GGUF)

## Declarative NixOS service

`hosts/main/configuration.nix` imports `modules/sys/s1-mini.nix` and enables the native `services.llama-cpp` module. The model is fetched at an immutable revision with a SHA-256 hash, and both weights and `modules/sys/s1-mini.jinja` live in the Nix store. No files in the user's home directory are needed by the server. It starts at boot as `llama-cpp.service`, using the upstream module's dynamic user, sandboxing, and failure restart policy.

The endpoint remains `http://127.0.0.1:18080/v1`, model `s1-mini`; Handy needs no further settings changes. Only loopback is bound, CORS is restricted to localhost, and no firewall port is opened.

Activation requires sudo. Build first while the temporary server remains available, then stop it to release port 18080 and switch:

```sh
nh os build
systemctl --user stop s1-mini-trial
nh os switch
systemctl status llama-cpp
curl --fail http://127.0.0.1:18080/health
```

If switching fails, the temporary server can be restored without sudo using the evaluated declarative command:

```sh
nix eval --raw .#nixosConfigurations.nixos.config.systemd.services.llama-cpp.serviceConfig.ExecStart \
  | xargs systemd-run --user --unit=s1-mini-trial --collect
```

After activation, use `sudo systemctl restart llama-cpp` and `journalctl -u llama-cpp` for operations. The one-off trial scripts were removed after validation; they are not runtime dependencies.

## Model and actual downloads

- S1-mini is a 596M-parameter Qwen3-0.6B fine-tune for **English transcript normalization**, not audio recognition or general chat. It follows an exact system prompt and constrained control line, not arbitrary cleanup instructions. Recommended transcript length is approximately 1,000 tokens maximum per pass. [Model card](https://huggingface.co/superwhisper/s1-mini)
- Architecture: `Qwen3ForCausalLM`, 28 layers, 16 query heads/8 KV heads, BF16, configured context 40,960 tokens. The architectural context is not a recommendation to normalize long transcripts. [Configuration](https://huggingface.co/superwhisper/s1-mini/blob/main/config.json)
- Actual artifact sizes, rather than rounded/inconsistent card units:

  | Repository | Artifact | Bytes |
  | --- | --- | ---: |
  | `superwhisper/s1-mini-GGUF` | `s1-mini-q4_k_m.gguf` | 484,219,808 (~462 MiB) |
  | `superwhisper/s1-mini-GGUF` | `s1-mini-f16.gguf` | 1,509,347,232 |
  | `superwhisper/s1-mini` | `model.safetensors` | 1,503,300,328 |

  These are weight-file sizes, not total process memory. Sources: [GGUF file API](https://huggingface.co/api/models/superwhisper/s1-mini-GGUF/tree/main), [BF16 file API](https://huggingface.co/api/models/superwhisper/s1-mini/tree/main).

## Verified documented server command

```sh
llama-server \
  -hf superwhisper/s1-mini-GGUF:Q4_K_M \
  --host 127.0.0.1 --port 8080 \
  --ctx-size 4096 \
  --jinja --chat-template-kwargs '{"enable_thinking":false}' \
  --temp 0
```

The publisher documents this model selection/template/temperature combination. The explicit bind/port/context options are documented upstream; 4,096 is a conservative local allocation choice, not a model requirement. First startup downloads weights. For pinned deployment, download an immutable revision separately and replace `-hf …` with `-m /absolute/path/to/s1-mini-q4_k_m.gguf`. [Publisher command](https://huggingface.co/superwhisper/s1-mini-GGUF#llamacpp), [server options](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)

The server exposes OpenAI-compatible `/v1/chat/completions`; `/v1/models` reports the model ID, and `/health` reports readiness. Avoid assuming that the filename/model ID will match an application display label. [Server API documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)

## Request contract and failure traps

1. Send the **exact system message** from the author's [input-format section](https://huggingface.co/superwhisper/s1-mini-GGUF#input-format), as a system-role message. Do not replace it with a generic editing prompt.
2. The user message begins with this control line, then a newline and the transcript:

   ```text
   [Styling: semi-formal] [Structure: prose] [Context: general]
   ```

   Supported values: styling `casual`, `semi-casual`, `semi-formal`, `formal`; structure `prose`, `lists`; context `general`, `email`.
3. Disable thinking **in template rendering**. Do not substitute `--reasoning-budget 0`: the required assistant prefix includes an empty think block, and the publisher reports degraded output with the substitute.
4. Use temperature zero. For clients that omit temperature, set the llama-server default with `--temp 0`; do not rely on inherited GGUF sampling metadata.

These requirements and a complete curl example are in the [publisher's GGUF instructions](https://huggingface.co/superwhisper/s1-mini-GGUF).

The raw assistant prefix must be `<|im_start|>assistant\n<think>\n\n</think>\n\n`. Missing thinking suppression commonly yields blank output. Separately, filler-only input legitimately produces an empty result. Suggested output ceiling: `1.3 × input_tokens + 32`; split longer transcripts at sentence boundaries. [Model integration guidance](https://huggingface.co/superwhisper/s1-mini#best-practices)

## Alternatives and remaining verification

- vLLM and SGLang have author-documented OpenAI-compatible serving commands; disable thinking with `chat_template_kwargs` on requests. They add an unnecessary serving stack for this small CPU-capable model unless already deployed. Ollama needs the author's custom non-thinking Modelfile; a plain model pull is insufficient evidence of correct prompt formatting. [Deployment](https://huggingface.co/superwhisper/s1-mini#deployment), [Ollama example](https://huggingface.co/superwhisper/s1-mini-GGUF#ollama)
- The trial below verified the pinned `llama-server`, custom template, and Handy-shaped requests on CPU.
- Display the publisher's model name/attribution and consult the bundled custom license before redistributing weights. [License](https://huggingface.co/superwhisper/s1-mini/blob/main/LICENSE)

## Handy 0.9.8: dedicated llama.cpp template, not Ollama

The parent integration audit found that Handy 0.9.8's legacy custom provider sends one user message and omits temperature. A control line alone therefore cannot work with the unmodified llama-server setup above: its required system message would be missing. The structured-output path is unsuitable because the model emits plain text, not JSON.

**Tested integration:** `modules/sys/s1-mini.jinja` hardcodes the author's exact system message, inserts the incoming user message verbatim, and emits the exact empty-think assistant prefix documented above. Select it using `--jinja --chat-template-file`, replacing the baseline `--chat-template-kwargs` flags; retain `--temp 0`. The template itself fixes thinking off. This changes prompt rendering, not the HTTP protocol, and requires neither a proxy nor a Handy fork. Upstream documents the custom-template flag and server sampling defaults. [Server options](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)

Handy's prompt then contains only:

```text
[Styling: semi-formal] [Structure: prose] [Context: general]
${output}
```

The running trial uses `http://127.0.0.1:18080/v1`, model `s1-mini`; port 8080 was occupied. Handy's Custom provider, model, and selected prompt were configured, preserving the existing prompt. Handy was restarted successfully. The user confirmed microphone-to-paste behavior works well.

**Why not Ollama:** its stored system message and legacy `.System`/`.Prompt` template do support single-user-message chat requests. However, its OpenAI compatibility conversion sets temperature to `1.0` when omitted, overriding a Modelfile's `PARAMETER temperature 0`. Since Handy 0.9.8 omits temperature, the author's Ollama Modelfile alone cannot guarantee the required greedy decoding. Reconsider only if Handy gains explicit temperature control. [System injection](https://github.com/ollama/ollama/blob/main/server/routes.go), [template executor](https://github.com/ollama/ollama/blob/main/template/template.go), [temperature conversion](https://github.com/ollama/ollama/blob/main/openai/openai.go)

## Trial history

- Runtime: the flake's CPU `llama-cpp` 0.6.0, build 11429 / d812350; eight threads, one slot, 4,096-token context. About 740 MiB service memory after tests.
- Weights: `~/.cache/s1-mini/s1-mini-q4_k_m.gguf`, downloaded from revision `34add00a48a2e5d24e5a4ee5405a99620a3a240c`; SHA-256 verified as `3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634`.
- Initial server: temporary user service `s1-mini-trial`, loopback only, localhost CORS, no web UI. Replaced by the declarative system service on activation above.
- Handy: settings backup at `~/.local/share/com.pais.handy/settings_store.json.before-s1-mini-20261016-111348`; started as temporary user service `handy-s1-mini-trial`.
- Permanent Hyprland shortcut: **Super+R** now toggles dictation with post-processing, configured in `dots/hypr/hyprland.lua`. It replaces the plain-transcription binding and the temporary Super+Alt+R trial binding.

Initial validation checked the exact rendered prompt, temperature-zero default, and three single-user requests with Handy's `reasoning_effort: none` and no temperature. Results: corrected date in 0.18–0.57 s; spoken currency in 0.10–0.11 s; empty filler-only output in 0.03 s. These are short synthetic samples, not an end-to-end latency benchmark.

```sh
curl --fail http://127.0.0.1:18080/health
systemctl status llama-cpp
```

For a complete Handy settings rollback, first quit Handy, copy the backup over `settings_store.json`, then restart Handy. Restoring the complete backup also discards any settings changed since the trial began.

### Shortcut crash correction

The original temporary binding incorrectly sent `SIGUSR1`. That signal is reserved for JavaScriptCore on Linux, and reproduced a SIGSEGV in `WTF::Thread::signalHandlerSuspendResume`, before microphone startup. Handy 0.9.8 only handles that post-processing signal on macOS; Linux must use `handy --toggle-post-process`. The CLI path successfully initialized recording and cancelled without crashing. [Upstream signal handling](https://github.com/cjpais/Handy/blob/v0.9.8/src-tauri/src/signal_handle.rs)

The permanent Super+R binding uses the CLI. Initial validation exercised that actual shortcut and confirmed the original Handy process survived recording startup and cancellation.
