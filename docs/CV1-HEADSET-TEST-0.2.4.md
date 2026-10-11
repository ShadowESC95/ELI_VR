# ELI VR 0.2.4 — Rift CV1 headset validation

This revision isolates headset validation from the unfinished Wayland desktop-capture backend.

## What changed

- CV1 launcher now uses native Monado directly and explicitly pins its OpenXR manifest.
- SteamVR presence is treated as a conflict instead of silently allowing the wrong runtime.
- The known-good Monado stdin FIFO workaround is retained.
- The legacy desktop bridge is stopped/disabled for the headset test.
- ELI VR receives `--eli-desktop=off` for the headset validation run.
- Godot is run as a child instead of `exec`, allowing the launcher to cleanly stop Monado when Godot exits.
- Godot XR logs are written to `~/.local/state/eli-vr-standalone/godot-xr.log`.
- Volumetric fog is no longer requested when the Mobile renderer is active.
- `libgbm-dev` is included in the Ubuntu desktop-bridge build dependency list.
- Starting the legacy bridge on Wayland is blocked by default to prevent repeated screenshot/portal requests.

## Test command

```bash
./launch/run-linux-cv1-headset-test.sh
```

Expected pipeline:

```text
Godot / ELI VR
    -> OpenXR
    -> native Monado Rift CV1 runtime
    -> Rift CV1
```

WayVR and SteamVR are not part of this path.

## Logs

```text
~/.local/state/eli-vr-standalone/monado.log
~/.local/state/eli-vr-standalone/godot-xr.log
```
