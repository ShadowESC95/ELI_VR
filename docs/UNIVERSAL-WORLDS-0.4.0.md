# ELI VR 0.4.0 — Universal Worlds

0.4.0 removes the assumption that ELI VR is a Linux/CV1 product.

## Runtime architecture

The product core remains:

```text
ELI VR world / UI / interaction
        |
        +-- OpenXR adapter (where OpenXR exists)
        +-- desktop-capture adapter
        +-- OS/window/input adapter
        +-- hardware/quality profile
```

The Linux CV1 launcher remains a development adapter only. It is not the
architecture boundary.

ELI VR now records OS, CPU threads/model, RAM, GPU model/vendor/type/API and
rendering backend, then selects a conservative starting quality profile when
`graphics.auto_quality` is enabled. Users retain Auto plus manual Low/Medium/High/Ultra
overrides. Runtime framerate remains the final authority: GPU model names are
never treated as a complete performance benchmark.

Godot's core APIs are used for hardware information, keeping this detection
portable instead of shelling out to Linux-specific commands.

## Desktop capture

The XR desktop surface is now independent from the capture provider. Toggling
DESKTOP SCREEN always shows/hides the actual spatial screen.

Live frames are supplied through a local capture adapter:

- Windows: Windows Graphics Capture / Desktop Duplication.
- Linux Wayland: XDG Desktop Portal ScreenCast + PipeWire.
- Linux X11: X11/native capture.
- macOS: ScreenCaptureKit + Metal/IOSurface.
- Android XR: remote desktop or MediaProjection.
- iOS: remote source/ReplayKit where appropriate.
- Web: explicit browser capture APIs.

These native providers are separate adapter work; 0.4.0 does not falsely claim
that one Linux capture implementation works on every OS.

The CV1 launcher no longer passes `--eli-desktop=off`, so the desktop surface
can be toggled in XR. It still does not automatically start the old Wayland
xcap bridge, preventing repeated screenshot permission dialogs.

## XR HUD

The old HUD was a CanvasLayer and therefore did not exist in XR. The HUD toggle
now controls a real head-locked Label3D status display showing FPS, environment,
hardware class, quality mode and desktop state.

## Universal movement

Free-flight is enabled in every environment by default:

- left stick: move in the direction you are looking;
- left stick click: boost;
- right stick Y: vertical movement;
- right stick X: snap turn.

This makes mountains, forests, stations, laboratories, ocean, arctic, desert
and every other world traversable with the same freedom as Deep Space.

## Complete environment pass

Every registered environment now receives a full 4π procedural background,
including below the user. The legacy environments that were still room-scale
prototype geometry were rebuilt into much larger spatial volumes:

- Orbital Core Station: nested orbital structures and full star field.
- Memory Cathedral: long cathedral volume, columns and floating memory shards.
- Engineering Workshop: multi-level industrial rings and floating work cells.
- Mountain Observatory: larger generated mountain field and observation deck.
- Debug Bunker: red diagnostic grid volume and server canyons.
- Fabrication Lab: multi-level radial fabrication structure.
- Digital Matrix: full grid/data volume.
- Anomaly Void: large volumetric-looking void with floating impossible forms.
- Evidence Studio: repeated investigation galleries and floating evidence.
- Forest Sanctuary: larger terrain and denser instanced forest.
- Ocean Platform: expanded ocean, islands and platform structure.
- Deep Space: richer nebula/star shell, six lit planets and larger asteroid field.
- Arctic Aurora: larger ice terrain and animated full-sphere aurora.
- Desert Observatory: larger procedural terrain and monument field.
- Underwater Lab: expanded sea floor, suspended particles and coral structures.

Deep Space also receives a strong directional key light and planet self-light
floor so the planets no longer collapse into black silhouettes on the CV1.

## Theme identities

Themes are no longer literal colour labels. The current visual identities are:

- Frontier Glass
- Obsidian Gold
- Nebula Royal
- Verdant Circuit
- Solar Flare
- Abyssal Glass
- Polar Aurora
- Monolith

A theme now affects world surface tint, sky palette, accent lighting and
emission strength, not just button text/accent colour.

## Hardware scope

A single binary cannot guarantee identical rendering cost across every CPU,
GPU, RAM amount, OS and XR runtime. ELI VR therefore uses capability-driven
profiles plus manual overrides rather than hard-coding an RTX/NVIDIA/Linux
assumption.

The current CV1/RTX 2060 SUPER machine remains a reference test target, not the
product definition.
