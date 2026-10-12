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
    <panorama>.jpg                               Poly Haven tonemapped panoramas
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
SKIES = ROOT / "assets" / "skies"

# ambientCG id -> the name the rooms know it by
MATERIAL_SETS = {
    "MetalPlates008": "hull_panels",
    "MetalPlates017A": "deck_plating",
    "Metal009": "brushed_metal",
    "Rock058": "rock",
    "Rock063": "moss_rock",
    "Snow010A": "snow",
    "Ice003": "ice",
    "Ground068": "forest_floor",
    "Ground080": "sand",
    "Concrete030": "concrete",
    "Marble012": "marble_white",
    "Marble016": "marble_black",
    "WoodFloor043": "wood_floor",
    "Planks037A": "planks",
    "Tiles107": "lab_tiles",
    "Bark012": "bark",
}

# Poly Haven panoramas (tonemapped JPG) -> the name the rooms know them by
PANORAMAS = {
    "kiara_1_dawn": "mountain_dawn",
    "misty_pines": "misty_pines",
    "belfast_sunset_puresky": "sunset_sea",
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
        # no metalness map means the surface is not metal at all
        metal = load("Metalness", "L") or Image.new("L", albedo.size, 0)
        occlusion = load("AmbientOcclusion", "L") or Image.new("L", albedo.size, 255)

    albedo.save(MATERIALS / f"{name}_albedo.jpg", quality=90)
    normal.save(MATERIALS / f"{name}_normal.jpg", quality=92, subsampling=0)
    Image.merge("RGB", (occlusion, rough, metal)).save(
        MATERIALS / f"{name}_orm.jpg", quality=90, subsampling=0)


def leaves() -> None:
    """A fern frond and a blade of kelp, drawn here from nothing, so they are
    ours to give away. Stem at the bottom, tip at the top, clear around."""
    import math
    import random
    from PIL import ImageDraw, ImageFilter

    random.seed(4)
    width, height = 256, 1024
    frond = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frond)
    draw.line([(width // 2, height - 6), (width // 2, 30)], fill=(58, 92, 40, 255), width=7)
    y = height - 60.0
    while y > 50:
        t = 1.0 - y / height
        span = (width * 0.46) * (1.0 - t) ** 0.7 * (0.35 + 0.65 * min(1.0, (height - y) / 220))
        thick = max(5, int(26 * (1.0 - t) + 6))
        for side in (-1, 1):
            tip = (width / 2 + side * span, y - span * 0.35)
            shade = random.randint(-14, 14)
            draw.polygon([(width / 2, y + thick / 2), (width / 2, y - thick / 2), tip],
                         fill=(46 + shade, 118 + shade, 44 + shade // 2, 255))
            draw.line([(width / 2, y), tip], fill=(34, 86, 34, 255), width=2)
        y -= thick * 0.86
    frond.filter(ImageFilter.SMOOTH).save(MATERIALS / "fern_frond.png")

    width = 128
    blade = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(blade)
    left, right = [], []
    for y in range(height, -1, -8):
        t = 1.0 - y / height
        half = (width * 0.36) * (0.35 + 0.65 * math.sin(min(t * 1.1, 1.0) * math.pi)) + 4
        sway = math.sin(y * 0.035) * 9
        left.append((width / 2 - half + sway, y))
        right.append((width / 2 + half + sway, y))
    draw.polygon(left + right[::-1], fill=(40, 96, 46, 255))
    for y in range(height - 10, 10, -22):
        sway = math.sin(y * 0.035) * 9
        draw.line([(width / 2 + sway, y), (width / 2 + sway + random.randint(-26, 26), y - 30)], fill=(30, 74, 38, 255), width=2)
    draw.line([(width / 2 + math.sin(y * 0.035) * 9, y) for y in range(height, -1, -8)], fill=(26, 66, 34, 255), width=5)
    blade.filter(ImageFilter.SMOOTH).save(MATERIALS / "kelp_blade.png")


def panorama(src: Path, name: str) -> None:
    """A 360 degree photograph of a real place, kept at 8K. Prints where the
    sun is in it, so the room's light can come from the same direction."""
    im = Image.open(src).convert("RGB")
    if im.size[0] > 8192:
        im = im.resize((8192, 4096), Image.LANCZOS)
    im.save(SKIES / f"{name}.jpg", quality=86)
    small = np.asarray(im.resize((720, 360), Image.BILINEAR)).astype(np.float32).sum(axis=2)
    v, u = np.unravel_index(np.argmax(small), small.shape)
    az = (u / 720.0 - 0.5) * 2.0 * np.pi
    el = (0.5 - v / 360.0) * np.pi
    sun = (np.sin(az) * np.cos(el), np.sin(el), -np.cos(az) * np.cos(el))
    print(f"{name}: brightest point towards ({sun[0]:.3f}, {sun[1]:.3f}, {sun[2]:.3f})")


def main() -> int:
    """Makes whatever the folder has the sources for and skips what is
    already made. Pass --force as a second argument to remake everything."""
    if len(sys.argv) not in (2, 3):
        print(__doc__)
        return 2
    folder = Path(sys.argv[1])
    force = len(sys.argv) == 3 and sys.argv[2] == "--force"
    for target in (SPACE, MATERIALS, SKIES):
        target.mkdir(parents=True, exist_ok=True)

    if (folder / "starmap_2020_8k.exr").exists() and (force or not (SPACE / "starmap_8k.jpg").exists()):
        star_map(folder / "starmap_2020_8k.exr")
    if (folder / "cloud_combined_2048.jpg").exists() and (force or not (SPACE / "earth_day.jpg").exists()):
        earth(folder)
    for source_id, name in MATERIAL_SETS.items():
        archive = folder / f"{source_id}_1K-JPG.zip"
        if archive.exists() and (force or not (MATERIALS / f"{name}_albedo.jpg").exists()):
            material(archive, name)
    for source_id, name in PANORAMAS.items():
        src = folder / f"{source_id}.jpg"
        if src.exists() and (force or not (SKIES / f"{name}.jpg").exists()):
            panorama(src, name)

    if force or not (MATERIALS / "fern_frond.png").exists():
        leaves()

    for path in sorted([*SPACE.glob("*.jpg"), *MATERIALS.glob("*.jpg"), *SKIES.glob("*.jpg")]):
        with Image.open(path) as im:
            print(f"{path.relative_to(ROOT)}  {im.size[0]}x{im.size[1]}  {path.stat().st_size / 1048576:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
