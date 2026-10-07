#!/usr/bin/env python3
"""Dump a GitHub issue and its directly related context as JSON."""

import argparse
import json
import re
import subprocess
from urllib.parse import urlsplit

FIELDS = "number,title,url,body,comments,parent"
ISSUE_URL = re.compile(
    r"https?://[^\s<>()]+/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/\d+"
)
CROSS_REPO = re.compile(
    r"(?<![A-Za-z0-9_.-])([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)#(\d+)\b"
)
SAME_REPO = re.compile(r"(?<![A-Za-z0-9_./-])#(\d+)\b")
SCP_REMOTE = re.compile(r"(?:[^@]+@)?([^:]+):(.+)")


def issue_coordinates(url: str) -> tuple[str, str, str]:
    parsed = urlsplit(url)
    owner, repo, kind, number = parsed.path.strip("/").split("/")[:4]
    if kind != "issues":
        raise ValueError(f"Not an issue URL: {url}")
    return f"{parsed.scheme}://{parsed.netloc}", f"{owner}/{repo}", number


def referenced_issue_urls(body: str, root_url: str) -> list[str]:
    host, repository, _ = issue_coordinates(root_url)
    candidates = ISSUE_URL.findall(body)
    candidates += [
        f"{host}/{owner}/{repo}/issues/{number}"
        for owner, repo, number in CROSS_REPO.findall(body)
    ]
    candidates += [
        f"{host}/{repository}/issues/{number}"
        for number in SAME_REPO.findall(body)
    ]
    return list(dict.fromkeys(candidates))


def repository_from_remote(remote: str) -> str:
    scp_match = SCP_REMOTE.fullmatch(remote)
    if scp_match and "://" not in remote:
        host, path = scp_match.groups()
    else:
        parsed = urlsplit(remote)
        host, path = parsed.hostname, parsed.path

    if not host:
        raise ValueError(f"Unsupported Git remote URL: {remote}")
    path = path.removeprefix("/").removesuffix(".git")
    if len(path.split("/")) != 2:
        raise ValueError(f"Unsupported GitHub remote URL: {remote}")
    return path if host == "github.com" else f"{host}/{path}"


def select_remote(remotes: dict[str, str]) -> str:
    if "origin" in remotes:
        return remotes["origin"]
    if len(remotes) == 1:
        return next(iter(remotes.values()))
    raise RuntimeError("Expected an origin remote or exactly one Git remote")


def infer_repository() -> str:
    try:
        result = subprocess.run(
            ["jj", "--ignore-working-copy", "git", "remote", "list"],
            check=True,
            capture_output=True,
            text=True,
        )
        remotes = dict(line.split(maxsplit=1) for line in result.stdout.splitlines())
        return repository_from_remote(select_remote(remotes))
    except (FileNotFoundError, subprocess.CalledProcessError, RuntimeError, ValueError):
        pass

    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            check=True,
            capture_output=True,
            text=True,
        )
        return repository_from_remote(result.stdout.strip())
    except (FileNotFoundError, subprocess.CalledProcessError, ValueError) as error:
        raise RuntimeError(
            "Cannot determine the GitHub repository; pass --repo OWNER/REPO"
        ) from error


def view_issue(issue: str | None, repository: str | None = None) -> dict:
    command = ["gh", "issue", "view"]
    if issue:
        command.append(issue)
    if repository:
        command.extend(("--repo", repository))
    command.extend(("--json", FIELDS))

    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def implementation_context(issue: dict) -> dict:
    return {
        "number": issue["number"],
        "title": issue["title"],
        "url": issue["url"],
        "body": issue["body"],
        "comments": [comment["body"] for comment in issue["comments"]],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("issue", help="issue number or URL")
    parser.add_argument("-R", "--repo", help="[HOST/]OWNER/REPO")
    args = parser.parse_args()

    repository = args.repo
    if not repository and not args.issue.startswith(("https://", "http://")):
        repository = infer_repository()

    root = view_issue(args.issue, repository)
    parent_url = (root.get("parent") or {}).get("url")
    parent = view_issue(parent_url) if parent_url else None

    excluded = {root["url"], parent_url}
    references = [
        view_issue(url)
        for url in referenced_issue_urls(root.get("body") or "", root["url"])
        if url not in excluded
    ]

    print(
        json.dumps(
            {
                "issue": implementation_context(root),
                "parentIssue": implementation_context(parent) if parent else None,
                "referencedIssues": [implementation_context(issue) for issue in references],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
