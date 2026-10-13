# Architecture

```text
                          ELI VR  (Godot 4.7, GDScript)
        rooms · themes · settings · console · portals · desktop screen
                                   |
        +--------------+-----------+-----------+----------------+
        |              |                       |                |
     OpenXR         Flat 3D             Desktop screen       ELI link
   any runtime   mouse + keyboard     frames on loopback   off by default
        |                                      |                |
   the headset                          capture helper     ELI v3's local
                                        (one per OS)           server
```

Everything above the line is one Godot project that runs the same on Linux, Windows and macOS. Everything below it is optional and found at run time.

## Rule: the core does not know the headset, the OS or the user

Rooms, themes and settings contain nothing about a headset vendor, an OpenXR runtime, a capture API or a machine. Those are adapters. Paths are worked out at run time from the project folder and the OS's per-user folders; nothing is written into the project.

## Starting up

`scripts/app.gd` builds everything: settings (`core/app_config.gd`), the network policy, XR (`xr/xr_bootstrap.gd`), the room, the desktop screen, the console and portals, and the ELI link if it is on.

`XRBootstrap` asks Godot for an OpenXR interface. If one starts, the viewport renders to the headset, controllers use the action map in `openxr_action_map.tres`, and controller rays press `Interactable3D` nodes. If none does, the same world opens as an ordinary 3D window with mouse and keyboard. Nothing else changes between the two.

## Rooms

What exists is data:

```text
config/rooms/rooms.json          the nine ELI rooms and which place each one is
config/rooms/environments.json   the fifteen places
config/themes/themes.json        the eight themes
config/profiles/*.json           the four quality profiles
```

How a place looks is one script each, in `scripts/world/rooms/`, all built on `room_base.gd`:

| Piece | What it gives a room |
|---|---|
| `rooms/room_base.gd` | Sky (star map or a photographed panorama laid on the ground), sun, lamps, a deck or a hall, drifting particles, things that turn and blink |
| `kit/mesh_kit.gd` | Shapes made in code: lathed profiles, terrain, rocks, beams, plants. UVs are in metres |
| `kit/material_kit.gd` | Scanned materials (albedo, normal, packed occlusion/roughness/metal), glass, lights, shaders |
| `assets/shaders/` | Planet, atmosphere, water, aurora, hologram, screens and the rest |
| `assets/space`, `assets/skies`, `assets/materials` | The art. Sources and licences in [assets/CREDITS.md](../assets/CREDITS.md) |

`room_factory.gd` picks the script for the place and hands it the theme and the quality settings. A theme only colours the lights; a quality profile switches shadows, fog and particles and sets the render scale.

`tools/prepare_space_assets.py` is how the art was made from its sources, so it can be made again. Nothing is downloaded when ELI VR runs.

## Desktop screen

```text
the OS's screen capture          Wayland: portal + PipeWire (Python helper)
        |                        X11, Windows, macOS: native helper (Rust)
JPEG frames over 127.0.0.1:47831
        |
desktop/desktop_bridge_client.gd  ->  a texture on desktop/desktop_surface.gd
```

The app never captures anything itself. It reads frames from a helper on the same machine, and the helper refuses to listen anywhere but loopback. This favours working everywhere over latency; a shared-texture path per OS can replace it later without the screen itself changing.

## ELI link

`scripts/eli/`, off by default:

| Script | What it does |
|---|---|
| `eli_link.gd` | The socket and HTTP calls to ELI v3's local server. Agrees a protocol version on connecting |
| `eli_result.gd` | What came of a request: the answer, or which kind of failure |
| `eli_presence.gd` | ELI in the room |
| `eli_voice.gd` | Push to talk: a turn of conversation, or a piece of building |
| `eli_senses.gd` | Tells ELI the scene: where you are, what you look at, what is near |
| `eli_things.gd`, `eli_thing.gd` | Draws what ELI has built in the room you are in |

`scripts/world/rooms/own_room.gd` is ELI's own room, drawn with the sky, ground and light his world says he chose.

ELI v3 publishes his room and state; ELI VR draws them. ELI's reasoning, memory and model stay in ELI v3, and ELI VR stays a renderer that also runs alone. See [ELI_INTEGRATION.md](ELI_INTEGRATION.md).

## ELI v3 bundle

`src/eli_vr/` is a small Python package and the only Python in the product: how ELI v3 finds ELI VR and starts it. `bundle.py` gives ELI v3 the description its bundle contract asks for and a launch function; `cli.py` is the `eli-vr` command that registers a copy. The Godot app does not use it.

## Linux session

`launch/eli-vr.sh` and `launch/lib-session.sh` start the desktop helper and the app, and on exit stop the helper and every VR runtime process the session started, so nothing is left holding GPU memory. A runtime that was already running is left alone. The AppImage is this launcher in one file.

## Network boundary

```text
ELI VR
  |
NetworkPolicy (LOCAL_ONLY)
  |
  +-- 127.0.0.1:47831   desktop capture helper
  +-- 127.0.0.1:8081    ELI v3's local server, only with the ELI link on
```

No third-party API client is in the runtime, and `tools/network_audit.py` fails the build if a remote address appears in it. See [NETWORK-POLICY.md](NETWORK-POLICY.md).
