#!/usr/bin/env python3
"""Bring the downloaded Poly Haven models into assets/models/, as the rooms use them.

    python3 tools/prepare_models.py <folder with the downloads>

Nothing here runs at play time, and the app never downloads anything. This is
how the files under assets/models/ were made, so they can be made again.

Expected in the folder:
    models.json            Poly Haven's model list (https://api.polyhaven.com/assets?t=models),
                           for each model's name and authors
    <id>/<id>_1k.gltf      each model as Poly Haven gives it at 1K: the glTF, its .bin
    <id>/...               and the textures it names

Every file a glTF names must be there, inside that model's folder; nothing else is
copied. assets/models/models.json records what each model is and who made it, and
assets/CREDITS.md lists them.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "assets" / "models"


def named_files(gltf: Path) -> list[str]:
    data = json.loads(gltf.read_text(encoding="utf-8"))
    uris = [b.get("uri", "") for b in data.get("buffers", [])] + [i.get("uri", "") for i in data.get("images", [])]
    out = []
    for uri in uris:
        if not uri or uri.startswith("data:"):
            continue
        if uri.startswith("/") or ".." in Path(uri).parts or "://" in uri:
            raise SystemExit(f"{gltf.name}: refuses {uri!r}: a model may only name files beside it")
        out.append(uri)
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1])
    catalogue = json.loads((src / "models.json").read_text(encoding="utf-8"))
    MODELS.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for folder in sorted(p for p in src.iterdir() if p.is_dir()):
        model = folder.name
        gltf = folder / f"{model}_1k.gltf"
        if not gltf.exists() or model not in catalogue:
            continue
        dest = MODELS / model
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True)
        shutil.copy2(gltf, dest / gltf.name)
        for rel in named_files(gltf):
            if not (folder / rel).is_file():
                raise SystemExit(f"{model}: {rel} is missing")
            (dest / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(folder / rel, dest / rel)
        info = catalogue[model]
        manifest[model] = {
            "name": info.get("name", model),
            "authors": sorted((info.get("authors") or {}).keys()),
            "licence": "CC0 1.0",
            "polyhaven_id": model,      # the page is polyhaven.com/a/<id>; see assets/CREDITS.md
            "triangles": info.get("polycount"),
        }
        print(f"{model}: {1 + len(named_files(gltf))} files")
    (MODELS / "models.json").write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
    print(f"{len(manifest)} models in {MODELS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
