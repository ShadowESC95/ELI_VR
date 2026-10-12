#!/usr/bin/env python3
"""Set how Godot imports the art textures: compressed on the GPU, with mipmaps.

    python3 tools/set_texture_imports.py

Godot's default keeps a texture uncompressed in GPU memory, which for an 8K
sky is over a hundred megabytes. Run this after adding textures under
assets/space, assets/skies or assets/materials and letting Godot import them
once (./tools/godot_parse_check.sh), then import again.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = ["assets/space", "assets/skies", "assets/materials"]


def wanted(name: str) -> dict[str, str]:
    big_picture = "starmap" in name or "/skies/" in name
    return {
        "compress/mode": "2",
        "mipmaps/generate": "true",
        # skies and star fields show banding under the cheaper format
        "compress/high_quality": "true" if big_picture else "false",
        "compress/normal_map": "1" if "_normal" in name else "0",
        "detect_3d/compress_to": "0",
    }


def main() -> int:
    changed = 0
    for folder in FOLDERS:
        for path in sorted((ROOT / folder).glob("*.import")):
            text = path.read_text()
            new = text
            for key, value in wanted(path.as_posix()).items():
                new, count = re.subn(rf"^{re.escape(key)}=.*$", f"{key}={value}", new, flags=re.M)
                if count != 1:
                    print(f"unexpected import file: {path.relative_to(ROOT)} has no {key}")
                    return 1
            if new != text:
                path.write_text(new)
                changed += 1
    print(f"import settings updated on {changed} texture(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
