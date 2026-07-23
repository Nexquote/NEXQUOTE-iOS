#!/usr/bin/env python3
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {".gitattributes", ".gitignore", "NOTICE", "README.md", "SECURITY.md"}
ALLOWED_SUFFIXES = {
    ".github": {".yml", ".yaml"},
    "App": {".css", ".entitlements", ".html", ".js", ".json", ".plist", ".png", ".storyboard", ".swift", ".xml"},
    "App.xcodeproj": {".pbxproj", ".plist", ".xcscheme"},
    "AppTests": {".swift"},
    "AppUITests": {".swift"},
    "CapApp-SPM": {".md", ".swift"},
    "Config": {".xcconfig"},
    "Shared": {".strings", ".swift", ".xcprivacy"},
    "ShareExtension": {".entitlements", ".plist", ".swift"},
    "docs": {".gif", ".md", ".png", ".webp"},
    "scripts": {".py", ".sh"},
}
EXACT_GITHUB_FILES = {".github/dependabot.yml", ".github/workflows/ci.yml"}
DENIED_PARTS = {
    ".env", ".git", ".idea", ".swiftpm", ".vscode", "DerivedData", "Pods",
    "customer-data", "e2e", "infra", "node_modules", "xcuserdata",
}
DENIED_SUFFIXES = {
    ".cer", ".crt", ".der", ".ipa", ".key", ".mobileprovision", ".p12", ".pem",
    ".sqlite", ".xcarchive", ".xcresult",
}
SECRET_PATTERNS = {
    "private-key": re.compile(rb"-----BEGIN (?:EC |OPENSSH |RSA )?PRIVATE KEY-----"),
    "github-token": re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})"),
    "aws-access-key": re.compile(rb"(?:AKIA|ASIA)[A-Z0-9]{16}"),
    "slack-token": re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}"),
    "jwt": re.compile(rb"eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}"),
    "assigned-secret": re.compile(
        rb"(?i)(?:api[_-]?key|client[_-]?secret|password|private[_-]?token|refresh[_-]?token)"
        rb"\s*[:=]\s*[\"']?[A-Za-z0-9/+_.=-]{16,}"
    ),
}
BINARY_SUFFIXES = {".gif", ".png", ".webp"}


def run(*args: str, input_data: bytes | None = None) -> bytes:
    return subprocess.check_output(args, cwd=ROOT, input=input_data, stderr=subprocess.DEVNULL)


def allowed_path(relative: str) -> bool:
    path = Path(relative)
    if len(path.parts) == 1:
        return relative in ROOT_FILES
    top = path.parts[0]
    if top not in ALLOWED_SUFFIXES:
        return False
    if top == ".github" and relative not in EXACT_GITHUB_FILES:
        return False
    return path.suffix in ALLOWED_SUFFIXES[top]


def path_violation(relative: str) -> str | None:
    path = Path(relative)
    if any(part in DENIED_PARTS for part in path.parts):
        return "denied path"
    if path.suffix.lower() in DENIED_SUFFIXES:
        return "denied artifact"
    if not allowed_path(relative):
        return "outside public allowlist"
    return None


def tree_files() -> list[tuple[str, Path]]:
    files = []
    for directory, names, filenames in os.walk(ROOT):
        names[:] = [name for name in names if name != ".git"]
        for name in filenames:
            path = Path(directory, name)
            files.append((path.relative_to(ROOT).as_posix(), path))
    return sorted(files)


def check_tree() -> int:
    failures = []
    for relative, path in tree_files():
        violation = path_violation(relative)
        if violation:
            failures.append(f"{violation}: {relative}")
        if path.is_symlink():
            failures.append(f"symlink not allowed: {relative}")
        if path.stat().st_size > 8 * 1024 * 1024:
            failures.append(f"file exceeds 8 MiB: {relative}")
    if failures:
        print("Public tree guard failed:")
        print("\n".join(f"- {item}" for item in failures))
        return 1
    print(f"Public tree guard passed ({len(tree_files())} files).")
    return 0


def secret_hits(data: bytes) -> list[str]:
    if b"\0" in data[:4096]:
        return []
    return [name for name, pattern in SECRET_PATTERNS.items() if pattern.search(data)]


def check_tree_secrets() -> int:
    failures = []
    for relative, path in tree_files():
        if path.suffix.lower() in BINARY_SUFFIXES or path.stat().st_size > 2 * 1024 * 1024:
            continue
        hits = secret_hits(path.read_bytes())
        if hits:
            failures.append(f"{relative}: {', '.join(hits)}")
    if failures:
        print("Working-tree secret scan failed; matched values are intentionally redacted.")
        print("\n".join(f"- {item}" for item in failures))
        return 1
    print("Working-tree secret scan passed.")
    return 0


def check_history_secrets() -> int:
    try:
        objects = run("git", "rev-list", "--objects", "--all").decode().splitlines()
        roots = run("git", "rev-list", "--max-parents=0", "--all").decode().splitlines()
    except subprocess.CalledProcessError:
        print("History scan requires an initialized Git repository.")
        return 1
    failures = []
    if len(roots) != 1:
        failures.append(f"fresh history must have exactly one root commit; found {len(roots)}")
    seen = set()
    for line in objects:
        object_id, _, relative = line.partition(" ")
        if not relative or object_id in seen:
            continue
        if run("git", "cat-file", "-t", object_id).strip() != b"blob":
            continue
        seen.add(object_id)
        if path_violation(relative):
            failures.append(f"history path outside allowlist: {relative}")
            continue
        if Path(relative).suffix.lower() in BINARY_SUFFIXES:
            continue
        if int(run("git", "cat-file", "-s", object_id)) > 2 * 1024 * 1024:
            continue
        hits = secret_hits(run("git", "cat-file", "blob", object_id))
        if hits:
            failures.append(f"{relative}: {', '.join(hits)}")
    tree_rows = run("git", "ls-tree", "-r", "--full-tree", "HEAD").decode().splitlines()
    failures.extend(
        f"history symlink not allowed: {row.split(chr(9), 1)[1]}"
        for row in tree_rows
        if row.startswith("120000 ")
    )
    if failures:
        print("Git-history secret/allowlist scan failed; matched values are intentionally redacted.")
        print("\n".join(f"- {item}" for item in failures))
        return 1
    print(f"Git-history secret/allowlist scan passed ({len(seen)} blobs checked).")
    return 0


def check_docs() -> int:
    link_pattern = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
    failures = []
    for relative, path in tree_files():
        if path.suffix.lower() != ".md":
            continue
        content = path.read_text(encoding="utf-8")
        for raw_target in link_pattern.findall(content):
            target = raw_target.strip().split()[0].strip("<>")
            if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                continue
            target = unquote(target.split("#", 1)[0])
            destination = (path.parent / target).resolve()
            try:
                destination.relative_to(ROOT)
            except ValueError:
                failures.append(f"{relative}: link escapes repository: {target}")
                continue
            if not destination.exists():
                failures.append(f"{relative}: missing link target: {target}")
    if failures:
        print("Documentation link check failed:")
        print("\n".join(f"- {item}" for item in failures))
        return 1
    print("Documentation link check passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("check", choices=["tree", "docs", "secrets"])
    parser.add_argument("--scope", choices=["tree", "history"], default="tree")
    args = parser.parse_args()
    if args.check == "tree":
        return check_tree()
    if args.check == "docs":
        return check_docs()
    return check_history_secrets() if args.scope == "history" else check_tree_secrets()


if __name__ == "__main__":
    sys.exit(main())
