---
name: walkthrough
description: Guided walkthrough of a branch, commit range, or module — orientation, domain, execution flow, seams, then implementation — so a human can comprehend the code well enough to judge it themselves.
disable-model-invocation: true
argument-hint: "Branch, commit range, or path (defaults to the current branch)"
---

# Walkthrough

Explain a body of code to a human well enough that **they** can judge it. The reader is the judge; you are the guide. A reader who finishes the walkthrough and disagrees with the code has been served perfectly — verdicts on code quality belong in `/thermonuclear-review`, which takes this document as excellent input.

The walkthrough is an index into the code, not an English copy of the diff. Assume the reader has the code and diff open. Explain only what requires synthesis across files: the main flow, changed behaviour, interfaces, invariants, and non-obvious implementation choices. Point to local detail instead of restating it.

Two readers, one document: someone handed a branch to review, and someone reviewing code they nominally authored but an agent actually wrote. The second reader is why stated intent gets checked rather than repeated.

## Scope

Resolve the **subject** — what you explain — and the **baseline** it changed from, where there is one:

- **No argument** — the current branch against its merge-base with the default branch.
- **A branch or commit range** — that range; baseline is the merge-base or the range's start.
- **A path** — the module as it stands. No baseline, so nothing is marked as changed.

The walkthrough always explains the code **as it now stands**. A baseline doesn't change that — it marks which parts moved, and those parts lead every rung, because they're what the reader came for.

## Phase 1 — Survey

Read everything before writing anything. Drafting the orientation paragraph before you've read the subject anchors every rung beneath it to a guess you'll then spend the document defending.

Read it yourself — no subagent fan-out. The product is one coherent tour, and parallel readers return summaries you'd have to stitch together without having read the code.

Gather notes in this shape. The size gate measures them, so the shape has to hold:

```
## Files
- <path> — <what it does; what changed>

## Execution paths
- <behaviour> — <entry point → decisions and state changes → observable result; relevant tests and invariants>

## Terms
- <term> (stated|derived) — <meaning; whether it shifted>

## Claims
- <source> — <what it asserts about the change>

## Tricky
- <path:line> — <why the behaviour isn't evident from one read>
```

**Terms** come from `CONTEXT.md` where the repo has one — mark those **stated**. Otherwise derive them from type names, module names, and the vocabulary the tests use, and mark them **derived**. The distinction is load-bearing: a derived term is your reading of the model, and a reading you got wrong is exactly the misunderstanding the reader is here to catch. Read `CONTEXT.md`; leave it unmodified.

**Claims** are what commit messages, PR descriptions, and code comments assert about the change. Record them; source from the code instead. On an agent-authored branch the same process wrote the code and the message, so a walkthrough that repeats the message launders a claim into an explanation and the misunderstanding passes through invisibly. Where a claim and the code disagree, that becomes an open question — one of the most valuable things this document produces.

Phase 1 is done when **every file in the subject has a line** and the representative changed behaviour has been traced from an entry point to an observable result. Trace another path only when it has different decisions, state changes, or results. For a module without a baseline, trace its representative behaviour. Files nobody would discuss get one word. This inventory is a survey check, not a section to copy into the walkthrough.

### The size gate

Survey notes running past **~300 lines** mean the subject is too big to walk in one pass — the notes are a line per file plus a few short lists, so 300 lines is a great deal of subject.

When the gate trips, write rungs 1–4 and **stop before implementation**, saying so in the header. Degrading from the bottom is deliberate: orientation, domain, execution flow, and seams are what make a large subject navigable at all, and implementation detail is what the reader can fetch themselves once they know where to look. Thinning all five rungs evenly produces a document that looks complete and isn't.

## Phase 2 — Write

Start only once phase 1's criterion is met, and write top-down from the notes.

**Every claim carries a `file:line`.** An uncited sentence is one you didn't verify, and citations make that visible at a glance rather than merely suspected.

Use a default budget of **1,000 words**. Extend to 1,500 only when the subject has several independent execution paths. Cut restatements of local code first. Keep at most three annotated snippets.

Use ASD-STE100 Simplified Technical English outside common software terms:

- Use short sentences with one main idea. Aim for 25 words or fewer, excluding citations.
- Use the active voice when the actor is known.
- Use one term for one concept. Do not vary words for style.
- Avoid idioms, rhetorical phrases, and long abstract noun groups.
- Define an uncommon domain term before you use it.

The ladder is fixed. A rung with nothing in it shrinks to a line — a visibly empty **Seams** rung tells the reader something real — but no rung disappears.

### 1. Orientation

One paragraph: what this subject does and why it exists. Near-fixed length regardless of subject size — this is the part that has to stay skimmable exactly when the subject is large.

### 2. Domain

Define only the terms needed to follow the execution flow. Use terms from `CONTEXT.md` when available. Do not expose the survey labels `stated`, `derived`, or `shifted`. When a term changed meaning, use a direct “Before … Now …” statement.

### 3. Execution flow

Trace one representative changed behaviour from its entry point through decisions and state changes to its observable result. Add another path only when its behaviour is materially different. Name tests only when they establish an invariant or cover a non-obvious path. For a module without a baseline, trace its representative behaviour instead.

### 4. Seams

Invoke `/codebase-design` and use its vocabulary — module, interface, seam, depth, adapter — so a seam named here means the same thing when the reader goes to change it. Where the interfaces are, what sits behind them, what is new or moved. This is the rung where **signatures** are quoted: at a seam, the shape is the content.

### 5. Implementation

Include only the tricky spots that are not clear from the execution flow and seams. Use at most three annotated snippets. A citation is enough when the code is clear on inspection.

### Mechanical

Group files that changed without needing prose — lockfiles, generated output, formatting, and pure renames. Do not emit the survey's full per-file inventory.

### Open questions

At most five, plus contradictions. Two things are admitted:

- Something you **could not determine** from the code.
- A **contradiction** between the code and a stated claim — commit message, PR description, `CONTEXT.md`. These always go in and don't count against the five.

Both are comprehension findings. An opinion about code quality phrased as a question is still a verdict; send those to `/thermonuclear-review`.

## Quoting code

The reader has the repo open, so every quote is a cost that buys a saved lookup. Three tiers:

- **`file:line`** — on every claim, always.
- **Signatures** — where the interface is the point. Making the reader open a file to learn the shape of a seam is the expensive lookup worth absorbing.
- **Annotated snippets** — where the annotation carries what the code cannot say: an invariant, an ordering constraint, a "this looks wrong and isn't", an interaction three files away.

Test the third tier by stripping the annotation. If the snippet still says the same thing, it wasn't worth quoting — keep the `file:line` and drop the code.

## The artifact

Write to `/tmp/walkthrough-<subject>-<timestamp>.md`, opening with a header naming the subject, the baseline commit, the file count, and whether the size gate stopped it short. A document read three days later needs to say what it's of.

Report the path. The reader reads it themselves and asks about whatever didn't land; answer from the survey notes, and append anything substantial back into the file so the artifact stays complete.
