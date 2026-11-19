# Architecture

```text
                          ELI VR  (Godot 4.7, GDScript)
        rooms · themes · settings · console · portals · desktop screen
                                   |
        +--------------+-----------+-----------+----------------+
        |              |                       |                |
     OpenXR         Flat 3D             Desktop screen       ELI link
   any runtime   mouse + keyboard     frames on loopback   on where ELI v3 is
        |                                      |                |
   the headset                          capture helper     ELI v3's local
                                        (one per OS)           server
```

Everything above the line is one Godot project that runs the same on Linux, Windows and macOS. Everything below it is optional and found at run time.

## Rule: the core does not know the headset, the OS or the user

Rooms, themes and settings contain nothing about a headset vendor, an OpenXR runtime, a capture API or a machine. Those are adapters. Paths are worked out at run time from the project folder and the OS's per-user folders; nothing is written into the project.

## Starting up

`main.tscn` is one node carrying `scripts/app.gd`, and there are no autoloads. `app.gd` builds everything: settings (`core/app_config.gd`), the lists of rooms, places and themes (`core/registry.gd`), the network policy (`core/network_policy.gd`), the licence check (`core/licence.gd`), XR (`xr/xr_bootstrap.gd`), the room, the desktop screen, the console and portals, and the ELI link if it is on.

`XRBootstrap` asks Godot for an OpenXR interface. If one starts, the viewport renders to the headset, controllers use the action map in `openxr_action_map.tres`, and controller rays press `Interactable3D` nodes. If none does, the same world opens as an ordinary 3D window with mouse and keyboard. Nothing else changes between the two.

## Rooms

What exists is data:

```text
config/rooms/rooms.json               the nine ELI rooms and ELI's own room, and which place each one is
config/rooms/environments.json        the fifteen places and the place that is ELI's own room
config/rooms/environment_assets.json  the sound each place plays
config/themes/themes.json             the eight themes
config/profiles/*.json                the four quality profiles
```

How a place looks is one script each, in `scripts/world/rooms/`, all built on `room_base.gd`. The shared pieces are in `scripts/world/kit/`:

| Piece | What it gives a room |
|---|---|
| `rooms/room_base.gd` | Sky (star map or a photographed panorama laid on the ground), sun, lamps, a deck or a hall, drifting particles, things that turn and blink; a board's heading and the place a pinned sheet takes (`board_heading`, `pinned`); ELI's state handed to the room's screens (`show_eli`) |
| `kit/mesh_kit.gd` | Shapes made in code: lathed profiles, terrain, rocks, beams, plants, and the boxes, rods, balls and lamps that the rooms, ELI's things, its guns and the bookcases are hung from (`part`, `box`, `cylinder`, `ball`, `omni`, `laid_along`). UVs are in metres. A room keeps the shapes its last build asked for |
| `kit/material_kit.gd` | Scanned materials (albedo, normal, packed occlusion/roughness/metal), glass, lights, shaders |
| `kit/land_kit.gd` | Open ground out of doors: two scanned surfaces blended by slope and height, the ground's height at any point, ground cover |
| `kit/model_cache.gd` | The real models in `assets/models/`, loaded once and kept while ELI VR runs |
| `kit/reading.gd` | How writing is sized, wrapped and paged to be read from where it hangs, and the one typed font |
| `kit/info_screen.gd`, `kit/eli_readout.gd` | A screen of true lines, and ELI's state put into those lines the same way in every room |
| `kit/evidence_sheet.gd` | One sheet of the Evidence Wall, written with one of ELI's records |
| `kit/bookcase.gd` | Shelves for ELI's books, in the Memory Archive and in ELI's own room |
| `kit/flock.gd`, `kit/black_hole.gd` | Birds in flight as one batch; how light bends past the Anomaly Room's black hole, worked out once for its shader |
| `assets/shaders/` | Planet, air, water, aurora, hologram, the desktop screen and the rest. The hash and value noise the room shaders share are in `include/noise.gdshaderinc` |
| `assets/space`, `assets/skies`, `assets/materials`, `assets/models` | The art. Sources and licences in [assets/CREDITS.md](../assets/CREDITS.md) |

`room_factory.gd` is the list of which script is which place: it builds the script for the place asked for and hands it the theme and the settings. A place no script answers to (a saved override from another version, a mistyped `--eli-environment`) is built as the Orbital Core, `rooms/orbital_core.gd`. A theme only colours the lights; a quality profile switches shadows and particles and sets how much small detail a room fills itself with.

The Evidence Wall (`rooms/evidence_studio.gd`) works its boards out again only when what it reads of ELI's message has changed: its own records, the feed's `evidence` and `thoughts`, and whether ELI is connected. A message that changed something elsewhere costs it nothing.

`tools/prepare_space_assets.py` is how the art was made from its sources, so it can be made again. Nothing is downloaded when ELI VR runs.

## Desktop screen

```text
the OS's screen capture          Wayland: portal + PipeWire (Python helper)
        |                        X11, Windows, macOS: native helper (Rust)
lossless tiles over 127.0.0.1:47831, only where the screen changed; pointer lines back
        |
desktop/desktop_bridge_client.gd  (its own thread)
        |
desktop/desktop_surface.gd: the tiles, then the desktop brought to the size it is seen at
        |
the VR runtime's own layer (cylinder or quad), seen through a hole cut in the room;
or, where the runtime has none and in the flat window, the same shape drawn in the room
```

The app never captures anything itself. It reads frames from a helper on the same machine, and the helper refuses to listen anywhere but loopback and to anyone without the key it keeps for this account. Tiles that did not change are not sent, and nothing is drawn or handed to the runtime until something does. The room's own rendering never touches the desktop's pixels in the headset: the hole is cut after the room is drawn, and hands, pointers, panels and ELI are drawn after it (`keep_in_front`).

## ELI link

`scripts/eli/`, off by default:

| Script | What it does |
|---|---|
| `eli_link.gd` | The socket and HTTP calls to ELI v3's local server. Agrees a protocol version and capabilities on connecting, reads each message on a worker thread, and keeps the records it was sent so that an unchanged one can come by its id alone |
| `eli_result.gd` | What came of a request: the answer, or which kind of failure |
| `eli_presence.gd` | ELI in the room |
| `eli_voice.gd` | Push to talk: a turn of conversation, or a piece of building |
| `eli_senses.gd` | Tells ELI the scene: where you are, what you look at, what is near |
| `eli_things.gd`, `eli_thing.gd` | Draws what ELI has built in the room you are in |
| `eli_motion.gd` | Where ELI's light goes in the room, and why |
| `eli_thoughts.gd` | Lines of what is on ELI's mind, rising from its light |
| `eli_initiative.gd` | Asks ELI to make something of a waiting moment while you are there |
| `eli_room_light.gd` | A room ELI has relit: its glowing fixtures take the colour ELI chose |
| `eli_play.gd` | Runs the rules of a game ELI set, keeps the score and tells ELI's world how it went |
| `eli_arm.gd`, `eli_arms.gd` | The guns of the range: how each looks and sounds, and one in the hand |
| `eli_book.gd` | A book of ELI's records, taken from a shelf and read page by page |
| `eli_props.gd`, `eli_models.gd` | The real models ELI can place, as ELI is told of them; models of ELI's own fetched from ELI v3 |
| `eli_pictures.gd` | Pictures ELI took or looked at for you, fetched from ELI v3 once each |
| `eli_bundle.gd` | Puts this copy on ELI v3's list of bundles at each start, and reads which port ELI v3 serves on |

`scripts/world/rooms/own_room.gd` is ELI's own room, drawn with the sky, ground and light ELI's world says ELI chose.

ELI v3 publishes its room and state; ELI VR draws them. ELI's reasoning, memory and model stay in ELI v3, and ELI VR stays a renderer that also runs alone. See [ELI_INTEGRATION.md](ELI_INTEGRATION.md).

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

`NetworkPolicy.is_loopback_host` is the one list of hosts that count as this machine; the desktop link and the ELI link both ask it.

No third-party API client is in the runtime, and `tools/network_audit.py` fails the build if a remote address appears in it. See [NETWORK-POLICY.md](NETWORK-POLICY.md).
