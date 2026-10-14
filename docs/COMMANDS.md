# Commands

From the ELI VR folder. Release folders have the launchers and `tools/register_eli_bundle.py`; everything else here is for a checkout.

## Start

Linux, the whole session (desktop helper, app, clean stop of the VR runtime on exit):

```bash
./launch/eli-vr.sh                 # system OpenXR runtime, flat if there is none
./launch/eli-vr.sh --monado        # start native Monado first
./launch/eli-vr.sh --eli           # with the link to ELI v3
./launch/eli-vr.sh --flat          # no headset   (--xr forces one, --compat is OpenGL)
./launch/eli-vr.sh --no-desktop    # no desktop helper
```

The AppImage takes the same options. Ones you always want go on one line in `~/.config/eli-vr/launch.conf`.

Through Godot, any OS:

```bash
./launch/run-linux.sh              # auto | xr | flat | compat
./launch/run-macos.command
```

```powershell
.\launch\run-windows.ps1 -Mode flat
.\launch\run-windows.ps1 -Eli
```

Anything after `--` goes to the app and applies to that run only:

| Option | Meaning |
|---|---|
| `--eli-room=<id>` | Start in this room |
| `--eli-environment=<id>` | Use this place for it |
| `--eli-theme=<id>` | Theme |
| `--eli-quality=low\|medium\|high\|ultra` | Quality profile |
| `--eli-xr=auto\|on\|off` | Headset or not |
| `--eli-desktop=on\|off` | The desktop screen |
| `--eli-link=on\|off` | The link to ELI v3 |
| `--eli-endpoint=<url>` | ELI v3's local server, if not the default. Loopback only |
| `--eli-model=<name>` | Ask ELI to load one of its models, for this run. Names are the ones on the ELI'S MIND panel |
| `--eli-say="..."` | Send a sentence to ELI as if spoken, once the link is up. Several separated by `\|`; `@build` and `@undo` do what those buttons do, `@wait` waits. For trying the link without a microphone |

## Settings

```bash
python3 tools/eli_vr.py show
python3 tools/eli_vr.py reset
python3 tools/eli_vr.py rooms
python3 tools/eli_vr.py environments
python3 tools/eli_vr.py themes

python3 tools/eli_vr.py room workshop
python3 tools/eli_vr.py environment mountain_observatory
python3 tools/eli_vr.py environment default
python3 tools/eli_vr.py theme solar
python3 tools/eli_vr.py quality high
python3 tools/eli_vr.py xr auto
python3 tools/eli_vr.py desktop on
python3 tools/eli_vr.py eli on
python3 tools/eli_vr.py model Some-Model-Q4.gguf   # asked for when ELI has nothing loaded; "any" clears it

python3 tools/eli_vr.py set desktop.distance_m 4.5
python3 tools/eli_vr.py set xr.move_speed 2.5
```

Every key is in [SETTINGS.md](SETTINGS.md).

## ELI v3

```bash
./launch/eli-vr.sh --register-eli               # put this copy on ELI v3's list of bundles
./launch/eli-vr.sh --unregister-eli
python3 tools/register_eli_bundle.py            # the same, any OS
python3 tools/register_eli_bundle.py --show     # print it, write nothing
python3 tools/register_eli_bundle.py --remove
python3 tools/register_eli_bundle.py --into DIR # ELI v3's bundles folder, if not the usual one
```

With the Python package installed (`pip install -e .`):

```bash
eli-vr bundle show | register | unregister
eli-vr where                                    # which copy would be started, and how
```

In ELI v3: `eli --bundles` lists what it found, `eli --bundle vr` opens ELI VR. See [ELI_INTEGRATION.md](ELI_INTEGRATION.md).

## Desktop helper

```bash
./launch/start-desktop-bridge-linux.sh
./launch/start-desktop-bridge-macos.command
```

```powershell
.\launch\start-desktop-bridge-windows.ps1
```

Building the native one:

```bash
./native/desktop_bridge/build-linux.sh          # or build-macos.sh, build-windows.ps1
./native/desktop_bridge/target/release/eli-vr-desktop-bridge --fps 20 --width 1920 --quality 78 --monitor 1
```

## A picture of a room without a headset

```bash
godot --path . --xr-mode off -- --eli-xr=off --eli-environment=forest_sanctuary \
  --eli-shot=/tmp/forest.png --eli-shot-view="0,1.7,2.8,20,8" --eli-shot-clean
```

`--eli-shot-view` is `x,y,z,yaw,pitch`, several separated by `;`. `--eli-shot-clean` leaves out the panels, portals and desktop screen. It saves the pictures and quits.

## Checks

```bash
python3 tools/source_sanity.py
python3 tools/validate_project.py
python3 tools/network_audit.py
python3 -m unittest discover -s tests
./tools/godot_parse_check.sh
python3 tools/make_release.py --check
python3 tools/doctor.py                         # what this machine has: GPU, OpenXR runtime, capture
```

## Export

With Godot's export templates installed:

```bash
godot --headless --path . --xr-mode off --export-release "Linux" build/linux/ELI-VR.x86_64
godot --headless --path . --xr-mode off --export-release "Windows Desktop" build/windows/ELI-VR.exe
godot --headless --path . --xr-mode off --export-release "macOS" build/macos/ELI-VR.zip
```

The release workflow does this, builds the helper on each OS and packages the lot. See [RELEASE.md](../RELEASE.md).

## Room packs

```bash
python3 tools/install_room_pack.py /path/to/room-pack.zip
```

From a local file only. ELI VR does not fetch packs.

## In the headset

```text
Left stick           move where you look      (click: boost)
Right stick X        snap turn
Right stick Y        up and down
Trigger              press buttons, enter portals
Grip                 grab a panel, the screen or an object
Grip + stick Y       push it away or pull it in
Grip + stick X       turn it
B / Y                show or hide the spatial console
Menu (left)          wrist menu
Hold A / X           talk to ELI, with the link on
Grip on ELI's thing  move what ELI built; ELI is told where you put it
```

Hands not where the controllers are: hold both grips and both triggers for a second with the controllers together in front of your chest, or use CALIBRATE on the wrist menu. `F6` shows the calibration widget, `F7` calibrates at once.
