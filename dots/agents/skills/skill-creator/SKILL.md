---
name: skill-creator
description: Create or revise agent skills, evaluate their outputs against baselines, and optimize description triggering. Use for skill authoring, performance benchmarks, or trigger tuning.
---

# Skill Creator

Start at the user's current stage: define intent, draft, evaluate, or revise. Match the scope to the request; an editorial revision need not become a benchmark project.

Paths below are relative to this skill's directory. Run `python -m scripts.…` commands from that directory; use absolute paths for target skills and workspaces.

## 1. Define the contract

Extract what the conversation already establishes, then resolve the gaps:

- **Purpose:** what the skill enables the agent to do.
- **Triggers:** user requests and contexts that should invoke it, plus nearby cases that should not.
- **Output:** deliverables, formats, constraints, and success criteria.
- **Inputs:** examples, edge cases, dependencies, and required tools.
- **Evidence:** whether the user wants test runs. Suggest them for verifiable workflows; use human review for subjective quality. Respect requests to work without evaluations.

Proceed when the contract is agreed. Ask only for information that would change the draft or tests. Match terminology to the user's technical familiarity.

When comparing revisions, snapshot the existing skill into `<skill-name>-workspace/skill-snapshot/` before editing. Preserve its directory name and frontmatter `name`. Copy read-only installations to a writable location first.

## 2. Draft or revise

Write `SKILL.md` with YAML frontmatter:

- `name`: the skill identifier.
- `description`: what it does and the distinct contexts that should trigger it. Put invocation guidance here rather than repeating it in the body.
- `compatibility`: required tools or dependencies, when needed.

Write the body as an executable procedure:

- Order actions and give each step a checkable completion criterion.
- Use direct imperatives. Explain reasons where they affect decisions.
- Define exact output formats when downstream tools require them; add examples when they resolve ambiguity.
- Keep each rule in one place. Remove conversational filler, repeated instructions, and advice that adds no behavior.
- Keep shared steps inline; move branch-specific detail into referenced files with explicit conditions for reading them. Aim for fewer than 500 lines in `SKILL.md`; add a contents list to references over 300 lines.
- Bundle repeated deterministic work in `scripts/`, on-demand documentation in `references/`, and output templates or other assets in `assets/`.
- Keep the skill's actions within the user's stated purpose and authorization. Exclude deceptive behavior, unauthorized access, and data exfiltration.

The draft is ready when each contract requirement has an instruction or resource, and every reference has a clear loading condition.

## 3. Evaluate, when requested

Propose two or three realistic prompts covering the contract and edge cases. Get the user's approval before running them. Save them to the target skill's `evals/evals.json`, initially without assertions:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "A realistic user request",
      "expected_output": "The observable result",
      "files": []
    }
  ]
}
```

For test runs, benchmarks, or output review, follow [Evaluation](references/evaluation.md). It covers paired runs, grading, timing, and the review viewer. Complete the sequence through human review before revising from its results.

## 4. Revise from evidence

Use user feedback, grades, outputs, and execution transcripts together:

- Fix the general failure rather than adding a rule for one test case.
- Remove instructions that cause unproductive work.
- Bundle helpers only when repeated runs demonstrate a shared need.
- Separate skill failures from weak tests: an assertion that both configurations always pass may not measure the skill's value.

For evaluated changes, rerun the approved cases in a new iteration with a baseline, then request review again. Expand coverage when the existing cases no longer distinguish improvements. Stop when the user accepts the result or another iteration offers no meaningful improvement; report remaining limitations.

For a requested blind comparison, read [Comparator](agents/comparator.md) and [Analyzer](agents/analyzer.md), then use independent agents without revealing which version produced each output.

## 5. Validate and deliver

Run `python scripts/quick_validate.py <skill-path>` and check that referenced resources exist.

Return the edited skill's path and a brief change summary. State which evaluations ran or were skipped.

Once the user accepts the skill's behavior, offer description tuning. For trigger evaluation or description optimization, follow [Description optimization](references/description-optimization.md); it requires the `claude` CLI.

If `present_files` is available and the user needs an installable artifact, run `python -m scripts.package_skill <skill-path>` and present the resulting `.skill` file. Stage packaging in a writable directory.
