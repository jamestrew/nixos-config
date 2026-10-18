---
name: to-epic
description: Turn the current conversation into a spec epic with implementation split into child tickets.
disable-model-invocation: true
---

# To Epic

Compose `to-spec` and `to-tickets` in sequence. Their templates and processes remain authoritative except for the epic-specific overrides below.

## 1. Publish the spec epic

Read and follow [to-spec](../to-spec/SKILL.md), preserving its testing-seam approval checkpoint.

Override its publishing instructions:

- Label the root issue `epic` instead of `ready-for-agent`. Create the `epic` label if missing.
- Retain the full spec, including implementation and testing decisions. State in Further Notes that this issue is a coordination-only epic: all implementation belongs in its child tickets.

This step is complete when the epic is published and its issue number is known.

## 2. Publish the implementation tickets

Read and follow [to-tickets](../to-tickets/SKILL.md), passing the epic issue number as the spec reference. Preserve its breakdown approval checkpoint before publishing children.

Use the epic as the native parent of every implementation ticket. Keep the child tickets labelled `ready-for-agent` and wire their native blocking dependencies as directed by `to-tickets`. The epic is their parent, not a blocker; it contains no implementation work of its own.

Finish when all approved tickets are published with their parent links and blocking dependencies. Report the epic URL and child ticket URLs. Leave implementation for those tickets.
