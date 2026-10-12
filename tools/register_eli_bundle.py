#!/usr/bin/env python3
"""Tell ELI v3 that ELI VR is installed, so it shows up among ELI's bundles.

    python3 tools/register_eli_bundle.py            # register
    python3 tools/register_eli_bundle.py --remove   # take it out again
    python3 tools/register_eli_bundle.py --show     # print it, write nothing
    python3 tools/register_eli_bundle.py --into DIR # ELI v3's bundles folder, if not the usual one

For a download or a checkout that has not been installed with pip. With the
package installed, `eli-vr bundle register` is the same thing.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from eli_vr.cli import main  # noqa: E402

if __name__ == "__main__":
    rest = sys.argv[1:]
    action = "register"
    for flag, name in (("--remove", "unregister"), ("--show", "show")):
        if flag in rest:
            rest.remove(flag)
            action = name
    # what is left is passed on: --into <folder> names ELI v3's bundles folder
    sys.exit(main(["bundle", action, *rest]))
