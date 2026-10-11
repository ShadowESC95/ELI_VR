# ELI VR / Godot audit

This is a read-only diagnostic collector for a Godot project.

## Install into the project

From the project root (the folder containing `project.godot`):

```bash
python3 tools/audit_godot.py
```

It creates a timestamped report under `build/` and a `.tar.gz` archive.

The report records machine details (paths, environment, GPU and runtime
information). Read it before sharing it; `build/` is never part of a release.

## What it checks

- exact Godot binary, real path, version, ELF/library dependencies
- headless project startup
- headless editor startup
- compatibility-renderer startup
- NVIDIA driver output
- Vulkan summary
- OpenGL summary (if `glxinfo` exists)
- Wayland/X11 session metadata
- OpenXR runtime manifests and relevant environment variables
- `.godot` cache presence/size
- `project.godot` and `export_presets.cfg`
- recent Godot log files
- Git status and project/script diff when the project is a Git checkout

The script does not intentionally modify project files. Godot itself can refresh `.godot`
cache/import metadata when started in headless/editor mode.
