"""ELI VR as an ELI v3 bundle: a separate application ELI v3 can open, on ELI v3's core.

The contract (``eli.bundles`` in ELI v3) asks a bundle for a description and a launch function.
Installed in ELI v3's Python environment, ELI VR is found through the ``eli.bundles`` entry
point. Installed on its own (an AppImage, a download), ``eli-vr bundle register`` tells ELI v3
where it is, and ELI v3 starts it as its own program.

ELI VR is a Godot application, not a Python program, so it reaches ELI over ELI v3's local
server: its world, its hearing and its voice. The description says so (``needs``), and ELI v3
has the server answering before ELI VR starts. Launching then means starting the application
with its link to ELI switched on and waiting for it to close.

This module imports nothing heavy at load: ELI v3 reads the description without starting
anything.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path
from typing import Any

from eli_vr import __version__

CONTRACT = 1
BUNDLE_ID = "vr"
DEFAULT_PORT = 8081
_ICON = Path(__file__).resolve().parent / "eli_vr_256.png"

# What a folder holds when ELI VR is in it: a build for one of the systems, or the project.
_BUILDS = ("ELI-VR.x86_64", "ELI-VR.exe", "ELI VR.app/Contents/MacOS/ELI VR")
_PROJECT = "project.godot"


def describe() -> dict[str, Any]:
    return {
        "contract": CONTRACT,
        "id": BUNDLE_ID,
        "title": "ELI VR",
        "summary": "ELI's rooms as places to stand in, in a headset or on a monitor, with ELI present.",
        "version": __version__,
        "edition": BUNDLE_ID,
        "icon": str(_ICON) if _ICON.is_file() else "",
        "launch": "eli_vr.bundle:launch",
        "needs": ["server"],
        "requires_core": ">=3.0.131",
    }


def launch(argv: list[str] | None = None, *, host: dict[str, Any] | None = None) -> int:
    """Open ELI VR, hosted by ELI v3.

    ELI v3 says which port its local server is answering on. An ELI v3 from before it did that
    is helped out: the server is started here, in its process, on this machine only, and
    stopped again when ELI VR closes. ELI VR keeps its settings in its own folder, never
    ELI v3's.
    """
    port, server = _core_server(host)
    env = dict(os.environ)
    env["ELI_API_PORT"] = str(port)
    if host:
        env["ELI_VR_HOST"] = f"{host.get('name', 'ELI v3')} {host.get('version', '')}".strip()
    try:
        return int(subprocess.call([*own_command(), *(argv or [])], env=env))
    finally:
        if server is not None:
            server.should_exit = True


# ── ELI v3's local server ────────────────────────────────────────────────────
def _port() -> int:
    try:
        from eli.runtime.server_util import effective_api_port

        return int(effective_api_port())
    except Exception:
        return int(os.environ.get("ELI_API_PORT") or DEFAULT_PORT)


def _answers(port: int) -> bool:
    """Whether ELI, and not something else, is serving on this port."""
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/v1/world/state", timeout=1.5) as reply:
            return json.load(reply).get("type") == "eli_world_state"
    except Exception:
        return False


def _core_server(host: dict[str, Any] | None = None) -> tuple[int, Any]:
    """The port ELI is serving on, and the server if it had to be started here."""
    if host and host.get("api_port"):
        return int(host["api_port"]), None
    port = _port()
    if _answers(port):
        return port, None
    try:
        import uvicorn
        from api.server import app
    except Exception:
        # Not inside ELI v3. ELI VR still opens, and says ELI is not running.
        return port, None
    server = uvicorn.Server(
        uvicorn.Config(app, host="127.0.0.1", port=port, log_level="warning", loop="asyncio")
    )
    threading.Thread(target=server.run, name="eli-vr-core-server", daemon=True).start()
    deadline = time.monotonic() + 30.0
    while time.monotonic() < deadline and not _answers(port):
        time.sleep(0.25)
    return port, server


# ── where ELI VR is ──────────────────────────────────────────────────────────
def config_dir() -> Path:
    if os.name == "nt":
        return Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming") / "eli-vr"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "eli-vr"
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "eli-vr"


def _holds_eli_vr(folder: Path) -> bool:
    return any((folder / name).exists() for name in (*_BUILDS, _PROJECT))


def _remembered() -> Path | None:
    """Where ELI VR was when it was last registered: a folder, or one file to run."""
    note = config_dir() / "location"
    if not note.is_file():
        return None
    kept = Path(note.read_text(encoding="utf-8").strip())
    return kept if kept.exists() else None


def _beside() -> Path | None:
    """The folder this file came with, when that is a checkout or an unpacked download."""
    folder = Path(__file__).resolve().parents[2]
    return folder if _holds_eli_vr(folder) else None


def app_file() -> Path | None:
    """ELI VR as one file to run (an AppImage): named by ELI_VR_APP, or remembered."""
    named = os.environ.get("ELI_VR_APP")
    if named and Path(named).is_file():
        return Path(named).resolve()
    kept = _remembered()
    return kept if kept is not None and kept.is_file() else None


def home() -> Path | None:
    """The folder ELI VR is in: named by ELI_VR_HOME, or the one this file came with, or the
    one remembered from the last ``eli-vr bundle register``."""
    named = os.environ.get("ELI_VR_HOME")
    if named and _holds_eli_vr(Path(named)):
        return Path(named).resolve()
    beside = _beside()
    if beside is not None:
        return beside
    kept = _remembered()
    return kept if kept is not None and kept.is_dir() and _holds_eli_vr(kept) else None


def _godot() -> str | None:
    named = os.environ.get("GODOT_BIN")
    if named and Path(named).exists():
        return named
    for name in ("godot", "godot4", "Godot"):
        found = shutil.which(name)
        if found:
            return found
    mac = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    return str(mac) if mac.exists() else None


def own_command() -> list[str]:
    """How to start this copy of ELI VR from outside, with its link to ELI on."""
    if os.environ.get("ELI_VR_APP"):
        app = app_file()
        if app is None:
            raise FileNotFoundError("ELI_VR_APP does not name a file.")
        return [str(app), "--eli"]
    folder = home()
    if folder is None:
        app = app_file()
        if app is not None:
            return [str(app), "--eli"]
        raise FileNotFoundError(
            "ELI VR was not found. Set ELI_VR_HOME to its folder, or ELI_VR_APP to its AppImage."
        )
    built = next((folder / name for name in _BUILDS if (folder / name).exists()), None)
    session = folder / "launch" / "eli-vr.sh"
    if sys.platform.startswith("linux") and session.is_file() and (built or _godot()):
        # the launcher also starts the desktop helper and stops the VR runtime on exit
        return [str(session), "--eli"]
    if built is not None:
        return [str(built), "--", "--eli-link=on"]
    godot = _godot()
    if godot is None:
        raise FileNotFoundError("Godot 4.7.2 was not found. Set GODOT_BIN to its executable.")
    return [str(Path(godot).resolve()), "--path", str(folder), "--", "--eli-link=on"]


# ── registering a separately installed copy with ELI v3 ───────────────────────
def v3_bundle_dirs() -> list[Path]:
    """The folders ELI v3 looks in for separately installed bundles."""
    if os.name == "nt":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    out = [base / "ELI_v3" / "bundles"]
    if os.environ.get("ELI_DATA_DIR"):
        out.append(Path(os.environ["ELI_DATA_DIR"]) / "bundles")
    return out


def record() -> dict[str, Any]:
    """What a registration says: the description, with the command that starts this copy.
    The icon is one kept in ELI VR's own config folder, because the one beside this file is
    gone again when the copy registering is an AppImage."""
    kept = str(config_dir() / _ICON.name) if _ICON.is_file() else ""
    return {**describe(), "command": own_command(), "launch": "", "icon": kept}


def register(target: Path | None = None) -> Path:
    """Tell ELI v3 where this copy is, so it can offer to open it. Writes one small file, and
    notes where ELI VR is so a copy of this package installed into ELI v3's environment finds
    it too."""
    described = record()
    folder = target or v3_bundle_dirs()[0]
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{BUNDLE_ID}.json"
    path.write_text(json.dumps(described, indent=2) + "\n", encoding="utf-8")
    config_dir().mkdir(parents=True, exist_ok=True)
    if described["icon"]:
        shutil.copyfile(_ICON, described["icon"])
    where = app_file() if os.environ.get("ELI_VR_APP") else (home() or app_file())
    if where is not None:
        (config_dir() / "location").write_text(str(where) + "\n", encoding="utf-8")
    return path


def unregister(target: Path | None = None) -> list[Path]:
    removed = []
    for folder in [target] if target else v3_bundle_dirs():
        path = folder / f"{BUNDLE_ID}.json"
        if path.is_file():
            path.unlink()
            removed.append(path)
    return removed
