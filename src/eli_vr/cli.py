"""The ``eli-vr`` command: what ELI VR's Python side can do from a terminal."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from eli_vr import __version__, bundle


def cmd_bundle(args: argparse.Namespace) -> int:
    into = Path(args.into) if getattr(args, "into", None) else None
    if args.bundle_cmd == "show":
        print(json.dumps(bundle.record(), indent=2))
        return 0
    if args.bundle_cmd == "register":
        path = bundle.register(into)
        print(f"Registered ELI VR with ELI v3: {path}")
        print("Start ELI v3 and pick ELI VR, or run:  eli --bundle vr")
        return 0
    removed = bundle.unregister(into)
    print("\n".join(f"Removed {p}" for p in removed) or "ELI VR was not registered.")
    return 0


def cmd_where(_args: argparse.Namespace) -> int:
    folder = bundle.home()
    print(f"ELI VR {__version__}")
    print(f"folder:  {folder if folder else 'not found (set ELI_VR_HOME)'}")
    try:
        print("starts:  " + " ".join(bundle.own_command()))
    except FileNotFoundError as missing:
        print(f"starts:  {missing}")
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="eli-vr", description="ELI VR and ELI v3.")
    ap.add_argument("--version", action="version", version=f"eli-vr {__version__}")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("bundle", help="make this copy available to ELI v3 as a bundle")
    s = p.add_subparsers(dest="bundle_cmd", required=True)
    s.add_parser("show", help="print the registration without writing it")
    for name in ("register", "unregister"):
        s.add_parser(name).add_argument("--into", help="ELI v3's bundles folder, if not the usual one")
    p.set_defaults(run=cmd_bundle)

    sub.add_parser("where", help="where this copy of ELI VR is and how it is started").set_defaults(run=cmd_where)

    args = ap.parse_args(argv)
    return int(args.run(args))


if __name__ == "__main__":
    sys.exit(main())
