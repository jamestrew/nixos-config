---
name: update-matt-skills
description: Stage and apply a reviewed update of the vendored Matt Pocock skills.
disable-model-invocation: true
---

# Update Matt Skills

Work from the repository's `dots/agents/skills/` directory.

## 1. Prepare

Read [`references/CHANGES.md`](references/CHANGES.md) and the generated report before judging personalized merges. Read [`references/npx-skills-grouping.md`](references/npx-skills-grouping.md) when upstream inventory or grouping behavior is in question.

Run:

```bash
python update-matt-skills/scripts/sync.py prepare \
  --skills . \
  --output /tmp/matt-skills-update
```

Use `--ref <tag-or-commit>` only when intentionally bypassing the latest stable GitHub release. Preparation copies the live collection to a candidate tree; it does not mutate live skills. Exit status 2 means the report contains inventory decisions or merge conflicts.

Review `/tmp/matt-skills-update/report.md`, then inspect every changed candidate file against the intent in `references/CHANGES.md`. Resolve merge markers directly in the candidate. For a promoted addition, removal, rename, replacement, or policy change, update `matt-skills.json` and prepare again so `blocking_decisions` is empty.

Completion criterion: every report row and upstream inventory change has an explicit disposition, `blocking_decisions` is empty, and any files listed under `merge_conflicts` are resolved in the candidate.

## 2. Verify

Run the fixture checks and inspect the candidate diff:

```bash
python -m unittest update-matt-skills/tests/test_sync.py
diff -ru . /tmp/matt-skills-update/candidate
```

Check intervening changelog and release-note sections in the report for semantic replacements that Git rename detection cannot identify. Validate changed skill frontmatter, bundled files, removed-skill references, and the behaviors documented in `references/CHANGES.md`.

Completion criterion: tests pass and every candidate difference is approved.

## 3. Apply

After explicit maintainer approval, run:

```bash
python update-matt-skills/scripts/sync.py apply \
  --skills . \
  /tmp/matt-skills-update
```

Apply syncs only manifest-managed destinations, keeps local-only skills untouched, verifies tombstones/frontmatter, and advances the pinned baseline only after verification. Read `apply-report.json` and resolve any stale-reference warnings before committing.
