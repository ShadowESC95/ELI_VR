#!/usr/bin/env python3
"""Set how Godot imports the art textures: compressed on the GPU, with mipmaps.

    python3 tools/set_texture_imports.py            set every texture under assets/
    python3 tools/set_texture_imports.py --check    only say which are not set; exit 1 if any

Godot's default keeps a texture uncompressed in GPU memory, which for an 8K
sky is over a hundred megabytes and for the model library is gigabytes, and
without mipmaps a far or slanted surface shimmers. Every texture under assets/
is drawn in 3D (the rooms, the real models, the sky and the space), so every
one of them is set here; the app icon at the top is not under assets/.

Normal maps are imported as normal maps: the images a glTF under assets/ uses
as a material's normalTexture, and the textures the rooms load as normal maps
(their names end in _normal).

Run this after adding textures (models from tools/prepare_models.py among them)
and letting Godot import them once (./tools/godot_parse_check.sh), then import
again. tests/test_texture_imports.py fails while any texture is not set.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = "assets"


def texture_imports(root: Path | None = None) -> list[Path]:
    """Every texture's .import file under assets/ (Godot's own .godot folder aside)."""
    root = root or ROOT
    out = []
    for path in sorted((root / ART).rglob("*.import")):
        if ".godot" in path.parts:
            continue
        if re.search(r'^importer="texture"$', path.read_text(), flags=re.M):
            out.append(path)
    return out


def normal_maps(root: Path | None = None) -> set[str]:
    """The textures (res-relative paths) that are drawn as normal maps: what each glTF's materials
    use as their normalTexture, and the rooms' own textures named *_normal.*"""
    root = root or ROOT
    found: set[str] = set()
    for gltf in sorted((root / ART).rglob("*.gltf")):
        data = json.loads(gltf.read_text(encoding="utf-8"))
        images, textures = data.get("images", []), data.get("textures", [])
        for material in data.get("materials", []):
            index = (material.get("normalTexture") or {}).get("index")
            if index is None or index >= len(textures):
                continue
            source = textures[index].get("source")
            if source is None or source >= len(images) or not images[source].get("uri"):
                continue
            found.add((gltf.parent / images[source]["uri"]).resolve().relative_to(root.resolve()).as_posix())
    for path in texture_imports(root):
        source = path.with_suffix("")
        if re.search(r"_normal$", source.stem):
            found.add(source.relative_to(root).as_posix())
    return found


def wanted(name: str, normal: bool) -> dict[str, str]:
    big_picture = "starmap" in name or "/skies/" in name
    return {
        "compress/mode": "2",
        "mipmaps/generate": "true",
        # skies and star fields show banding under the cheaper format
        "compress/high_quality": "true" if big_picture else "false",
        "compress/normal_map": "1" if normal else "0",
        "detect_3d/compress_to": "0",
    }


def unset(root: Path | None = None) -> list[str]:
    """What is not set as it should be, one line per texture; [] when every texture is."""
    root = root or ROOT
    normals = normal_maps(root)
    out = []
    for path in texture_imports(root):
        source = path.with_suffix("").relative_to(root).as_posix()
        text = path.read_text()
        for key, value in wanted(source, source in normals).items():
            got = re.search(rf"^{re.escape(key)}=(.*)$", text, flags=re.M)
            if got is None or got.group(1) != value:
                out.append(f"{source}: {key}={got.group(1) if got else '(missing)'}, wanted {value}")
    return out


def main(argv: list[str]) -> int:
    if "--check" in argv:
        wrong = unset()
        for line in wrong:
            print(line)
        print(f"{len(wrong)} texture import setting(s) not as wanted")
        return 1 if wrong else 0
    normals = normal_maps()
    changed = 0
    for path in texture_imports():
        source = path.with_suffix("").relative_to(ROOT).as_posix()
        text = path.read_text()
        new = text
        for key, value in wanted(source, source in normals).items():
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
    sys.exit(main(sys.argv[1:]))
