# Commands

## Launch

Linux:

```bash
./launch/run-linux.sh
./launch/run-linux.sh xr
./launch/run-linux.sh flat
./launch/run-linux.sh compat
```

Windows PowerShell:

```powershell
.\launch\run-windows.ps1
.\launch\run-windows.ps1 -Mode xr
.\launch\run-windows.ps1 -Mode flat
```

macOS:

```bash
./launch/run-macos.command
./launch/run-macos.command --xr-mode on
```

## CLI

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

python3 tools/eli_vr.py set desktop.distance_m 4.5
python3 tools/eli_vr.py set desktop.width_m 6.5
python3 tools/eli_vr.py set xr.move_speed 2.5
python3 tools/eli_vr.py set xr.snap_turn_degrees 45
```

## Native desktop bridge

Build:

```bash
cd native/desktop_bridge
cargo build --release
```

Run:

```bash
./target/release/eli-vr-desktop-bridge
./target/release/eli-vr-desktop-bridge --fps 20 --width 1920 --quality 78
./target/release/eli-vr-desktop-bridge --monitor 1
```

Linux helper:

```bash
./native/desktop_bridge/build-linux.sh
./launch/start-desktop-bridge-linux.sh
```

## Export

With Godot export templates installed:

```bash
godot --headless --path . --export-release Linux
godot --headless --path . --export-release "Windows Desktop"
godot --headless --path . --export-release macOS
```

## Validation

```bash
python3 tools/validate_project.py
```

## Hardware/runtime doctor

```bash
python3 tools/doctor.py
```

## Optional high-fidelity environment assets

```bash
```


## Local room packs

```bash
python3 tools/install_room_pack.py /path/to/room-pack.zip
```

ELI VR does not fetch packs from the internet.

## Network audit

```bash
python3 tools/network_audit.py
```

This scans runtime source for remote URLs and writes:

```text
build/network-audit.json
```


## Frontier XR shortcuts

- Left stick: move.
- Left stick click: boost.
- Right stick X: snap turn.
- Right stick Y: vertical movement in free-flight environments.
- Trigger: select spatial UI.
- Grip: grab movable world objects.
- Grip + same-hand stick Y: pull/push grabbed object.
- Grip + same-hand stick X: rotate grabbed object.
- Left Menu: wrist shortcut deck.
- B/Y: large spatial console.

Deep Space, Underwater, Digital Matrix and Anomaly use automatic free-flight.


## XR calibration

If the virtual hands/pointers are above, below or offset from the real Touch
controllers:

```text
Hold BOTH GRIPS + BOTH TRIGGERS for 1 second
```

while holding both controllers together naturally in front of your chest.

Other access:

```text
Left wrist -> CALIBRATE
F6          -> toggle calibration widget
F7          -> calibrate hands immediately
```


## Universal Worlds controls

Free-flight is enabled in every environment by default:

```text
Left stick         move where you look
Left stick click   boost
Right stick Y      move vertically
Right stick X      snap turn
```

Spatial system controls:

```text
DESKTOP SCREEN     show/hide the XR desktop surface
STATUS HUD         show/hide the XR status HUD
```

The desktop surface can exist without a live capture provider. Its status panel
shows the platform capture backend expected on the current OS.


## Movable spatial workspace (0.5.0)

Point at the body/background of ROOMS, ENVIRONMENTS, VISUAL/SYSTEM or the
DESKTOP screen and hold grip:

```text
Grip + move hand      move panel/screen
Grip + stick Y        push/pull distance
Grip + stick X        rotate around vertical axis
```

Trigger remains reserved for panel buttons.
