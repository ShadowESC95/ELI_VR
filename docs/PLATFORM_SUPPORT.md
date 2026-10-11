# Platform support strategy

## Windows

Target:

- flat 3D: yes
- OpenXR: yes, where an OpenXR runtime is installed
- desktop capture helper: source included
- final capture path: Windows Graphics Capture / shared D3D textures

## Linux

Target:

- flat 3D: yes
- OpenXR: yes, runtime dependent
- desktop capture helper: source included
- final capture path: PipeWire with DMA-BUF/Vulkan where available

Wayland screen capture is permission/compositor sensitive. The portable bridge is a fallback, not the final zero-copy path.

## macOS

Target:

- flat 3D: yes
- desktop capture: source included, Screen Recording permission required
- XR: only where a suitable OpenXR/runtime path exists

ELI VR does not assume macOS has the same PCVR runtime ecosystem as Windows/Linux.

## Android / standalone XR

Architecture target:

- Godot/OpenXR world
- no host desktop requirement
- optional remote ELI/desktop surfaces
- device-specific export/runtime packaging

Not packaged as an Android APK in this source alpha.

## Hardware scaling

Use the quality profiles:

- low
- medium
- high
- ultra

The room model is identical. Geometry density, volumetrics, particles, shadows and OpenXR render scale change.
