#!/usr/bin/env python3
"""Tell ELI v3 that ELI VR is installed, so it shows up among ELI's bundles.

    python3 tools/register_eli_bundle.py            # register
    python3 tools/register_eli_bundle.py --remove   # take it out again
    python3 tools/register_eli_bundle.py --show     # print it, write nothing

ELI VR runs fine without this. Registering writes one small file into ELI v3's
data folder. ELI then lists ELI VR when it starts and in its Bundles menu, and
starts it with the ELI link switched on.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "vr"
CONTRACT = 1   # the bundle contract in ELI v3's docs/BUNDLES.md


def registry_dir() -> Path:
    """Where ELI v3 looks for separately installed bundles."""
    override = os.environ.get("ELI_DATA_DIR")
    if override:
        return Path(override) / "bundles"
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return base / "ELI_v3" / "bundles"


def find_godot() -> str | None:
    env = os.environ.get("GODOT_BIN")
    if env and Path(env).exists():
        return env
    for name in ("godot", "godot4", "Godot"):
        found = shutil.which(name)
        if found:
            return found
    mac = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    return str(mac) if mac.exists() else None


def launch_command() -> list[str]:
    """A release build starts itself; a source checkout starts through Godot."""
    link_on = ["--", "--eli-link=on"]
    for built in (ROOT / "ELI-VR.x86_64", ROOT / "ELI-VR.exe",
                  ROOT / "ELI VR.app" / "Contents" / "MacOS" / "ELI VR"):
        if built.exists():
            return [str(built), *link_on]
    if (ROOT / "project.godot").exists():
        godot = find_godot()
        if not godot:
            raise SystemExit("Godot not found. Set GODOT_BIN to the Godot 4.7.2 executable.")
        return [str(Path(godot).resolve()), "--path", str(ROOT), *link_on]
    raise SystemExit(f"No ELI VR build or project found in {ROOT}")


def description() -> dict:
    icon = ROOT / "icon.svg"
    return {
        "contract": CONTRACT,
        "id": BUNDLE_ID,
        "title": "ELI VR",
        "summary": "ELI's rooms as a place to stand in: a headset or a monitor, with ELI present.",
        "version": (ROOT / "VERSION").read_text().strip(),
        "edition": BUNDLE_ID,
        "icon": str(icon) if icon.exists() else "",
        "command": launch_command(),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--remove", action="store_true", help="unregister ELI VR")
    ap.add_argument("--show", action="store_true", help="print the registration without writing it")
    args = ap.parse_args()

    target = registry_dir() / f"{BUNDLE_ID}.json"

    if args.remove:
        if target.exists():
            target.unlink()
            print(f"Removed {target}")
        else:
            print(f"Nothing to remove: {target} does not exist.")
        return 0

    text = json.dumps(description(), indent=2) + "\n"
    if args.show:
        print(f"# would be written to {target}\n{text}", end="")
        return 0

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
    print(f"Registered ELI VR with ELI v3: {target}")
    print("Start ELI v3 and pick ELI VR, or run:  eli --bundle vr")
    return 0


if __name__ == "__main__":
    sys.exit(main())
