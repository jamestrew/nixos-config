#!/usr/bin/env python3
"""Stage and apply reviewed updates from mattpocock/skills."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

MANAGED = {"tracked", "personalized"}
DEFAULT_MANIFEST = Path(__file__).parents[1] / "matt-skills.json"


def run(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or "command failed: " + " ".join(args))
    return result.stdout


def git(repo: Path, *args: str, check: bool = True) -> str:
    return run("git", "-C", str(repo), *args, check=check)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def tree(repo: Path, commit: str, source: str) -> dict[str, bytes] | None:
    source = source.removeprefix("./").rstrip("/")
    names = git(repo, "ls-tree", "-r", "--name-only", commit, "--", source).splitlines()
    files = {}
    prefix = source + "/"
    for name in names:
        if name.startswith(prefix):
            files[name[len(prefix):]] = subprocess.check_output(
                ["git", "-C", str(repo), "show", f"{commit}:{name}"]
            )
    return files or None


def disk_tree(path: Path) -> dict[str, bytes] | None:
    if not path.is_dir():
        return None
    return {
        str(file.relative_to(path)): file.read_bytes()
        for file in sorted(path.rglob("*"))
        if file.is_file()
    }


def write_tree(path: Path, files: dict[str, bytes] | None) -> None:
    shutil.rmtree(path, ignore_errors=True)
    if files is None:
        return
    for name, data in files.items():
        target = path / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)


def digest(files: dict[str, bytes] | None) -> str | None:
    if files is None:
        return None
    value = hashlib.sha256()
    for name, data in sorted(files.items()):
        value.update(name.encode() + b"\0" + data + b"\0")
    return value.hexdigest()


def merge_file(local: bytes, base: bytes, target: bytes) -> tuple[bytes, bool]:
    with tempfile.TemporaryDirectory() as temp:
        paths = [Path(temp) / name for name in ("local", "base", "target")]
        for path, data in zip(paths, (local, base, target)):
            path.write_bytes(data)
        result = subprocess.run(
            ["git", "merge-file", "-p", *map(str, paths)], capture_output=True
        )
        return result.stdout, result.returncode != 0


def merge_trees(
    local: dict[str, bytes], base: dict[str, bytes], target: dict[str, bytes]
) -> tuple[dict[str, bytes], list[str]]:
    merged, conflicts = {}, []
    for name in sorted(set(local) | set(base) | set(target)):
        l, b, t = local.get(name), base.get(name), target.get(name)
        if l == b:
            value = t
        elif t == b or l == t:
            value = l
        elif b is not None and l is not None and t is not None:
            value, conflict = merge_file(l, b, t)
            if conflict:
                conflicts.append(name)
        else:
            value = l
            conflicts.append(name)
        if value is not None:
            merged[name] = value
    return merged, conflicts


def inventory(repo: Path, commit: str, path: str) -> set[str]:
    raw = git(repo, "show", f"{commit}:{path}")
    return {item.removeprefix("./").rstrip("/") for item in json.loads(raw)["skills"]}


def checkout_repo(source: str) -> tuple[Path, tempfile.TemporaryDirectory | None]:
    local = Path(source).expanduser()
    if local.exists():
        return local.resolve(), None
    temp = tempfile.TemporaryDirectory(prefix="matt-skills-upstream-")
    repo = Path(temp.name) / "repo"
    run("git", "clone", "--quiet", "--filter=blob:none", source, str(repo))
    return repo, temp


def latest_tag(manifest: dict) -> str:
    github = manifest["upstream"].get("github")
    if not github:
        raise RuntimeError("--ref is required when upstream.github is absent")
    return run("gh", "api", f"repos/{github}/releases/latest", "--jq", ".tag_name").strip()


def copy_candidate(live: Path, candidate: Path) -> None:
    if candidate.exists():
        shutil.rmtree(candidate)
    shutil.copytree(
        live,
        candidate,
        ignore=shutil.ignore_patterns("__pycache__", "*-workspace"),
    )


def is_ancestor(repo: Path, older: str, newer: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor", older, newer],
        capture_output=True,
    ).returncode == 0


def release_notes(manifest: dict, baseline: str, target: str, repo: Path) -> list[dict]:
    github = manifest["upstream"].get("github")
    if not github or not shutil.which("gh"):
        return []
    raw = run("gh", "api", f"repos/{github}/releases?per_page=100", check=False)
    if not raw.strip():
        return []
    notes = []
    for release in json.loads(raw):
        tag = release.get("tag_name", "")
        commit = git(repo, "rev-parse", f"{tag}^{{commit}}", check=False).strip()
        if commit and commit != baseline and is_ancestor(repo, baseline, commit) and is_ancestor(repo, commit, target):
            notes.append({"tag": tag, "body": release.get("body") or ""})
    return list(reversed(notes))


def prepare(args: argparse.Namespace) -> int:
    live, manifest_path = args.skills.resolve(), args.manifest.resolve()
    manifest = load_json(manifest_path)
    repo_source = args.upstream or manifest["upstream"]["repository"]
    repo, temporary_repo = checkout_repo(repo_source)
    try:
        baseline = git(repo, "rev-parse", f"{manifest['upstream']['baseline_commit']}^{{commit}}").strip()
        target_tag = args.ref or latest_tag(manifest)
        target = git(repo, "rev-parse", f"{target_tag}^{{commit}}").strip()
        output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="matt-skills-candidate-"))
        if output == live or live in output.parents:
            raise RuntimeError("candidate output must be outside the live skills directory")
        output.mkdir(parents=True, exist_ok=True)
        candidate = output / "candidate"
        copy_candidate(live, candidate)

        inv_path = manifest["upstream"]["inventory"]
        baseline_inventory = inventory(repo, baseline, inv_path)
        target_inventory = inventory(repo, target, inv_path)
        configured = {entry["source"].removeprefix("./") for entry in manifest["entries"]}
        additions = sorted(target_inventory - configured)
        removals = sorted(
            entry["source"] for entry in manifest["entries"]
            if entry["status"] in MANAGED and entry["source"] not in target_inventory
        )
        results, unresolved, merge_conflicts = [], [], []

        for entry in manifest["entries"]:
            source, policy = entry["source"].removeprefix("./"), entry["status"]
            if policy not in MANAGED:
                for tombstone in entry.get("tombstones", []):
                    shutil.rmtree(candidate / tombstone, ignore_errors=True)
                results.append({"source": source, "policy": policy, "action": "kept absent"})
                continue

            destination = entry["destination"]
            base_files, target_files = tree(repo, baseline, source), tree(repo, target, source)
            local_files = disk_tree(live / destination)
            action, conflicts = "preserved local", []
            if target_files is None:
                action = "upstream removal requires decision"
                unresolved.append(source)
            elif local_files is None:
                action = "missing local destination"
                unresolved.append(destination)
            elif local_files == base_files:
                write_tree(candidate / destination, target_files)
                action = "updated from upstream"
            elif target_files == base_files or local_files == target_files:
                action = "preserved local"
            elif base_files is None:
                action = "no merge baseline"
                unresolved.append(source)
            else:
                merged, conflicts = merge_trees(local_files, base_files, target_files)
                write_tree(candidate / destination, merged)
                action = "merged" if not conflicts else "merge conflict"
                if conflicts:
                    merge_conflicts.append(source)
            results.append({
                "source": source,
                "destination": destination,
                "policy": policy,
                "action": action,
                "conflicts": conflicts,
                "baseline_hash": digest(base_files),
                "local_hash": digest(local_files),
                "target_hash": digest(target_files),
            })

        unresolved.extend(additions + removals)
        diff = git(
            repo, "diff", "--name-status", "--find-renames", baseline, target,
            "--", "skills", inv_path, "CHANGELOG.md"
        )
        changelog = git(repo, "diff", baseline, target, "--", "CHANGELOG.md")
        state = {
            "schema_version": 1,
            "manifest": str(manifest_path),
            "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            "live": str(live),
            "baseline_commit": baseline,
            "target_tag": target_tag,
            "target_commit": target,
            "inventory_additions": additions,
            "inventory_removals": removals,
            "blocking_decisions": sorted(set(unresolved)),
            "merge_conflicts": sorted(set(merge_conflicts)),
            "unresolved": sorted(set(unresolved + merge_conflicts)),
            "results": results,
        }
        (output / "report.json").write_text(json.dumps(state, indent=2) + "\n")
        notes = release_notes(manifest, baseline, target, repo)
        lines = [
            "# Matt skills update candidate", "",
            f"- Baseline: `{baseline}`", f"- Target: `{target_tag}` (`{target}`)",
            f"- Candidate: `{candidate}`", f"- Unresolved decisions: **{len(state['unresolved'])}**", "",
            "## Inventory decisions", "",
            f"- Additions: {', '.join(additions) or 'none'}",
            f"- Removed managed paths: {', '.join(removals) or 'none'}", "",
            "## Managed skills", "",
            "| Destination | Policy | Candidate action |", "| --- | --- | --- |",
        ]
        lines.extend(
            f"| {item.get('destination', item['source'])} | {item['policy']} | {item['action']} |"
            for item in results
        )
        lines += ["", "## Upstream path changes", "", "```text", diff.rstrip() or "(none)", "```"]
        if changelog:
            lines += ["", "## Changelog diff", "", "```diff", changelog.rstrip(), "```"]
        if notes:
            lines += ["", "## GitHub release notes"]
            for note in notes:
                lines += ["", f"### {note['tag']}", "", note["body"] or "(empty)"]
        (output / "report.md").write_text("\n".join(lines) + "\n")
        print(output)
        return 2 if state["unresolved"] else 0
    finally:
        del temporary_repo


def validate_skill(path: Path) -> list[str]:
    skill = path / "SKILL.md"
    if not skill.is_file():
        return [f"missing {skill}"]
    text = skill.read_text(errors="replace")
    if not re.match(r"^---\n(?:(?!\n---\n).)*\n---\n", text, re.S):
        return [f"invalid frontmatter in {skill}"]
    header = text.split("\n---\n", 1)[0]
    return [f"missing {key} in {skill}" for key in ("name:", "description:") if key not in header]


def apply(args: argparse.Namespace) -> int:
    output, live, manifest_path = args.candidate.resolve(), args.skills.resolve(), args.manifest.resolve()
    state = load_json(output / "report.json")
    manifest = load_json(manifest_path)
    if state.get("blocking_decisions", state["unresolved"]):
        raise RuntimeError(
            "candidate has unresolved inventory decisions: "
            + ", ".join(state.get("blocking_decisions", state["unresolved"]))
        )
    if hashlib.sha256(manifest_path.read_bytes()).hexdigest() != state["manifest_sha256"]:
        raise RuntimeError("manifest changed after preparation; prepare again")
    for result in state["results"]:
        if result.get("destination") and digest(disk_tree(live / result["destination"])) != result["local_hash"]:
            raise RuntimeError(f"live skill changed after preparation: {result['destination']}")
    candidate = output / "candidate"
    errors = []
    for entry in manifest["entries"]:
        if entry["status"] in MANAGED:
            destination = candidate / entry["destination"]
            errors += validate_skill(destination)
            for file in destination.rglob("*") if destination.exists() else []:
                if file.is_file() and b"<<<<<<<" in file.read_bytes():
                    errors.append(f"unresolved merge marker in {file}")
        elif entry["status"] == "replaced":
            errors += validate_skill(candidate / entry["replacement"])
    if errors:
        raise RuntimeError("candidate validation failed:\n" + "\n".join(errors))

    backup = Path(tempfile.mkdtemp(prefix="matt-skills-rollback-"))
    touched = []
    try:
        for entry in manifest["entries"]:
            if entry["status"] in MANAGED:
                destination = entry["destination"]
                touched.append(destination)
                if (live / destination).exists():
                    shutil.copytree(live / destination, backup / destination)
                write_tree(live / destination, disk_tree(candidate / destination))
            else:
                for tombstone in entry.get("tombstones", []):
                    touched.append(tombstone)
                    if (live / tombstone).exists():
                        shutil.copytree(live / tombstone, backup / tombstone)
                    shutil.rmtree(live / tombstone, ignore_errors=True)
        errors = []
        for entry in manifest["entries"]:
            if entry["status"] in MANAGED:
                errors += validate_skill(live / entry["destination"])
            elif entry["status"] == "replaced":
                errors += validate_skill(live / entry["replacement"])
            for tombstone in entry.get("tombstones", []):
                if (live / tombstone).exists():
                    errors.append(f"tombstone reappeared: {tombstone}")
        if errors:
            raise RuntimeError("live verification failed:\n" + "\n".join(errors))

        manifest["upstream"]["baseline_tag"] = state["target_tag"]
        manifest["upstream"]["baseline_commit"] = state["target_commit"]
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        tombstones = [t for e in manifest["entries"] for t in e.get("tombstones", [])]
        stale = []
        for file in live.glob("*/SKILL.md"):
            for name in tombstones:
                if name in file.read_text(errors="replace"):
                    stale.append(f"{file.relative_to(live)} mentions {name}")
        report = {"applied": state["target_commit"], "validation_errors": [], "stale_references": stale}
        (output / "apply-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print("Applied " + state["target_commit"])
        if stale:
            print("Review stale-reference warnings in apply-report.json", file=sys.stderr)
        return 0
    except Exception:
        for destination in set(touched):
            shutil.rmtree(live / destination, ignore_errors=True)
            if (backup / destination).exists():
                shutil.copytree(backup / destination, live / destination)
        raise
    finally:
        shutil.rmtree(backup, ignore_errors=True)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    for name in ("prepare", "apply"):
        command = sub.add_parser(name)
        command.add_argument("--skills", type=Path, required=True, help="live skills directory")
        command.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
        if name == "prepare":
            command.add_argument("--ref", help="target release tag or commit")
            command.add_argument("--upstream", help="upstream URL or local fixture repository")
            command.add_argument("--output", type=Path)
        else:
            command.add_argument("candidate", type=Path, help="prepared output directory")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        return prepare(args) if args.command == "prepare" else apply(args)
    except (RuntimeError, OSError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
