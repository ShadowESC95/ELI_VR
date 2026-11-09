"""Every texture the rooms and the real models draw is compressed on the GPU, with mipmaps.

Godot keeps a texture it imports with its defaults uncompressed in video memory and without a mip
chain: the model library alone (four hundred textures at 1K and 2K) held about 3.6 GiB of the same
GPU ELI v3's model needs, and far or slanted surfaces shimmered in the headset. tools/
set_texture_imports.py sets them; this fails while any texture under assets/ is not set, so a model
brought in later with Godot's defaults is caught here, not in the headset.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import set_texture_imports  # noqa: E402

IMPORT = """[remap]

importer="texture"

[params]

compress/mode=0
compress/high_quality=false
compress/normal_map=0
mipmaps/generate=false
detect_3d/compress_to=1
"""


class EveryTexture(unittest.TestCase):
    def test_every_texture_under_assets_is_compressed_on_the_gpu_with_mipmaps(self) -> None:
        textures = set_texture_imports.texture_imports()
        self.assertTrue(any("/models/" in p.as_posix() for p in textures), "the model textures were not looked at")
        wrong = set_texture_imports.unset()
        self.assertEqual(wrong, [], f"{len(wrong)} setting(s) wrong, first: {wrong[:3]}; run tools/set_texture_imports.py")

    def test_the_normal_maps_are_the_ones_the_models_and_rooms_draw_as_normal_maps(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = root / "assets" / "models" / "chair"
            (model / "textures").mkdir(parents=True)
            (model / "chair_1k.gltf").write_text(json.dumps({
                "images": [{"uri": "textures/a.jpg"}, {"uri": "textures/b.jpg"}],
                "textures": [{"source": 0}, {"source": 1}],
                "materials": [{"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}, "normalTexture": {"index": 1}}]}))
            for name in ("a.jpg", "b.jpg"):
                (model / "textures" / f"{name}.import").write_text(IMPORT)
            (root / "assets" / "materials").mkdir(parents=True)
            (root / "assets" / "materials" / "stone_normal.jpg.import").write_text(IMPORT)
            (root / "assets" / "materials" / "stone_albedo.jpg.import").write_text(IMPORT)
            (root / "assets" / "sound.ogg.import").write_text('[remap]\n\nimporter="oggvorbisstr"\n')
            self.assertEqual(set_texture_imports.normal_maps(root), {
                "assets/models/chair/textures/b.jpg", "assets/materials/stone_normal.jpg"})
            self.assertEqual(len(set_texture_imports.unset(root)), 2 * 4 + 2 * 3)   # a normal map: four wrong, a colour: three
            with mock.patch.object(set_texture_imports, "ROOT", root), mock.patch("builtins.print"):
                self.assertEqual(set_texture_imports.main([]), 0)
                self.assertEqual(set_texture_imports.main(["--check"]), 0)
            colour = (model / "textures" / "a.jpg.import").read_text()
            normal = (model / "textures" / "b.jpg.import").read_text()
            self.assertIn("compress/mode=2", colour)
            self.assertIn("mipmaps/generate=true", colour)
            self.assertIn("compress/normal_map=0", colour)
            self.assertIn("compress/normal_map=1", normal)
            self.assertEqual((root / "assets" / "sound.ogg.import").read_text(), '[remap]\n\nimporter="oggvorbisstr"\n')


if __name__ == "__main__":
    unittest.main()
