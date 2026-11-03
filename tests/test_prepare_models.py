"""Bringing models in from Poly Haven's downloads: a folder of new downloads adds to what is there.

The first version rebuilt assets/models/models.json from the folder alone, so adding two models
would have dropped the thirty-five already listed; and it emptied each model's folder before
copying, which deleted Godot's import settings beside the files.
"""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import prepare_models  # noqa: E402


def _download(folder: Path, model: str) -> None:
    (folder / model / "textures").mkdir(parents=True)
    (folder / model / f"{model}_1k.gltf").write_text(json.dumps({
        "buffers": [{"uri": f"{model}.bin"}], "images": [{"uri": f"textures/{model}_diff_1k.jpg"}]}))
    (folder / model / f"{model}.bin").write_bytes(b"\0")
    (folder / model / "textures" / f"{model}_diff_1k.jpg").write_bytes(b"\xff")


class Adding(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.models = self.tmp / "models"
        self.enterContext(mock.patch.object(prepare_models, "MODELS", self.models))
        self.enterContext(mock.patch.object(prepare_models, "ROOT", self.tmp))

    def _bring(self, *names: str) -> None:
        downloads = Path(tempfile.mkdtemp(dir=self.tmp))
        (downloads / "models.json").write_text(json.dumps(
            {n: {"name": n.replace("_", " ").title(), "authors": {"Someone": "All"}, "polycount": 10} for n in names}))
        for name in names:
            _download(downloads, name)
        with mock.patch.object(sys, "argv", ["prepare_models.py", str(downloads)]), mock.patch("builtins.print"):
            self.assertEqual(prepare_models.main(), 0)

    def test_new_downloads_add_to_the_models_already_there(self) -> None:
        self._bring("old_chair")
        self._bring("new_table")
        listed = json.loads((self.models / "models.json").read_text())
        self.assertEqual(sorted(listed), ["new_table", "old_chair"])

    def test_godots_import_settings_are_kept_when_a_model_is_brought_in_again(self) -> None:
        self._bring("old_chair")
        settings = self.models / "old_chair" / "old_chair_1k.gltf.import"
        settings.write_text("[remap]\n")
        stale = self.models / "old_chair" / "textures" / "gone_1k.jpg"
        stale.write_bytes(b"\xff")
        self._bring("old_chair")
        self.assertTrue(settings.exists(), "the import settings were deleted")
        self.assertFalse(stale.exists(), "a file the model no longer names stayed")

    def test_a_model_whose_folder_is_gone_leaves_the_list(self) -> None:
        self._bring("old_chair")
        self._bring("new_table")
        for f in sorted((self.models / "old_chair").rglob("*"), reverse=True):
            f.unlink() if f.is_file() else f.rmdir()
        (self.models / "old_chair").rmdir()
        self._bring("lamp")
        self.assertEqual(sorted(json.loads((self.models / "models.json").read_text())), ["lamp", "new_table"])


if __name__ == "__main__":
    unittest.main()


class Sharper(Adding):
    def test_a_2k_download_takes_the_place_of_the_1k_model(self) -> None:
        self._bring("old_chair")
        (self.models / "old_chair" / "old_chair_1k.gltf.import").write_text("[remap]\n")
        downloads = Path(tempfile.mkdtemp(dir=self.tmp))
        (downloads / "models.json").write_text(json.dumps({"old_chair": {"name": "Old Chair", "authors": {"Someone": "All"}}}))
        (downloads / "old_chair" / "textures").mkdir(parents=True)
        (downloads / "old_chair" / "old_chair_2k.gltf").write_text(json.dumps({
            "buffers": [{"uri": "old_chair.bin"}], "images": [{"uri": "textures/old_chair_diff_2k.jpg"}]}))
        (downloads / "old_chair" / "old_chair.bin").write_bytes(b"\0")
        (downloads / "old_chair" / "textures" / "old_chair_diff_2k.jpg").write_bytes(b"\xff")
        with mock.patch.object(sys, "argv", ["prepare_models.py", str(downloads)]), mock.patch("builtins.print"):
            self.assertEqual(prepare_models.main(), 0)
        here = sorted(p.relative_to(self.models / "old_chair").as_posix() for p in (self.models / "old_chair").rglob("*") if p.is_file())
        self.assertEqual(here, ["old_chair.bin", "old_chair_2k.gltf", "textures/old_chair_diff_2k.jpg"],
                         "the 1K files and their import settings are gone")
