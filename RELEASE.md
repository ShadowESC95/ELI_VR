# Cutting an ELI VR release

Maintainer: **ShadowESC95/ELI_VR** on GitHub. New users want [docs/INSTALL.md](docs/INSTALL.md) instead.

## 1. Bump the version

It lives in three places and they have to agree:

| File | Line |
|---|---|
| `VERSION` | the whole file |
| `pyproject.toml` | `version = "..."` |
| `project.godot` | `config/version="..."` |

Add a short note as `docs/PUBLIC-RELEASE-<version>.md`. It becomes the text of the GitHub Release.

## 2. Check it locally

```bash
python3 tools/source_sanity.py
python3 tools/validate_project.py
python3 tools/network_audit.py
python3 -m unittest discover -s tests
./tools/godot_parse_check.sh
python3 tools/make_release.py --check
```

`make_release.py` is the privacy gate. It stops if anything that would be published contains a home folder path, the builder's user or host name, an e-mail address, a Steam ID, a device serial or a compiled binary.

## 3. Tag and push

```bash
git tag v0.9.2 && git push origin v0.9.2
```

The `release` workflow does the rest. It fails early if the tag and the three version lines differ.

## What the workflow builds

| Asset | What it is |
|---|---|
| `ELI_VR-<v>-x86_64.AppImage` | Linux, one file: starts the desktop helper and the app, stops the VR runtime on exit |
| `ELI_VR-<v>-linux-x86_64.tar.gz` | The same Linux build as a folder |
| `ELI_VR-<v>-windows-x64.zip` | Windows build, desktop helper included |
| `ELI_VR-<v>-macos-universal.zip` | macOS app for Apple Silicon and Intel, desktop helper included |
| `ELI_VR-<v>-source.zip` | The scanned source tree |
| `SHA256SUMS.txt` | Checksums for the five above |

The three apps are exported from one Linux machine with Godot's official export templates. The desktop helper is compiled on each OS. Every package also carries `src/eli_vr`, `pyproject.toml` and `tools/register_eli_bundle.py`, the Python side that ELI v3 finds ELI VR by. Nothing is code-signed or notarised yet, which is why Windows and macOS warn on first launch.

## Dry run

Actions → **release** → **Run workflow** builds everything and keeps the packages as workflow artifacts without publishing a Release. Do this before tagging when the workflow itself has changed.
