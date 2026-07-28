# Personalizations

Local modifications to the off-the-shelf [`mattpocock/skills`](https://github.com/mattpocock/skills) set, kept separate from the vendored skills so upstream updates can be pulled and re-applied mechanically.

## Layout

| Path | What it is |
| --- | --- |
| `upstream/<skill>/SKILL.md` | Pristine upstream copy, as vendored, **before** any local edit. The merge baseline. |
| `upstream/BASELINE.sha256` | Hashes of those pristine files, to confirm the baseline hasn't drifted. |
| `patches/<skill>.patch` | Unified diff turning the pristine file into the personalized one. Applies with `patch -p1`. |
| `removed/<skill>/SKILL.md` | A skill deleted outright, kept verbatim so it can be restored. |
| `skills-lock.json.orig` | The lock file before entries were removed for deleted skills. |

Personalized skills: **`to-spec`, `to-tickets`, `triage`, `wayfinder`, `implement`, `tdd`**.
Deleted: **`code-review`** (superseded by the local `thermonuclear-review` skill).

Everything else is untouched upstream, including `setup-matt-pocock-skills` — which is now vestigial (see `CHANGES.md`).

## Re-applying after an upstream update

The patches are verified to apply cleanly to the recorded baseline. After pulling new skills:

```bash
cd /tmp/mp-skills   # repo root — wherever .agents/ and skills-lock.json live

# 1. What changed upstream since the baseline? Empty output = nothing to merge.
for s in to-spec to-tickets triage wayfinder implement tdd; do
  diff -u ".personalization/upstream/$s/SKILL.md" ".agents/skills/$s/SKILL.md" && echo "$s: upstream unchanged"
done

# 2. Re-apply the personalization on top of the new upstream file.
for s in to-spec to-tickets triage wayfinder implement tdd; do
  patch -p1 --dry-run -d .agents/skills < ".personalization/patches/$s.patch"
done
# If the dry run is clean, drop --dry-run and run it for real.

# 3. Re-baseline: snapshot the NEW pristine upstream, then regenerate the patch.
#    Do this BEFORE applying in step 2 — the pristine copy is unrecoverable afterwards.
```

If a hunk is rejected, upstream rewrote the same passage the personalization targets. Read `CHANGES.md` for the *intent* behind that hunk and re-apply it by hand against the new wording, then regenerate the patch:

```bash
diff -u ".personalization/upstream/$s/SKILL.md" ".agents/skills/$s/SKILL.md" \
  --label "a/$s/SKILL.md" --label "b/$s/SKILL.md" > ".personalization/patches/$s.patch"
```

The intent matters more than the diff. `CHANGES.md` records why each change exists so it survives an upstream rewrite that invalidates the literal patch.

## Deleted skills

`code-review` was deleted, and its `skills-lock.json` entry removed so the updater stops managing it. After any update, check it hasn't come back:

```bash
ls .agents/skills/code-review 2>/dev/null && echo "code-review reappeared — delete it and drop its lock entry again"
```

Also re-check the `tdd` pointer: it references the `implement` skill's review rounds, and an upstream `tdd` update could restore the original pointer to the now-deleted `code-review`.

## A caveat about `skills-lock.json`

Each skill in `skills-lock.json` carries a `computedHash`. That hash is **not** a plain `sha256` of `SKILL.md` — the on-disk hashes of the untouched files did not match their lock entries, so the exact derivation is unknown and the file should not be hand-edited.

The practical consequence: the updater may treat a personalized skill as drifted, and could warn, refuse, or overwrite. That is precisely why the pristine copies and patches exist — **an overwrite is recoverable**, because the personalization lives here rather than only in the working file. Assume an update can clobber any of the six personalized skills, and re-apply from `patches/` afterwards.

Removing a whole entry from the lock file (as done for `code-review`) is safe — it's plain JSON deletion, not a hash that has to be recomputed.
