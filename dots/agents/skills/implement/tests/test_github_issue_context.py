import importlib.util
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "scripts" / "github_issue_context.py"
SPEC = importlib.util.spec_from_file_location("github_issue_context", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ReferencedIssueUrlsTest(unittest.TestCase):
    def test_extracts_and_deduplicates_supported_references(self):
        body = """
        Follow up in #12 and owner/other#34.
        See https://github.example.com/third/project/issues/56.
        Duplicate: owner/other#34.
        """

        self.assertEqual(
            MODULE.referenced_issue_urls(
                body, "https://github.example.com/acme/widgets/issues/1"
            ),
            [
                "https://github.example.com/third/project/issues/56",
                "https://github.example.com/owner/other/issues/34",
                "https://github.example.com/acme/widgets/issues/12",
            ],
        )


class RepositoryInferenceTest(unittest.TestCase):
    def test_converts_common_remote_urls(self):
        self.assertEqual(
            MODULE.repository_from_remote("git@github.com:acme/widgets.git"),
            "acme/widgets",
        )
        self.assertEqual(
            MODULE.repository_from_remote(
                "https://github.example.com/acme/widgets.git"
            ),
            "github.example.com/acme/widgets",
        )

    @patch.object(MODULE.subprocess, "run")
    def test_infers_repository_from_jj_without_calling_git(self, run):
        run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="origin git@github.com:acme/widgets.git\n"
        )

        self.assertEqual(MODULE.infer_repository(), "acme/widgets")
        run.assert_called_once_with(
            ["jj", "--ignore-working-copy", "git", "remote", "list"],
            check=True,
            capture_output=True,
            text=True,
        )


class IssueOutputTest(unittest.TestCase):
    def test_keeps_only_implementation_context(self):
        issue = {
            "number": 2,
            "title": "Implement CLI",
            "url": "https://github.com/acme/widgets/issues/2",
            "body": "Acceptance criteria",
            "comments": [
                {
                    "body": "Clarified requirement",
                    "author": {"login": "someone"},
                    "reactionGroups": [],
                }
            ],
            "parent": {"url": "https://github.com/acme/widgets/issues/1", "id": "opaque"},
        }

        self.assertEqual(
            MODULE.implementation_context(issue),
            {
                "number": 2,
                "title": "Implement CLI",
                "url": "https://github.com/acme/widgets/issues/2",
                "body": "Acceptance criteria",
                "comments": ["Clarified requirement"],
            },
        )


if __name__ == "__main__":
    unittest.main()
