"""ELI VR's side of ELI v3's bundle contract.

    python3 -m unittest discover -s tests

Nothing here starts ELI VR, ELI or a headset.
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from eli_vr import __version__, bundle, cli  # noqa: E402


class Sandbox(unittest.TestCase):
    """A machine with nothing on it: its own folders, and no ELI VR named anywhere."""

    def setUp(self) -> None:
        self.tmp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        env = {k: v for k, v in os.environ.items() if not k.startswith(("ELI_", "GODOT_BIN", "APPIMAGE"))}
        env.update(
            XDG_CONFIG_HOME=str(self.tmp / "config"),
            XDG_DATA_HOME=str(self.tmp / "data"),
            APPDATA=str(self.tmp / "config"),
            LOCALAPPDATA=str(self.tmp / "data"),
            HOME=str(self.tmp / "home"),
            USERPROFILE=str(self.tmp / "home"),
        )
        self.enterContext(mock.patch.dict(os.environ, env, clear=True))

    def download(self, *files: str) -> Path:
        folder = self.tmp / "ELI_VR"
        for name in files:
            (folder / name).parent.mkdir(parents=True, exist_ok=True)
            (folder / name).write_text("")
        return folder


class Description(unittest.TestCase):
    def test_it_is_what_eli_v3_asks_for(self) -> None:
        d = bundle.describe()
        self.assertEqual((d["contract"], d["id"], d["title"], d["edition"]), (1, "vr", "ELI VR", "vr"))
        self.assertEqual(d["needs"], ["server"])
        module, _, function = d["launch"].partition(":")
        self.assertEqual(module, "eli_vr.bundle")
        self.assertTrue(callable(getattr(bundle, function)))
        self.assertTrue(Path(d["icon"]).is_file())

    def test_the_version_is_the_one_everything_else_carries(self) -> None:
        project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))["project"]
        self.assertEqual(__version__, (ROOT / "VERSION").read_text(encoding="utf-8").strip())
        self.assertEqual(__version__, project["version"])
        self.assertEqual(bundle.describe()["version"], __version__)

    def test_the_entry_point_eli_v3_reads_is_declared(self) -> None:
        project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))["project"]
        self.assertEqual(project["entry-points"]["eli.bundles"], {"vr": "eli_vr.bundle:describe"})
        self.assertEqual(project["scripts"]["eli-vr"], "eli_vr.cli:main")
        self.assertEqual(project["dependencies"], [], "the package itself needs nothing installed")


class WhereItIs(Sandbox):
    def test_a_linux_download_starts_through_its_launcher(self) -> None:
        folder = self.download("ELI-VR.x86_64", "launch/eli-vr.sh")
        with mock.patch.dict(os.environ, {"ELI_VR_HOME": str(folder)}), mock.patch.object(sys, "platform", "linux"):
            self.assertEqual(bundle.own_command(), [str(folder.resolve() / "launch" / "eli-vr.sh"), "--eli"])

    def test_a_windows_and_a_macos_download_start_the_app_with_the_link_on(self) -> None:
        for build, platform in (("ELI-VR.exe", "win32"), ("ELI VR.app/Contents/MacOS/ELI VR", "darwin")):
            with self.subTest(build):
                folder = self.tmp / platform
                (folder / build).parent.mkdir(parents=True)
                (folder / build).write_text("")
                with mock.patch.dict(os.environ, {"ELI_VR_HOME": str(folder)}), mock.patch.object(sys, "platform", platform):
                    self.assertEqual(bundle.own_command(), [str(folder.resolve() / build), "--", "--eli-link=on"])

    def test_a_checkout_without_a_build_runs_through_godot(self) -> None:
        folder = self.download("project.godot")
        godot = self.tmp / "godot"
        godot.write_text("")
        with mock.patch.dict(os.environ, {"ELI_VR_HOME": str(folder), "GODOT_BIN": str(godot)}), \
                mock.patch.object(sys, "platform", "win32"):
            self.assertEqual(
                bundle.own_command(),
                [str(godot.resolve()), "--path", str(folder.resolve()), "--", "--eli-link=on"],
            )

    def test_an_appimage_is_the_one_file_to_run(self) -> None:
        app = self.tmp / "ELI_VR-x86_64.AppImage"
        app.write_text("")
        with mock.patch.dict(os.environ, {"ELI_VR_APP": str(app)}):
            self.assertEqual(bundle.own_command(), [str(app.resolve()), "--eli"])
        with mock.patch.dict(os.environ, {"ELI_VR_APP": str(self.tmp / "gone")}), self.assertRaises(FileNotFoundError):
            bundle.own_command()

    def test_this_checkout_is_found_without_being_told(self) -> None:
        self.assertEqual(bundle.home(), ROOT)


class Registering(Sandbox):
    def test_it_writes_one_file_eli_v3_can_read_and_takes_it_back(self) -> None:
        app = self.tmp / "ELI_VR-x86_64.AppImage"
        app.write_text("")
        with mock.patch.dict(os.environ, {"ELI_VR_APP": str(app)}):
            written = bundle.register()
        self.assertEqual(written, bundle.v3_bundle_dirs()[0] / "vr.json")
        record = json.loads(written.read_text(encoding="utf-8"))
        # what ELI v3 checks of a registration: a known contract, a plain id, a program that exists
        self.assertLessEqual(record["contract"], 1)
        self.assertTrue(record["id"].replace("-", "").replace("_", "").isalnum())
        self.assertEqual(record["command"], [str(app.resolve()), "--eli"])
        self.assertTrue(Path(record["command"][0]).exists())
        self.assertEqual((record["launch"], record["needs"]), ("", ["server"]))
        # installed into ELI v3's environment, with nothing named, the same copy is still found
        with mock.patch.object(bundle, "_beside", lambda: None):
            self.assertEqual(bundle.own_command(), [str(app.resolve()), "--eli"])
        self.assertEqual(bundle.unregister(), [written])
        self.assertFalse(written.exists())
        self.assertEqual(bundle.unregister(), [])

    def test_eli_v3_is_looked_for_where_it_keeps_its_data(self) -> None:
        with mock.patch.dict(os.environ, {"ELI_DATA_DIR": str(self.tmp / "elsewhere")}):
            folders = bundle.v3_bundle_dirs()
        self.assertEqual(folders[0].parts[-2:], ("ELI_v3", "bundles"))
        self.assertEqual(folders[1], self.tmp / "elsewhere" / "bundles")

    def test_the_command_line_does_the_same(self) -> None:
        app = self.tmp / "ELI_VR-x86_64.AppImage"
        app.write_text("")
        into = self.tmp / "bundles"
        with mock.patch.dict(os.environ, {"ELI_VR_APP": str(app)}), mock.patch("builtins.print"):
            self.assertEqual(cli.main(["bundle", "register", "--into", str(into)]), 0)
            self.assertTrue((into / "vr.json").is_file())
            self.assertEqual(cli.main(["bundle", "show"]), 0)
            self.assertEqual(cli.main(["bundle", "unregister", "--into", str(into)]), 0)
        self.assertFalse((into / "vr.json").exists())


class Launching(Sandbox):
    def run_launch(self, argv, host):
        seen = self.tmp / "seen.json"
        script = self.tmp / "stand_in.py"
        script.write_text(
            "import json, os, sys\n"
            f"open({str(seen)!r}, 'w').write(json.dumps([sys.argv[1:], os.environ.get('ELI_API_PORT'), "
            "os.environ.get('ELI_VR_HOST')]))\nsys.exit(5)\n"
        )
        with mock.patch.object(bundle, "own_command", lambda: [sys.executable, str(script)]):
            code = bundle.launch(argv, host=host)
        return code, json.loads(seen.read_text())

    def test_eli_vr_is_started_on_the_port_eli_v3_gives_and_its_exit_code_comes_back(self) -> None:
        code, (args, port, host) = self.run_launch(["--flat"], {"name": "ELI v3", "version": "3.0.132", "api_port": 18999})
        self.assertEqual((code, args, port, host), (5, ["--flat"], "18999", "ELI v3 3.0.132"))

    def test_an_older_eli_v3_with_its_server_already_up_is_used_as_it_is(self) -> None:
        with mock.patch.object(bundle, "_port", lambda: 18998), mock.patch.object(bundle, "_answers", lambda port: True):
            code, (_args, port, _host) = self.run_launch([], {"name": "ELI v3", "version": "3.0.131"})
        self.assertEqual((code, port), (5, "18998"))

    def test_without_eli_it_still_opens(self) -> None:
        with mock.patch.object(bundle, "_port", lambda: 18997), mock.patch.object(bundle, "_answers", lambda port: False):
            code, (_args, port, _host) = self.run_launch([], None)
        self.assertEqual((code, port), (5, "18997"))


if __name__ == "__main__":
    unittest.main()
