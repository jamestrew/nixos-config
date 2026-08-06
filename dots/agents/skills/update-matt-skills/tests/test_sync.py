from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "scripts" / "sync.py"


class Fixture:
    def __init__(self, test: unittest.TestCase):
        self.test = test
        self.temp = tempfile.TemporaryDirectory()
        test.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.upstream = self.root / "upstream"
        self.live = self.root / "skills"
        self.output = self.root / "output"
        self.manifest = self.root / "manifest.json"
        self.upstream.mkdir()
        self.live.mkdir()
        self.git("init", "-q")
        self.git("config", "user.email", "fixture@example.com")
        self.git("config", "user.name", "Fixture")

    def git(self, *args: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(self.upstream), *args], text=True
        ).strip()

    def write_upstream(self, paths: dict[str, str], inventory: list[str], changelog: str = "") -> None:
        for old in (self.upstream / "skills").glob("*/*") if (self.upstream / "skills").exists() else []:
            if old.is_dir():
                shutil.rmtree(old)
        for path, body in paths.items():
            target = self.upstream / path / "SKILL.md"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(body)
        plugin = self.upstream / ".claude-plugin" / "plugin.json"
        plugin.parent.mkdir(parents=True, exist_ok=True)
        plugin.write_text(json.dumps({"name": "fixture", "skills": ["./" + p for p in inventory]}))
        (self.upstream / "CHANGELOG.md").write_text(changelog)

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "-qm", message)
        return self.git("rev-parse", "HEAD")

    def write_local(self, destination: str, body: str, extra: dict[str, str] | None = None) -> None:
        path = self.live / destination
        path.mkdir(parents=True, exist_ok=True)
        (path / "SKILL.md").write_text(body)
        for name, value in (extra or {}).items():
            (path / name).write_text(value)

    def configure(self, baseline: str, entries: list[dict]) -> None:
        self.manifest.write_text(json.dumps({
            "schema_version": 1,
            "upstream": {
                "repository": str(self.upstream),
                "baseline_tag": "baseline",
                "baseline_commit": baseline,
                "inventory": ".claude-plugin/plugin.json",
            },
            "entries": entries,
        }))

    def prepare(self, target: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([
            "python3", str(SCRIPT), "prepare", "--skills", str(self.live),
            "--manifest", str(self.manifest), "--upstream", str(self.upstream),
            "--ref", target, "--output", str(self.output),
        ], text=True, capture_output=True)

    @staticmethod
    def skill(name: str, text: str) -> str:
        return f"---\nname: {name}\ndescription: fixture\n---\n\n{text}\n"


class SyncTests(unittest.TestCase):
    def test_untouched_tracked_skill_updates_and_apply_advances_baseline(self):
        f = Fixture(self)
        base_body = f.skill("tracked", "base")
        f.write_upstream({"skills/engineering/tracked": base_body}, ["skills/engineering/tracked"])
        baseline = f.commit("baseline")
        f.write_local("tracked", base_body)
        (f.live / "local-only").mkdir()
        (f.live / "local-only" / "note").write_text("keep")
        target_body = f.skill("tracked", "target")
        f.write_upstream({"skills/engineering/tracked": target_body}, ["skills/engineering/tracked"])
        target = f.commit("target")
        f.configure(baseline, [{"source": "skills/engineering/tracked", "destination": "tracked", "status": "tracked"}])

        result = f.prepare(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((f.live / "tracked" / "SKILL.md").read_text(), base_body)
        self.assertEqual((f.output / "candidate" / "tracked" / "SKILL.md").read_text(), target_body)
        self.assertEqual((f.output / "candidate" / "local-only" / "note").read_text(), "keep")

        (f.live / "tracked" / "SKILL.md").write_text(f.skill("tracked", "intervening edit"))
        stale = subprocess.run([
            "python3", str(SCRIPT), "apply", "--skills", str(f.live),
            "--manifest", str(f.manifest), str(f.output),
        ], text=True, capture_output=True)
        self.assertNotEqual(stale.returncode, 0)
        self.assertEqual(json.loads(f.manifest.read_text())["upstream"]["baseline_commit"], baseline)
        (f.live / "tracked" / "SKILL.md").write_text(base_body)

        applied = subprocess.run([
            "python3", str(SCRIPT), "apply", "--skills", str(f.live),
            "--manifest", str(f.manifest), str(f.output),
        ], text=True, capture_output=True)
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertEqual((f.live / "tracked" / "SKILL.md").read_text(), target_body)
        self.assertEqual((f.live / "local-only" / "note").read_text(), "keep")
        self.assertEqual(json.loads(f.manifest.read_text())["upstream"]["baseline_commit"], target)

    def test_personalized_skill_merges_nonoverlap_and_surfaces_overlap(self):
        f = Fixture(self)
        base_body = f.skill("personal", "line one\nline two\nline three")
        source = "skills/engineering/personal"
        f.write_upstream({source: base_body}, [source])
        baseline = f.commit("baseline")
        local_body = f.skill("personal", "local one\nline two\nline three")
        f.write_local("personal", local_body, {"LOCAL.md": "intent\n"})
        target_body = f.skill("personal", "line one\nline two\ntarget three")
        f.write_upstream({source: target_body}, [source])
        target = f.commit("nonoverlap")
        entry = {"source": source, "destination": "personal", "status": "personalized"}
        f.configure(baseline, [entry])

        result = f.prepare(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        candidate = (f.output / "candidate" / "personal" / "SKILL.md").read_text()
        self.assertIn("local one", candidate)
        self.assertIn("target three", candidate)
        self.assertEqual((f.output / "candidate" / "personal" / "LOCAL.md").read_text(), "intent\n")

        f.write_upstream({source: f.skill("personal", "upstream one\nline two\nline three")}, [source])
        conflict_target = f.commit("overlap")
        result = f.prepare(conflict_target)
        self.assertEqual(result.returncode, 2, result.stderr)
        state = json.loads((f.output / "report.json").read_text())
        self.assertIn(source, state["unresolved"])
        self.assertIn("<<<<<<<", (f.output / "candidate" / "personal" / "SKILL.md").read_text())

    def test_new_promoted_skill_requires_inventory_decision(self):
        f = Fixture(self)
        body = f.skill("old", "base")
        old, new = "skills/engineering/old", "skills/engineering/new"
        f.write_upstream({old: body}, [old])
        baseline = f.commit("baseline")
        f.write_local("old", body)
        f.write_upstream({old: body, new: f.skill("new", "new")}, [old, new])
        target = f.commit("add promoted skill")
        f.configure(baseline, [{"source": old, "destination": "old", "status": "tracked"}])
        result = f.prepare(target)
        self.assertEqual(result.returncode, 2)
        self.assertIn(new, json.loads((f.output / "report.json").read_text())["inventory_additions"])

    def test_rename_or_replacement_is_reported_with_changelog(self):
        f = Fixture(self)
        old, new = "skills/productivity/old-name", "skills/productivity/new-name"
        body = f.skill("old-name", "content")
        f.write_upstream({old: body}, [old], "# Changes\n")
        baseline = f.commit("baseline")
        f.write_local("old-name", body)
        f.write_upstream({new: f.skill("new-name", "content")}, [new], "# Changes\nold-name became new-name\n")
        target = f.commit("rename skill")
        f.configure(baseline, [{"source": old, "destination": "old-name", "status": "tracked"}])
        result = f.prepare(target)
        self.assertEqual(result.returncode, 2)
        report = (f.output / "report.md").read_text()
        self.assertIn("old-name became new-name", report)
        self.assertIn(new, report)

    def test_excluded_skill_reappearing_stays_absent(self):
        f = Fixture(self)
        source = "skills/engineering/excluded"
        f.write_upstream({source: f.skill("excluded", "base")}, [source])
        baseline = f.commit("baseline")
        f.write_local("excluded", f.skill("excluded", "accidental local copy"))
        f.write_upstream({source: f.skill("excluded", "upstream edit")}, [source])
        target = f.commit("reappears")
        f.configure(baseline, [{"source": source, "status": "excluded", "tombstones": ["excluded"]}])
        result = f.prepare(target)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((f.output / "candidate" / "excluded").exists())
        self.assertTrue((f.live / "excluded").exists(), "prepare mutated live tree")

    def test_removed_tracked_skill_blocks_apply_and_baseline_advance(self):
        f = Fixture(self)
        source = "skills/engineering/removed"
        body = f.skill("removed", "base")
        f.write_upstream({source: body}, [source])
        baseline = f.commit("baseline")
        f.write_local("removed", body)
        f.write_upstream({}, [], "# Changes\nremoved retired\n")
        target = f.commit("remove skill")
        f.configure(baseline, [{"source": source, "destination": "removed", "status": "tracked"}])
        result = f.prepare(target)
        self.assertEqual(result.returncode, 2)
        applied = subprocess.run([
            "python3", str(SCRIPT), "apply", "--skills", str(f.live),
            "--manifest", str(f.manifest), str(f.output),
        ], text=True, capture_output=True)
        self.assertNotEqual(applied.returncode, 0)
        self.assertEqual(json.loads(f.manifest.read_text())["upstream"]["baseline_commit"], baseline)
        self.assertTrue((f.live / "removed").exists())


if __name__ == "__main__":
    unittest.main()
