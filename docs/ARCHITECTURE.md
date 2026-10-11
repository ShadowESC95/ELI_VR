# Architecture

```text
                     ELI VR CORE
              rooms / settings / themes
                         |
        +----------------+----------------+
        |                                 |
    World Renderer                    Platform Services
       Godot 4                          adapters
        |                                 |
  +-----+------+                    +-----+------+
  |            |                    |            |
OpenXR       Flat 3D           Desktop capture Future ELI
  |            |                    |           bridge
runtime    mouse/keyboard      Rust helper      disabled
```

## Rule: core logic does not depend on a headset vendor or operating system

The project data model contains no Rift, Quest, Vive, Index, Monado, SteamVR, PipeWire, Windows Graphics Capture, or ScreenCaptureKit assumptions.

Those are runtime/backend concerns.

## OpenXR layer

`XRBootstrap` discovers Godot's `OpenXR` interface. If it initializes:

- main viewport uses XR;
- XROrigin3D/XRCamera3D are active;
- Touch/generic OpenXR controllers use Godot's action map;
- controller rays activate `Interactable3D` nodes.

If not, the same world runs in ordinary 3D desktop mode.

## World layer

Room definitions are data:

```text
config/rooms/rooms.json
config/rooms/environments.json
```

`RoomFactory` currently creates geometry procedurally. This deliberately avoids locking the project to imported commercial assets.

Production versions can replace a procedural environment with `.tscn`, glTF or packaged environment content while leaving the room registry intact.

## Desktop layer

The alpha desktop bridge intentionally favors portability over latency:

```text
native OS capture
      |
  Rust/xcap
      |
JPEG frames over localhost
      |
Godot ImageTexture
      |
3D desktop mesh
```

Later:

```text
Windows -> shared D3D texture
Linux   -> PipeWire DMA-BUF/Vulkan import
macOS   -> IOSurface/Metal
```

The `DesktopSurface` API does not need to change when these are introduced.

## ELI v3 integration seam

`scripts/core/future_eli_bridge.gd` is disabled.

The future ELI process can publish room/world state through a local transport and drive this application without moving ELI's domain model into Godot.

That keeps:

- ELI's reasoning/world state independent;
- ELI VR replaceable as a renderer;
- standalone mode available.

## Network boundary

Normal ELI VR runtime has no internet dependency.

All currently permitted socket use is localhost-only and passes through the standalone network policy:

```text
ELI VR
  |
NetworkPolicy (LOCAL_ONLY)
  |
  +-- 127.0.0.1:47831 desktop bridge
  +-- 127.0.0.1:47832 future ELI bridge (disabled)
```

There is no third-party API client in the runtime.
