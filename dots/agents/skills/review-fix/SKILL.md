---
name: review-fix
description: Delegate a review of this session's changes, then address every finding and verify the fixes.
disable-model-invocation: true
compatibility: Requires subagent spawn/wait tools and the thermonuclear-review skill.
---

# Review and fix

1. Define the review scope from this conversation and the working tree. Identify this session's changes separately from pre-existing edits; do not substitute the whole branch diff. If the boundary cannot be established, ask the user before delegating.

2. Delegate the review to one subagent with a self-contained brief. Assume it cannot see this conversation. Include:
   - What changed in this session, with affected paths and a diff or baseline sufficient to isolate those changes.
   - The ticket or issue requirements, or an explicit statement that none apply.
   - Any intentional additions or deviations from the request or requirements.

   Instruct the reviewer to invoke `thermonuclear-review`, review only this session's changes, and verify every applicable requirement. Only the reviewer invokes that skill. Keep its work read-only: request findings, not edits. For each finding, request severity, location, supporting evidence, and a recommended approach; also request unmet or unverifiable requirements. Require an explicit statement if there are no findings.

3. Await the reviewer's terminal result before proceeding. Let it finish at its own pace. A wait-tool timeout means only that the review is still running: continue useful non-review work that leaves the review scope unchanged, then wait again with the maximum supported timeout. Request early wrap-up only when new information, independent of elapsed time, makes further review unnecessary. If the reviewer fails, report the failure rather than treating it as a clean review.

4. Address every finding before completing the task. Make corrections consistent with the request and requirements, then run the relevant checks. Resolve a disputed finding with concrete evidence; if a fix requires a user decision or exceeds the task's authorization, ask rather than silently skipping it.
5. Report the findings, how each was resolved, and the verification results. Explicitly identify any blocked or unresolved finding; do not present it as fixed.
