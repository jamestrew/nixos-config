---
name: implement
description: "Implement a piece of work based on a spec or set of tickets, then drive it through review rounds until a reviewer signs off."
disable-model-invocation: true
---

## Resolve the work

Resolve `scripts/github_issue_context.py` relative to this file and run it with the target repository as the working directory.

- `Implement <issue> in <owner/repo>`: run `python3 <script-path> <issue> --repo <owner/repo>`.
- `<issue>`: run `python3 <script-path> <issue>`. The script resolves the repository from the `jj` remote, including workspaces without a `.git` directory.
- `<path/to/plan.md>`: read the file as the implementation plan and continue directly to implementation.

For a GitHub issue, input resolution is complete when you have read the issue, its comments, its parent issue when present, and every issue referenced in its body from the script's dump. Then implement the resolved issue or plan.

Use tdd skill where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once the work is green, run the review rounds below, then commit to the current branch.

## Review rounds

**Never read or invoke `thermonuclear-review` yourself** — a fresh subagent does, once per round. Reading it would leave you reviewing your own work against a rubric you just read, which is the job you're delegating.

Each round, spawn one `general-purpose` subagent:

> Invoke the `thermonuclear-review` skill and apply it to `git diff <base>...HEAD`. Report findings only — do not edit. End with exactly `VERDICT: APPROVE` or `VERDICT: CHANGES REQUESTED`, using the skill's own approval bar to decide.

The reviewer owns when its review is complete: only its terminal verdict completes a round. Count completed verdicts—not `WaitAgent` timeouts—toward the three-round limit.

On `CHANGES REQUESTED`, fix each finding or decline it with a reason — never drop one silently — then open a new round with a new subagent.

Carry declined findings into the next round's prompt: "declined for the stated reason; re-raise only if you disagree." Without this a fresh reviewer re-raises settled points and the rounds never converge.

Stop on `APPROVE`, or after three rounds — if the third still requests changes, hand it to the user with the outstanding findings.
