# How `npx skills add mattpocock/skills` groups skills

Researched 2026-08-05 against `vercel-labs/skills` v1.5.22 (`a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5`), `mattpocock/skills` v1.2.2 (`8b36d4fb2635b3c21998dcd8144439c9e5ba7302`), and Claude Code's official marketplace at `36b00173da517876f9e574ef98f3564b0e86c25d`. Links below are pinned to those commits unless they point to official living documentation.

## Short answer

`npx skills` is the executable named `skills` from the npm package also named **`skills`**, whose source repository is `vercel-labs/skills`. The published package maps both `skills` and the legacy `add-skill` binary names to `bin/cli.mjs`; that entry point loads `dist/cli.mjs`. This is confirmed independently by the [npm registry's published metadata](https://registry.npmjs.org/skills/latest), the CLI repository's [`package.json`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/package.json#L2-L14), and its [`bin/cli.mjs`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/bin/cli.mjs#L1-L14).

For `mattpocock/skills`, the selectable heading **“Mattpocock Skills”** comes from `.claude-plugin/plugin.json`'s `name` field, **`mattpocock-skills`**. The CLI's `getPluginGroupings()` attaches that manifest name only to the skill directories explicitly listed in the same file's `skills` array; `runAdd()` then converts the kebab-case value to title case. It does not use GitHub repository metadata, `package.json`, the repository name, the skill bucket directory, or generated metadata for this heading. See the upstream [plugin manifest's `name` and `skills` fields](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/.claude-plugin/plugin.json#L2-L47), the CLI's [`getPluginGroupings()` implementation](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/plugin-manifest.ts#L114-L182), and the [title conversion and prompt construction](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/add.ts#L1323-L1360).

At the researched revisions, repository discovery finds **35** valid `SKILL.md` files, but only the **25 promoted skills** explicitly listed in `.claude-plugin/plugin.json.skills` belong to “Mattpocock Skills.” The six `skills/in-progress/*` and four `skills/misc/*` skills are still discoverable by `npx skills add`; because their paths are absent from the manifest, the interactive selector places them in **“Other.”** The native Claude Code plugin differs: it installs the manifest-curated promoted set as one managed plugin, with no per-skill selection.

## What the CLI actually does

### 1. Resolve and fetch the repository

`parseSource()` recognizes `owner/repo` as GitHub shorthand and resolves `mattpocock/skills` to `https://github.com/mattpocock/skills.git`; see the [`shorthandMatch` branch](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/source-parser.ts#L433-L463). In v1.5.22, `runAdd()` uses a GitHub blob fast path only for a small allowlist of owners; `mattpocock` is not on it, so the command clones the repository into a temporary directory and calls `discoverSkills()` on that checkout. See [`runAdd()`'s fetch/clone branches](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/add.ts#L1145-L1227).

### 2. Discover candidates from the filesystem

`discoverSkills()` does **not** treat a plugin manifest as an exclusive repository inventory. Its default priority roots include the repository root, `skills/`, several conventional subdirectories, and agent-specific skill directories. Known skill containers are walked to a bounded depth of three, enough to reach Matt Pocock's `skills/<bucket>/<skill>/SKILL.md` layout. Manifest-declared locations are appended as additional search roots, not used as an allowlist. See [`prioritySearchDirs`, `deepContainerDirs`, and the walk](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/skills.ts#L247-L303), the [`DEFAULT_SKILL_CONTAINER_DEPTH = 3` constant](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/constants.ts#L1-L6), and [`getPluginSkillPaths()`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/plugin-manifest.ts#L42-L112).

A directory becomes an installable candidate when it has a readable `SKILL.md` with string-valued `name` and `description` frontmatter. A skill with `metadata.internal: true` is hidden unless internal skills are enabled or a specific skill was explicitly requested. Discovery deduplicates candidates by frontmatter `name`. These rules are in [`parseSkillMd()`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/skills.ts#L77-L130) and [`discoverSkills()`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/skills.ts#L175-L227). None of the current Matt Pocock skills is marked internal.

Consequently, the default command discovers every current skill in these buckets:

| Bucket | Discovered | Group in the interactive CLI | Native Claude plugin |
| --- | ---: | --- | --- |
| `skills/engineering` | 18 | Mattpocock Skills | Included |
| `skills/productivity` | 7 | Mattpocock Skills | Included |
| `skills/in-progress` | 6 | Other | Excluded |
| `skills/misc` | 4 | Other | Excluded |
| `skills/deprecated` | 0 | N/A | Excluded |

The category names themselves have no special meaning to the CLI. Today, all 25 paths in the plugin manifest happen to be under `engineering` or `productivity`, but membership comes from the explicit paths, not from those directory names. Upstream records the same product distinction: engineering and productivity are promoted, while misc, in-progress, deprecated, and the former personal bucket are not; see the repository's [plugin-distribution ADR](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/.agents/adr/0002-ship-as-a-claude-code-plugin.md#L7-L17).

### 3. Attach the group and render its name

Before filesystem discovery, `discoverSkills()` asks `getPluginGroupings()` for a map from absolute skill-directory paths to plugin names. `getPluginGroupings()` reads local `.claude-plugin/marketplace.json` plugin entries **only when an entry has both a `name` and explicit `skills` paths**, then reads root `.claude-plugin/plugin.json` and maps every valid explicit `skills` path to its `name`. `discoverSkills()` copies that value into `Skill.pluginName` only on exact path matches. See [`getPluginGroupings()`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/plugin-manifest.ts#L114-L182), [`discoverSkills()`'s `enhanceSkill()`](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/skills.ts#L193-L206), and the [`Skill.pluginName` field](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/types.ts#L79-L88).

Matt Pocock's `marketplace.json` does name a plugin, but it has no `skills` array, so it contributes no per-skill grouping to this CLI. The operative data is the root `plugin.json`, which contains `"name": "mattpocock-skills"` and 25 explicit skill paths. Compare [`.claude-plugin/marketplace.json`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/.claude-plugin/marketplace.json#L1-L23) with [`.claude-plugin/plugin.json`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/.claude-plugin/plugin.json#L1-L47). The repository `package.json` happens to repeat `mattpocock-skills`, but it is private release tooling and the CLI grouping code never reads it; see [`package.json`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/package.json#L1-L20).

Finally, `runAdd()` sorts grouped skills first, converts `mattpocock-skills` by splitting on `-` and capitalizing each word, and assigns ungrouped candidates to `Other`. The same grouping is used by `--list`; see the [list rendering](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/add.ts#L1242-L1289) and [interactive rendering](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/add.ts#L1323-L1360).

## Interactive CLI versus native Claude Code plugin

These are two distribution mechanisms consuming some of the same repository metadata, not two front ends to one installer.

| Behavior | `npx skills add mattpocock/skills` | `claude plugins install mattpocock-skills` |
| --- | --- | --- |
| Inventory scanned | Filesystem discovery across the repository (35 current skills) | Explicit promoted paths in the plugin manifest (25 current skills) |
| Selection | Interactive per-skill/group selection, or `--skill`/`--all` | Installs the plugin's whole curated skill set; no per-skill picker |
| Non-promoted skills | Discoverable under `Other`; an in-progress skill may be named directly | Excluded |
| Local form | Copies/symlinks ordinary editable skill files into agent directories | Managed, read-only plugin bundle |
| Updating | `npx skills update` against the install lock/provenance | Claude plugin version/marketplace update mechanism |

The upstream installation guide explicitly describes the native plugin as the whole managed bundle and `npx skills` as editable files with a skill picker; it also warns against installing both because that duplicates every promoted skill. See the [installation section](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/README.md#L25-L71). The official Claude Code reference says plugin skills are loaded from the default `skills/` location and any custom `skills` manifest paths, and defines `skills` as a string-or-array component path field; see [Skills](https://code.claude.com/docs/en/plugins-reference#skills), [Component path fields](https://code.claude.com/docs/en/plugins-reference#component-path-fields), and [Path behavior rules](https://code.claude.com/docs/en/plugins-reference#path-behavior-rules). Matt's bucket directories are one level below `skills/` and do not themselves contain `SKILL.md`, so the manifest's explicit leaf paths are what make the promoted skills native plugin components.

The official marketplace does not follow the repository's moving `main` branch implicitly: its listing contains a source URL plus a pinned commit SHA. At the research snapshot, it pins exactly `8b36d4f`, so the live listing and the 25-path v1.2.2 manifest agree; see the official marketplace's [`mattpocock-skills` entry](https://github.com/anthropics/claude-plugins-official/blob/36b00173da517876f9e574ef98f3564b0e86c25d/.claude-plugin/marketplace.json#L2107-L2118). A future upstream commit is therefore not necessarily available through native Claude until the marketplace pin moves, even if the repository manifest has already changed.

Frontmatter such as Claude's `disable-model-invocation` and Codex's neighboring `agents/openai.yaml` controls **who may invoke a skill after it is installed**, not whether it belongs to the group or plugin. The promoted manifest intentionally contains both user-invoked and model-invoked skills; the current invocation split is documented in the [engineering](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/skills/engineering/README.md#L5-L32) and [productivity](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/skills/productivity/README.md#L5-L20) bucket READMEs.

## Renames, deprecations, in-progress work, and removals

There is no tombstone or alias registry.

- **In progress:** a real skill directory remains under `skills/in-progress`, so filesystem discovery exposes it under `Other`, while omission from `plugin.json.skills` keeps it out of the native plugin. Upstream calls this a beta channel and documents direct `--skill=<name>` installation in [`skills/in-progress/README.md`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/skills/in-progress/README.md#L1-L16).
- **Misc:** a real skill directory under `skills/misc` behaves the same way: discoverable under `Other`, not promoted. See [`skills/misc/README.md`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/skills/misc/README.md#L1-L8).
- **Deprecated:** the bucket is currently empty. Its policy is to delete a retired skill and name the replacement in the removal changeset, not keep a deprecated installable directory; see [`skills/deprecated/README.md`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/skills/deprecated/README.md#L1-L3).
- **Renamed or replaced:** the old directory/path disappears, the new one appears, the promoted manifest is updated if applicable, and the changelog explains the transition. For example, v1.2.0 says `writing-great-skills` became `writing-for-agents`, the old name is gone with no alias, and users should reinstall; see [`CHANGELOG.md`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/CHANGELOG.md#L68-L78).
- **Removed:** the directory and any manifest entry disappear. The only durable explanation is git history/changelog/release metadata. The current changelog records six removals, their replacements where applicable, and the fact that they were never in the native plugin but had been discoverable through the universal installer; see [`CHANGELOG.md`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/CHANGELOG.md#L118-L132).

An updater therefore cannot infer rename versus delete-plus-add from the current tree alone. It must compare two upstream revisions and read the intervening `CHANGELOG.md`, release notes, changesets, commits, or PRs for intent.

## Recommendation for the future updater

Use **`.claude-plugin/plugin.json.skills` as the authoritative machine-readable inventory of the promoted Matt Pocock set**. It is the exact source of the current “Mattpocock Skills” group membership, it is explicit rather than inferred from bucket layout, and upstream has made “every promoted skill has an entry” an invariant. See the [ADR invariant](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/.agents/adr/0002-ship-as-a-claude-code-plugin.md#L19-L28). Do not assume `skills/engineering`, because promoted membership already spans `engineering` and `productivity`, and future promotion could add another path without preserving that assumption.

The updater should maintain three distinct data sources:

1. **Desired upstream inventory:** the `plugin.json.skills` array at a pinned upstream tag or commit.
2. **Local provenance/baseline:** the updater skill's `matt-skills.json`, which pins the imported commit and maps upstream sources to tracked, personalized, excluded, or replaced local entries.
3. **Lifecycle intent:** diff the old and new manifest/tree, then inspect the intervening changelog, release notes, and linked changesets/PRs before classifying a missing path as removed, renamed, or replaced.

Use a Matt Pocock release tag/commit as the local updater's source revision. Read Claude's official marketplace pin only when the goal is to reproduce the version currently distributed by native Claude Code; it can legitimately lag upstream.

If the user intentionally wants beta or misc skills too, record those as explicit opt-ins in the updater's own configuration. There is no upstream machine-readable all-skills manifest with lifecycle status: `scripts/list-skills.sh` merely finds every `SKILL.md`, and the CLI itself discovers from the filesystem. The script is useful as a completeness check but cannot distinguish promoted, beta, misc, renamed, or removed entries; see [`scripts/list-skills.sh`](https://github.com/mattpocock/skills/blob/8b36d4fb2635b3c21998dcd8144439c9e5ba7302/scripts/list-skills.sh#L1-L7).

Pin both the upstream repo revision and the CLI version while evaluating updates. An unqualified `npx skills` follows npm's current package resolution, so its discovery algorithm can change independently of the Matt Pocock repository.

## Read-only reproduction

These commands query published metadata and repository content only. They neither install skills nor modify local skill directories.

Confirm the npm package and binary mapping:

```bash
curl -fsSL https://registry.npmjs.org/skills/latest |
  jq '{name, version, bin, repository}'
```

Inspect the pinned group name and promoted inventory:

```bash
MATT_REF=8b36d4fb2635b3c21998dcd8144439c9e5ba7302
curl -fsSL "https://raw.githubusercontent.com/mattpocock/skills/$MATT_REF/.claude-plugin/plugin.json" |
  jq '{name, count: (.skills | length), skills}'
```

Compare every current skill directory with the promoted manifest. The left column is the manifest set; the right-only lines are discoverable-but-unpromoted paths:

```bash
MATT_REF=8b36d4fb2635b3c21998dcd8144439c9e5ba7302
comm -3 \
  <(curl -fsSL "https://raw.githubusercontent.com/mattpocock/skills/$MATT_REF/.claude-plugin/plugin.json" |
      jq -r '.skills[]' | sort) \
  <(curl -fsSL "https://api.github.com/repos/mattpocock/skills/git/trees/$MATT_REF?recursive=1" |
      jq -r '.tree[].path | select(test("^skills/[^/]+/[^/]+/SKILL.md$")) |
             "./" + sub("/SKILL.md$"; "")' | sort)
```

At the researched revision, that comparison prints ten right-only paths: six under `skills/in-progress` and four under `skills/misc`.

To observe the CLI's own grouped list without installing any skills, run it from a throwaway working directory with a disposable npm cache and telemetry disabled:

```bash
scratch_dir="$(mktemp -d)"
cache_dir="$(mktemp -d)"
(
  cd "$scratch_dir"
  DISABLE_TELEMETRY=1 npm_config_cache="$cache_dir" \
    npx --yes skills@1.5.22 add mattpocock/skills --list
)
rm -r "$scratch_dir" "$cache_dir"
```

`--list` exits before the installation flow; it is documented as “List available skills in the repository without installing” in the CLI's [help](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/src/cli.ts#L135-L145) and [README](https://github.com/vercel-labs/skills/blob/a4d243c3d4f86cdf9385dd1b6a0733f6937e70b5/README.md#L50-L70). The disposable cache prevents `npx` from leaving package-cache state behind.
