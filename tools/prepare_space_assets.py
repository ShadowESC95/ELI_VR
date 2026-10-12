#!/usr/bin/env python3
"""Turn the downloaded source imagery into the textures the rooms use.

    python3 tools/prepare_space_assets.py <folder with the downloads>

Nothing here runs at play time, and the app never downloads anything. This is
how the files under assets/space/ and assets/materials/ were made, so they can
be made again. Sources and licences are listed in assets/CREDITS.md.

Needs ffmpeg (to read the star map's EXR), numpy and Pillow.

Expected in the folder:
    starmap_2020_8k.exr                          NASA SVS Deep Star Maps 2020
    world.topo.bathy.200412.3x5400x2700.jpg      NASA Blue Marble Next Generation
    cloud_combined_2048.jpg                      NASA Blue Marble clouds
    BlackMarble_2016_01deg.jpg                   NASA Black Marble 2016
    <Material>_1K-JPG.zip                        ambientCG materials
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPACE = ROOT / "assets" / "space"
MATERIALS = ROOT / "assets" / "materials"

# ambientCG id -> the name the rooms know it by
MATERIAL_SETS = {
    "MetalPlates008": "hull_panels",
    "MetalPlates017A": "deck_plating",
    "Metal009": "brushed_metal",
}

Image.MAX_IMAGE_PIXELS = None


def star_map(src: Path) -> None:
    """Linear float star map -> an 8-bit picture that keeps the faint stars.

    The source spans four orders of magnitude. A power curve pulls the sky
    background down towards black while the Milky Way keeps its shape; the sky
    shader sets final black level and brightness per room.
    """
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "star.raw"
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
             "-f", "rawvideo", "-pix_fmt", "gbrpf32le", str(raw)],
            check=True,
        )
        planes = np.fromfile(raw, dtype=np.float32)
    height = int(round((planes.size / 3 / 2) ** 0.5))
    width = height * 2
    g, b, r = planes.reshape(3, height, width)
    linear = np.stack([r, g, b], axis=-1)
    del planes

    shaped = 3.1 * np.power(np.clip(linear, 0.0, None), 1.5)
    srgb = np.power(np.clip(shaped, 0.0, 1.0), 1.0 / 2.2)
    Image.fromarray((srgb * 255.0 + 0.5).astype(np.uint8)).save(
        SPACE / "starmap_8k.jpg", quality=92, subsampling=0
    )


def earth(folder: Path) -> None:
    Image.open(folder / "world.topo.bathy.200412.3x5400x2700.jpg").convert("RGB").resize(
        (4096, 2048), Image.LANCZOS).save(SPACE / "earth_day.jpg", quality=90)
    Image.open(folder / "cloud_combined_2048.jpg").convert("L").save(
        SPACE / "earth_clouds.jpg", quality=90)
    Image.open(folder / "BlackMarble_2016_01deg.jpg").convert("RGB").resize(
        (2048, 1024), Image.LANCZOS).save(SPACE / "earth_night.jpg", quality=90)


def material(archive: Path, name: str) -> None:
    """One ambientCG set -> albedo, normal (OpenGL) and a packed
    occlusion / roughness / metalness texture."""
    with zipfile.ZipFile(archive) as z:
        def load(suffix: str, mode: str):
            for item in z.namelist():
                if item.endswith(f"_{suffix}.jpg"):
                    return Image.open(z.open(item)).convert(mode)
            return None

        albedo = load("Color", "RGB")
        normal = load("NormalGL", "RGB")
        rough = load("Roughness", "L")
        metal = load("Metalness", "L") or Image.new("L", albedo.size, 255)
        occlusion = load("AmbientOcclusion", "L") or Image.new("L", albedo.size, 255)

    albedo.save(MATERIALS / f"{name}_albedo.jpg", quality=90)
    normal.save(MATERIALS / f"{name}_normal.jpg", quality=92, subsampling=0)
    Image.merge("RGB", (occlusion, rough, metal)).save(
        MATERIALS / f"{name}_orm.jpg", quality=90, subsampling=0)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    folder = Path(sys.argv[1])
    SPACE.mkdir(parents=True, exist_ok=True)
    MATERIALS.mkdir(parents=True, exist_ok=True)

    star_map(folder / "starmap_2020_8k.exr")
    earth(folder)
    for source_id, name in MATERIAL_SETS.items():
        material(folder / f"{source_id}_1K-JPG.zip", name)

    for path in sorted([*SPACE.glob("*.jpg"), *MATERIALS.glob("*.jpg")]):
        with Image.open(path) as im:
            print(f"{path.relative_to(ROOT)}  {im.size[0]}x{im.size[1]}  {path.stat().st_size / 1048576:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
