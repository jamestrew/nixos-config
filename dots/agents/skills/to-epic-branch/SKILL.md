---
name: to-epic-branch
description: Create a spec epic whose child tickets integrate on a shared branch and ship together to mainline.
disable-model-invocation: true
---

# To Epic Branch

Read and follow [to-epic](../to-epic/SKILL.md), including its referenced skills and both approval checkpoints. Apply the additions below while drafting and publishing; otherwise its process remains authoritative.

## Branch contract

Before publishing the epic, identify the repository's remote and mainline branch, respecting any user-specified target. Choose an unused epic branch name such as `epic/<feature-slug>` and check it against the remote. Resolve ambiguous targets with the user.

Record the exact remote, mainline branch, and epic branch in the epic's Further Notes. Include an initialization record, initially `Not initialized`, to distinguish a branch that has never been created from one that has disappeared. Planning publishes issues only; branch creation waits until implementation.

Add a **Branch workflow** section to every child issue, including the final integration ticket. Repeat the exact remote and branch names and the applicable instructions below so each issue is actionable on its own. This intentional repetition is the handoff contract for fresh implementation contexts, not a replacement for native parent links or blocking edges.

## Implementation ticket instructions

Include these instructions in the epic and every implementation ticket:

- Before starting, read the epic's initialization record and check the remote epic branch. Use its latest tip when it exists; reconcile an existing branch with an incomplete initialization record before proceeding.
- If the branch is absent, the record says `Not initialized`, and no child implementation has begun, create and push it from the latest remote mainline. Record the initial commit SHA on the epic immediately after a successful push. Use a normal push, never a force push; if another ticket initializes it concurrently, fetch and use that branch instead.
- If an initialized branch is missing, or child work exists despite a missing initialization record, stop and recover or clarify. Recreating it from mainline could abandon integrated work.
- Create each ticket's working branch from the latest remote epic branch. Target its PR at the epic branch and integrate the completed ticket there, leaving mainline unchanged.

Updating the epic's initialization record during implementation is a narrow exception to the inherited rule against editing the parent. Preserve its spec and other content.

## Final integration ticket

Include a final **Integrate and ship the epic** ticket in the breakdown presented for approval. Make it a child of the epic, labelled `ready-for-agent`, and natively blocked by every other child ticket. Keep those blocking edges out of its body, as directed by `to-tickets`.

Its deliverable is the assembled feature shipped as one unit. Its acceptance criteria must cover:

- Verification that all approved implementation work is present on the remote epic branch.
- The spec's acceptance and regression checks passing for the assembled feature, including integration with current mainline.
- One final PR from the epic branch to the recorded mainline branch, reviewed and merged according to repository policy.

Include the branch existence and recovery checks in this ticket too, but make its merge target explicitly mainline; it is the exception to the implementation tickets' PR target. The root epic stays coordination-only: implementation and final integration belong to its children.

Finish with the inherited issue URL report plus the recorded branch contract and a reminder that the epic branch will be initialized when implementation starts.
