#!/usr/bin/env python3
"""Build a clean public copy of ELI VR and refuse to ship personal data.

    python3 tools/make_release.py           # scan, then write build/release/
    python3 tools/make_release.py --check   # scan only

Local-only material (Godot caches, build logs, compiled binaries, personal
overrides, backups) is left out. The remaining files are scanned for home
directory paths, the current user and host name, e-mail addresses, Steam IDs
and device serial numbers. Any finding stops the release. The one exception is
an e-mail address in a file that exists to publish one (CONTACT_FILES): the
licence names who to contact for a licence.
"""
from __future__ import annotations

import argparse
import fnmatch
import getpass
import re
import shutil
import socket
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Never published: caches, build output, compiled code, personal overrides.
EXCLUDE_DIRS = [".git", ".godot", ".godot.*", "build", "target", "__pycache__"]
EXCLUDE_FILES = [
    "config/user.json", "*.pyc", "*.before-*", "*.bak", "*.orig",
    ".DS_Store", "Thumbs.db",
]
KEEP = {"build/.gitkeep"}

# Placeholder names that are fine to publish in docs and examples.
GENERIC_NAMES = {"user", "username", "you", "yourname", "name", "me", "path", "public", "shared"}
GENERIC_HOSTS = {"localhost", "localdomain", "ubuntu", "debian", "fedora", "desktop", "pc", "home"}

# Files whose e-mail addresses are published on purpose: the licence names who to contact for a
# licence. Only the e-mail rule stands down there; paths, user and host names are still findings.
CONTACT_FILES = {"LICENSE"}

HOME_PATH = re.compile(r"(?:/home/|/Users/|[A-Za-z]:\\+Users\\+)([A-Za-z0-9._-]+)")
RULES = [
    ("e-mail address", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")),
    ("Steam ID", re.compile(r"\b7656119\d{10}\b")),
    ("device serial", re.compile(r"\b[Ss]erial(?: number)?[ :=]+[A-Z0-9]{8,}\b")),
    ("MAC address", re.compile(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b")),
]
EXECUTABLE_MAGIC = {
    b"\x7fELF": "Linux binary", b"MZ": "Windows binary",
    b"\xcf\xfa\xed\xfe": "macOS binary", b"\xca\xfe\xba\xbe": "macOS binary",
}


def excluded(rel: Path) -> bool:
    posix = rel.as_posix()
    if posix in KEEP:
        return False
    if any(fnmatch.fnmatch(part, pat) for part in rel.parts[:-1] for pat in EXCLUDE_DIRS):
        return True
    return any(fnmatch.fnmatch(posix, pat) or fnmatch.fnmatch(rel.name, pat) for pat in EXCLUDE_FILES)


def publishable() -> list[Path]:
    files = []
    for path in sorted(ROOT.rglob("*")):
        if path.is_file() and not path.is_symlink() and not excluded(path.relative_to(ROOT)):
            files.append(path)
    return files


def local_identity() -> list[tuple[str, re.Pattern]]:
    """Whoever builds the release must not leak their own user or host name."""
    rules = []
    try:
        user = getpass.getuser()
    except Exception:
        user = ""
    host = socket.gethostname().split(".")[0]
    # "runner" is the CI account; the word is ordinary in docs and workflows.
    if len(user) >= 3 and user.lower() not in GENERIC_NAMES | {"root", "admin", "runner"}:
        rules.append(("current user name", re.compile(rf"(?<![A-Za-z0-9_]){re.escape(user)}(?![A-Za-z0-9_])")))
    if len(host) >= 4 and host.lower() not in GENERIC_HOSTS:
        rules.append(("current host name", re.compile(rf"(?<![A-Za-z0-9_-]){re.escape(host)}(?![A-Za-z0-9_-])")))
    return rules


def scan(files: list[Path]) -> list[str]:
    findings = []
    identity = local_identity()
    home = str(Path.home()).encode()
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        data = path.read_bytes()
        for magic, kind in EXECUTABLE_MAGIC.items():
            if data.startswith(magic):
                findings.append(f"{rel}: compiled {kind}; releases are source only")
        if b"\0" in data[:8192]:
            # Binary asset: only the unambiguous home-directory path is checked.
            if home in data:
                findings.append(f"{rel}: contains this machine's home directory path")
            continue
        text = data.decode("utf-8", errors="replace")
        for line_no, line in enumerate(text.splitlines(), 1):
            for match in HOME_PATH.finditer(line):
                if match.group(1).lower() not in GENERIC_NAMES:
                    findings.append(f"{rel}:{line_no}: home directory path '{match.group(0)}'")
            for label, pattern in RULES + identity:
                if label == "e-mail address" and rel in CONTACT_FILES:
                    continue
                match = pattern.search(line)
                if match:
                    findings.append(f"{rel}:{line_no}: {label} '{match.group(0)}'")
    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="scan only; do not write a release")
    args = ap.parse_args()

    files = publishable()
    findings = scan(files)
    print(f"ELI VR release scan: {len(files)} publishable files")
    if findings:
        print("\n".join("  " + f for f in findings))
        print(f"\nFAILED: {len(findings)} privacy finding(s). Nothing was written.", file=sys.stderr)
        return 1
    print("PASS: no personal data, machine paths or compiled binaries.")
    if args.check:
        return 0

    version = (ROOT / "VERSION").read_text().strip()
    out_dir = ROOT / "build" / "release" / f"ELI_VR-{version}-source"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    for path in files:
        dest = out_dir / path.relative_to(ROOT)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)

    archive = out_dir.parent / (out_dir.name + ".zip")  # version contains dots
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in files:
            zf.write(path, Path(out_dir.name) / path.relative_to(ROOT))
    print(f"\nRelease folder: {out_dir}\nRelease zip:    {archive}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
