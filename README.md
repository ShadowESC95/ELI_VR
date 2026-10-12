# ELI VR

A spatial workspace you can stand inside: fifteen places from an orbiting station to a misty forest, a movable live desktop screen, and a control console, built on Godot 4.7 and OpenXR. It runs in a headset, and it runs on a plain monitor when there isn't one.

**Version 0.8.0** · Linux · Windows · macOS

![The Core Room: an observation deck in orbit, Earth below and the Milky Way overhead](docs/images/core-room.jpg)

ELI VR is part of the ELI family but does not need ELI to run. With ELI v3 running beside it, ELI is present in the rooms and you can talk to him, and ELI v3 can open ELI VR itself as one of its bundles. There is no account, no telemetry and nothing leaves the machine.

## Status

This is an early build. Be clear-eyed about what has and has not been tried:

| | State |
|---|---|
| Linux, Wayland, Monado, Rift CV1 with Touch | The reference setup. Tested in the headset. |
| Flat (no headset) mode on Linux | Tested. |
| Windows and macOS builds | Built by CI. Not yet run on real hardware. |
| Valve Index, HTC Vive, Windows Mixed Reality, generic OpenXR controllers | Bound, not yet tested on hardware. |
| The link to ELI v3 (presence, talking) | Tested against ELI v3's own routes without a headset. Not yet used in one. |
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

- ELI appears as a body of light in whichever room his own world has him in, and the status line says where he is when it is not yours.
- Hold **A** / **X** on a controller, or **T** on the keyboard, to talk to him. He answers in his own voice from where he stands.

```bash
python3 tools/eli_vr.py eli on            # remembered
./launch/run-linux.sh -- --eli-link=on    # this run only
```

ELI VR names no model: whichever one ELI v3 has loaded answers.

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
