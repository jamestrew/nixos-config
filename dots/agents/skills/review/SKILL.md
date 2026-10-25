---
name: review
description: Delegate a read-only review of this session's changes and report findings for the user to decide how to address.
disable-model-invocation: true
compatibility: Requires subagent spawn/wait tools and the thermonuclear-review skill.
---

# Review

Keep both your work and the reviewer's work read-only; do not apply fixes.

1. Define the review scope from this conversation and the working tree. Identify this session's changes separately from pre-existing edits; do not substitute the whole branch diff. If the boundary cannot be established, ask the user before delegating.

2. Delegate the review to one subagent with a self-contained brief. Assume it cannot see this conversation. Include:
   - What changed in this session, with affected paths and a diff or baseline sufficient to isolate those changes.
   - The ticket or issue requirements, or an explicit statement that none apply.
   - Any intentional additions or deviations from the request or requirements.

   Instruct the reviewer to invoke `thermonuclear-review`, review only this session's changes, and verify every applicable requirement. Only the reviewer invokes that skill. Keep its work read-only: request findings, not edits. For each finding, request severity, location, supporting evidence, and a recommended approach; also request unmet or unverifiable requirements. Require an explicit statement if there are no findings.

3. Await the reviewer's terminal result before proceeding. Let it finish at its own pace. A wait-tool timeout means only that the review is still running: continue useful non-review work that leaves the review scope unchanged, then wait again with the maximum supported timeout. Request early wrap-up only when new information, independent of elapsed time, makes further review unnecessary. If the reviewer fails, report the failure rather than treating it as a clean review.

4. Report the reviewer's findings to the user, preserving severity, locations, evidence, recommended approaches, and requirement gaps. Clearly distinguish any uncertainty or disagreement from the reviewer's conclusions. If there are no findings, say so.
5. Leave decisions about whether and how to address findings to the user. Finish with the report, not implementation changes.
