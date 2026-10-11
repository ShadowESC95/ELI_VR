# Advanced platform and optimisation layer

ELI VR 0.2 adds 4K procedural environment assets, ambient audio, OpenXR capability detection, dynamic render-scale control, automatic foveation when supported, XR session focus handling, a composition-layer desktop path with fallback, and a cross-platform hardware doctor.

Run `python3 tools/doctor.py` before first XR launch.

OpenXR extensions are treated as optional capabilities rather than requirements.

## Optional photorealistic HDRI pack

The project ships with generated 4K panoramas so it works offline. For higher fidelity, the included downloader can install CC0 HDRIs from local environment packs using their public API:

```bash
```

For a stronger GPU and more disk space:

```bash
```

The downloader validates the API-published MD5 hash and rewrites only the relevant `environment_assets.json` entries. The procedural offline assets remain in the project as fallbacks.


## Local room packs

```bash
python3 tools/install_room_pack.py /path/to/room-pack.zip
```

ELI VR does not fetch packs from the internet.
