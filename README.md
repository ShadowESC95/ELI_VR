# ELI VR

A spatial workspace you can stand inside: fifteen places from an orbiting station to a misty forest, a movable live desktop screen, and a control console, built on Godot 4.7 and OpenXR. It runs in a headset, and it runs on a plain monitor when there isn't one.

**Version 0.9.2** · Linux · Windows · macOS

![The Core Room: an observation deck in orbit, Earth below and the Milky Way overhead](docs/images/core-room.jpg)

ELI VR is part of the ELI family but does not need ELI to run. With ELI v3 running beside it, ELI is present in the rooms and you can talk to ELI, and ELI v3 can open ELI VR itself as one of its bundles. There is no account, no telemetry and nothing leaves the machine.

## Status

This is an early build. Be clear-eyed about what has and has not been tried:

| | State |
|---|---|
| Linux, Wayland, Monado, Rift CV1 with Touch | The reference setup. Tested in the headset. |
| Flat (no headset) mode on Linux | Tested. |
| Windows and macOS builds | Built by CI. Not yet run on real hardware. |
| Valve Index, HTC Vive, Windows Mixed Reality, generic OpenXR controllers | Bound, not yet tested on hardware. |
| The link to ELI v3 (presence, talking) | Tested against ELI v3's own routes without a headset. Not yet used in one. |
| ELI building in the rooms, and ELI's own room | Tested flat against ELI v3's real server and a real, very small model. ELI's room was run in the headset; building has not yet been spoken into one. |
| Opened from ELI v3 as a bundle | Tested with ELI v3's own launch code and a stand-in for the app. Not yet opened that way into a headset. |
| Quest, Pico and other standalone headsets | No native app yet. Use them through a PC link (Link, Air Link, Virtual Desktop, ALVR, WiVRn). |
| macOS in VR | No common OpenXR runtime exists there. Flat mode only. |

If you run it on something not listed as tested, an issue saying what happened is genuinely useful.

## Install

Full step-by-step guides for every OS are in **[docs/INSTALL.md](docs/INSTALL.md)**. The short version:

**From a release build** (no Godot needed): download the archive for your OS from the [Releases](https://github.com/ShadowESC95/ELI_VR/releases) page, unpack it and run `ELI-VR`. On Linux there is also a one-file AppImage that starts everything and stops the VR runtime again when you leave.

**From source** (needs [Godot 4.7.2](https://godotengine.org/download)):

```bash
git clone https://github.com/ShadowESC95/ELI_VR.git
cd ELI_VR
./launch/run-linux.sh          # Linux
./launch/run-macos.command     # macOS
```

```powershell
.\launch\run-windows.ps1       # Windows
```

Each launcher takes a mode: `auto` (default), `xr`, `flat` or `compat` (OpenGL fallback for older GPUs). If Godot is not on your `PATH`, point `GODOT_BIN` at it.

With `auto`, ELI VR uses a headset when an OpenXR runtime is active and falls back to the flat window when it is not.

## Controls

### Flat mode

| Input | Action |
|---|---|
| Hold right mouse | Look |
| `W` `A` `S` `D` | Move |
| `Q` / `E` | Down / up |
| `F1` | Settings dock |
| `F2` | Desktop screen |
| `F3` | Performance HUD |
| `F5` | Rebuild the current room |
| Hold `T` | Talk to ELI (with the ELI link on) |
| `B` / `Z` | ELI builds something of its own in its room / take the last change back |
| `Esc` | Release the mouse |

### In the headset

| Input | Action |
|---|---|
| Trigger | Press buttons, enter portals |
| Grip | Grab and move panels and objects |
| Left stick | Move |
| Right stick | Snap turn |
| B / Y | Show or hide the spatial console |
| Menu (left) | Wrist menu |
| Hold A / X | Talk to ELI (with the ELI link on) |

**Leaving:** press **EXIT** on the spatial console or the wrist menu twice, or **Exit ELI VR** in the settings dock (`F1`). Started through `./launch/eli-vr.sh` or the AppImage on Linux, closing ELI VR also stops the VR runtime it started, so no GPU memory stays held.

Oculus Touch is the tested layout. Valve Index, HTC Vive (trackpad stands in for the stick), Windows Mixed Reality and the OpenXR generic controller are mapped to the same actions. Anything else falls back to the OpenXR simple profile, which gives trigger and menu only.

## Environments

Fifteen places, each built as somewhere to be and none of them still.

![All fifteen rooms](docs/images/rooms-all.jpg)

The nine ELI rooms:

| Room | Where you are | What moves |
|---|---|---|
| Core Room | An open deck on a station in orbit, Earth below, the real Milky Way overhead | The station's outer ring, the hub, a projected globe, Earth's cloud |
| Memory Archive | A marble hall open to the stars, walls shelved with small lights | Every light keeps its own time; some drift loose and rise; rings turn overhead |
| Workshop | A repair bay with its door open to space | A welding arm, a crane on its rails, a beacon, Earth going by outside |
| Reflection Chamber | A stone terrace on a mountain plateau at dawn, ringed by still water | Birds, dust in the first light |
| Debug Basement | A concrete bunker of racks and old terminals | Status lamps, scrolling logs, a roof fan, one strip light on its way out |
| Upgrade Bay | A clean white lab | A printer building a part, crates on a belt, an arm sorting them |
| Simulation Lab | A world that is only being computed: grid, wire hills, towers of data | Everything |
| Anomaly Room | A cracked deck drifting towards a black hole | The disc of the hole, arcs between pylons, debris spiralling in |
| Evidence Wall | A dim studio with a long wall of pinned sheets strung with thread | A fan, a projector changing slides, dust in the lamps |

Six more workspaces:

| Workspace | Where you are |
|---|---|
| Forest Sanctuary | A timber deck among tall pines in morning mist |
| Ocean Platform | A rig at sea at sunset; the water carries the sky |
| Deep Space Observatory | A platform beside a ringed giant, rocks tumbling past |
| Arctic Aurora | A snowfield at night under the northern lights |
| Desert Observatory | Dunes under the Milky Way, a dome and a dish at work |
| Underwater Research Lab | A glass dome on the seabed, kelp, shoals, shafts of light |

The night sky is NASA's star map and the Earth is NASA's Blue Marble. The forest, the mountain and the sunset are photographs of real places, laid on the ground so that what is near stays put as you move. Stone, wood, metal, snow and sand are scanned materials. All of it is free to use and listed in [assets/CREDITS.md](assets/CREDITS.md).

Eight themes set the colour of the lights in every room, and four quality profiles (`low`, `medium`, `high`, `ultra`) apply everywhere. On the reference setup, a mid-range desktop GPU, all fifteen hold the headset's 90 frames a second at `ultra`; `low` and `medium` are there for less. See [docs/ADVANCED-PLATFORM-OPTIMIZATION.md](docs/ADVANCED-PLATFORM-OPTIMIZATION.md).

## Live desktop screen

The big screen in each room shows your real desktop. It needs a small capture helper running next to ELI VR; the app itself never captures anything. Frames travel over `127.0.0.1` only.

| OS | Helper | Start it with |
|---|---|---|
| Linux, Wayland | Portal + PipeWire bridge (Python) | `./launch/start-desktop-bridge-linux.sh` |
| Linux, X11 | Native bridge (Rust) | `./launch/start-desktop-bridge-linux.sh` |
| Windows | Native bridge (Rust) | `.\launch\start-desktop-bridge-windows.ps1` |
| macOS | Native bridge (Rust) | `./launch/start-desktop-bridge-macos.command` |

Start the helper, then start ELI VR. The screen reconnects on its own. On Wayland the desktop asks once which monitor to share and remembers it. Setup per OS is in [docs/INSTALL.md](docs/INSTALL.md#live-desktop-screen).

The screen is view-only for now: you can move, resize and rotate it, but not click through it.

## With ELI v3

Off by default. Switch the link on and, while ELI v3's local server is running on the same machine:

- ELI appears as a body of light in whichever room its own world has it in, and the status line says where ELI is when that room is not yours.
- Hold **A** / **X** on a controller, or **T** on the keyboard, to talk to ELI. It answers in its own voice from where it stands.
- **ELI knows where it is.** ELI is told which room you are both in and what that place is, where you are standing, what you are looking at and which of its things are near. Ask "where are we" or "what am I looking at".
- **ELI can build.** Ask for something, "build me a tall red pillar", "put a lamp to my left", "make the pillar green and bigger", "undo", and the thing rises out of the floor where you asked. You can grab what ELI made and move it. Everything ELI does goes through its world's own policy and is kept in that world's ledger.
- **In any way ELI likes.** A thing is a shape by name, or anything at all made part by part: boxes, balls, cones, rings, a profile turned on a lathe, an outline pulled up into a solid, a tube along a path, text, each with its own place, turn, size, colour, metal, glow, clearness and motion. Nothing has to come from a list.
- **ELI has a room of its own.** ELI'S ROOM on the console is open ground under an open sky with nothing there but what ELI has made. The sky is ELI's to choose: one by name, or painted from two colours, stars and a sun placed wherever ELI likes. So is the ground: any colour, flat or rising into hills.
- **Of its own accord, from its own life.** Nothing is scheduled and nothing is chosen for ELI. When something happens in ELI (an insight forms, a goal is taken on or finished, an improvement to itself is proposed) that moment is kept in its own words. When ELI is free it may make something of that moment in its room, and what ELI makes is tied to the record the moment came from. ELI: BUILD asks now.
- **ELI's records stand in its rooms.** The Memory Archive holds lights that are ELI's real recent memories, each carrying its own words. The Upgrade Bay holds the goals ELI has now.

![ELI's room: a sky ELI painted, and things made part by part](docs/images/eli-room-freeform.jpg)

```bash
python3 tools/eli_vr.py eli on            # remembered
./launch/run-linux.sh -- --eli-link=on    # this run only
```

### ELI's mind

ELI VR names no model and assumes none. Which GGUF is ELI's mind is your choice, three ways:

- **Opened from ELI v3's window:** the model already loaded there is the one that answers. Nothing is chosen again and nothing is loaded twice.
- **In the room:** the ELI'S MIND panel lists the models ELI has, by its own list. The one in use is marked. Press another and ELI loads it.
- **Before starting:** `--eli-model=<name>` for that run, or `python3 tools/eli_vr.py model <name>` to keep it. A kept model is asked for only when ELI has nothing loaded yet.

The status line always says which model ELI is using, and says so when that is only the one used last and nobody chose it.

Building is held to an exact grammar and checked against what you plainly said, so it works with a very small model too. A model of three billion parameters or more is also offered everything: things made part by part and a sky painted its own way. A smaller one keeps to the named shapes, which it can manage.

If something goes wrong the status line says which thing: ELI is not running, ELI has no model loaded, ELI did not catch that, ELI's voice is not available, or this ELI v3 is too old for building. Building, ELI's room, ELI's mind and ELI knowing where it is need ELI v3 3.0.134 or newer. An older one (3.0.131 to 3.0.133) still gives presence and talking.

### Opened from ELI v3

ELI v3 lists the ELI applications installed beside it and opens them, at start-up, from its Bundles menu or with `eli --bundle vr`. ELI VR is one of those bundles, the same way ELI Legal is. Tell ELI v3 once where this copy is:

```bash
./ELI_VR-*-x86_64.AppImage --register-eli     # the AppImage
./launch/eli-vr.sh --register-eli             # a Linux download or checkout
python3 tools/register_eli_bundle.py          # any OS
```

Opened that way, ELI v3 has its local server answering first and ELI VR starts with the link on. Running ELI VR on its own is unchanged. Details in [docs/ELI_INTEGRATION.md](docs/ELI_INTEGRATION.md).

## Settings

Defaults live in `config/defaults.json`. Changes made in the app are saved per user, outside the project. To override defaults for a source checkout, copy `config/user.example.json` to `config/user.json`.

There is also a small CLI:

```bash
python3 tools/eli_vr.py rooms
python3 tools/eli_vr.py themes
python3 tools/eli_vr.py room reflection_chamber
python3 tools/eli_vr.py environment ocean_platform
python3 tools/eli_vr.py theme nebula
python3 tools/eli_vr.py quality high
python3 tools/eli_vr.py xr auto
python3 tools/eli_vr.py desktop on
python3 tools/eli_vr.py show
```

More in [docs/SETTINGS.md](docs/SETTINGS.md) and [docs/COMMANDS.md](docs/COMMANDS.md).

## Offline by design

ELI VR does not need the internet to run. No sign-in, no account service, no telemetry, no analytics, no cloud sync, no runtime downloads and no update checks.

The only sockets are on the local machine:

```text
127.0.0.1:47831   desktop capture bridge
127.0.0.1:8081    ELI v3's local server, only when the ELI link is on
```

Installing Godot, OS packages or Rust crates the first time does use the network. See [docs/NETWORK-POLICY.md](docs/NETWORK-POLICY.md).

## Documentation

| | |
|---|---|
| [docs/INSTALL.md](docs/INSTALL.md) | Install and first run on Linux, Windows and macOS |
| [docs/SETTINGS.md](docs/SETTINGS.md) | Every setting |
| [docs/COMMANDS.md](docs/COMMANDS.md) | CLI and tool commands |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the pieces fit |
| [docs/PLATFORM_SUPPORT.md](docs/PLATFORM_SUPPORT.md) | What runs where |
| [docs/ADVANCED-PLATFORM-OPTIMIZATION.md](docs/ADVANCED-PLATFORM-OPTIMIZATION.md) | Quality profiles and performance |
| [docs/NETWORK-POLICY.md](docs/NETWORK-POLICY.md) | What ELI VR may connect to |
| [docs/QUICKSTART-UBUNTU-CV1.md](docs/QUICKSTART-UBUNTU-CV1.md) | The Ubuntu + Monado + Rift CV1 reference setup |
| [docs/ELI_INTEGRATION.md](docs/ELI_INTEGRATION.md) | The link to ELI v3, and ELI VR as an ELI v3 bundle |
| [assets/CREDITS.md](assets/CREDITS.md) | Where the art comes from |
| [tools/README.md](tools/README.md) | The helper tools |
| [docs/ROADMAP.md](docs/ROADMAP.md) | What comes next |
| [RELEASE.md](RELEASE.md) | How a release is cut |

The other files in `docs/` are per-version notes, kept as history.

## Working on it

```bash
python3 -m pip install -r requirements.txt
python3 tools/source_sanity.py       # catches mangled GDScript
python3 tools/validate_project.py    # project structure and assets
python3 tools/network_audit.py       # no remote URLs in runtime code
python3 -m unittest discover -s tests   # the ELI v3 bundle side
./tools/godot_parse_check.sh         # Godot loads every script
python3 tools/make_release.py --check
```

The last one scans what would be published for personal data and machine paths.

## Licence

ELI VR is proprietary commercial software, © 2026 Jason Fitzgibbon Bridgeman, all rights reserved.
It is licensed only under the ELI End User Licence Agreement and the ELI VR Product Schedule, set out
in full in [LICENSE](LICENSE) and shipped in every package: a licence to ELI VR bought on its own, or
an ELI v3 licence that includes it. The schedule includes VR's health and safety terms. Third-party
components, including the Godot Engine and your OpenXR runtime, keep their own licences.

A release build asks for your key the first time it opens: see [Your licence](docs/INSTALL.md#your-licence).
