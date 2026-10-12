"""ELI VR's Python side: how ELI v3 finds ELI VR and starts it.

ELI VR itself is a Godot application. This small package is what a Python
host needs to know about it.
"""

from __future__ import annotations

from pathlib import Path


def _version() -> str:
    # In a checkout or an unpacked download the VERSION file is the truth.
    beside = Path(__file__).resolve().parents[2] / "VERSION"
    if beside.is_file():
        return beside.read_text(encoding="utf-8").strip()
    try:
        from importlib.metadata import version

        return version("eli-vr")
    except Exception:
        return "0"


__version__ = _version()
