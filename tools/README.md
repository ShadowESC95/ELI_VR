# Tools

Helpers for working on ELI VR. The app does not use any of them at run time. Python 3.10 or newer; `pip install -r requirements.txt` covers the checks.

## Everyday

| Tool | What it does |
|---|---|
| `eli_vr.py` | The settings CLI: rooms, themes, quality, the ELI link. `python3 tools/eli_vr.py show` |
| `register_eli_bundle.py` | Puts this copy of ELI VR on ELI v3's list of bundles. `--show` prints, `--remove` takes it off |
| `doctor.py` | What this machine has: GPU, OpenXR runtime, capture. Leaves your home folder name out |
| `install_room_pack.py` | Installs a room pack from a local `.zip` |

## Checks

| Tool | What it catches |
|---|---|
| `source_sanity.py` | Mangled GDScript: a block of code flattened onto one line with literal `\n` in it |
| `validate_project.py` | Project structure, room and theme data, assets that should be there |
| `network_audit.py` | A remote address in runtime code |
| `godot_parse_check.sh` | Anything Godot itself will not load |
| `make_release.py --check` | Personal data, machine paths or compiled binaries in what would be published |

`python3 -m unittest discover -s tests` covers the ELI v3 bundle side.

## Making things

| Tool | What it does |
|---|---|
| `make_release.py` | Builds the clean source package. The privacy gate runs first and stops it |
| `prepare_space_assets.py` | Turns the downloaded source imagery into the textures the rooms use. Needs numpy, Pillow and ffmpeg |
| `set_texture_imports.py` | Sets how Godot imports those textures: compressed on the GPU, with mipmaps |

## Linux desktop capture

| Tool | What it does |
|---|---|
| `install-linux-wayland-capture-deps.sh` | Installs what the Wayland helper needs, from the distro |
| `check-linux-wayland-capture.sh` | Says which of those are missing |

## Reports

`audit_godot.py` collects a full diagnostic report of the Godot project and this machine under `build/`: Godot binary and version, headless start, GPU driver, Vulkan, OpenXR runtime manifests, logs. It records machine details, so read it before sharing it. `build/` is never part of a release.
