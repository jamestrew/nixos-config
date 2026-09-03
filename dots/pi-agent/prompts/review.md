---
description: Spawn a review subagent
---
Delegate this session's implementation review to a subagent. Only the subagent invokes the `thermonuclear-review` skill.

Give the subagent all context it needs because it cannot see this conversation:

- what changed in this session
- the ticket or issue requirements, or an explicit statement that none apply
- any intentional additions or deviations from the request or requirements

Have it review only this session's changes, verify every applicable requirement, and report its findings. Address every finding before completing the task.

Let the reviewer finish at its own pace. A `WaitAgent` timeout says only that the review is still running: continue useful non-review work, then wait again with the maximum timeout. Await the reviewer's terminal result before completing the task. Request early wrap-up only when new information, independent of elapsed time, makes further review unnecessary.
