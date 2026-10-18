# Handoff fidelity

Preserve the technical context a fresh agent needs to understand and implement the agreed design without repeating the design conversation. Include relevant file paths, existing code structure, code snippets, pseudocode, examples, constraints, and rationale from the discussion. Retain alternatives or counterexamples when they explain why the chosen approach matters.

Keep snippets alongside the decisions they explain, including snippets from prototypes. Preserve whether something was agreed, illustrative, or unresolved; an example is not automatically a requirement. Condense repetition, not meaning: prefer concrete detail over an abstract summary when abstraction would lose information. Capture the context available rather than inventing details to fill gaps.

Check codebase references against the current repository while drafting. If something is already stale, reconcile it without changing the agreed intent, or explicitly flag the discrepancy. Treat paths and snippets as implementation pointers to verify, rather than omitting them because they might become outdated.

When the published spec or ticket includes codebase-specific context, include this note alongside it:

> **Codebase context:** File paths and snippets reflect the code at planning time. Verify them before implementation. If the code has changed, adapt the implementation while preserving the documented intent and constraints. Surface material conflicts rather than silently changing the agreed design.

Make the expected response to drift clear: moved files, renamed symbols, and equivalent structures can be accommodated without reopening the design. Changed assumptions, incompatible architecture, or different behavior require explaining the mismatch and confirming the revised approach. Record known discrepancies specifically; the general note is not a substitute for identifying them. Timestamps and commit hashes are optional when useful, not required metadata.
