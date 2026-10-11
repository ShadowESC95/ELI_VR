# ELI VR 0.6.3 — first public build

The first release with downloadable builds for Linux, Windows and macOS.

Tested on Linux with Monado and a Rift CV1. The Windows and macOS builds come from CI and have not been run on real hardware yet, and only Oculus Touch controllers have been tried in the headset. See the status table in the README.

## The desktop screen works

It could not show a frame before. Three separate faults:

- the app never polled its capture socket, so it stayed on "connecting";
- it waited for a whole frame to sit in the socket buffer, which a frame is far too big to do;
- on current GStreamer the Wayland helper crashed on its first frame, and it scaled the width only, so a 4K monitor came through as a stretched 1280x2160 picture.

All three are fixed. On the reference machine the Wayland helper now delivers 1280x720 at 18 frames a second into the app's own receiver. `launch/start-desktop-bridge-linux.sh` starts the right helper for Wayland or X11.

## Runs on more machines

- Removed a stray `\` from the first line of 19 shipped files. It hid the Linux export preset from Godot and left three launchers and two tools without a valid first line.
- Controller bindings for Valve Index, HTC Vive, Windows Mixed Reality and the OpenXR generic controller, next to Oculus Touch.
- No error box at start when there is no headset; it goes straight to the flat window.
- Launchers take the same `auto`, `xr`, `flat` and `compat` modes on all three systems, and all honour `GODOT_BIN`.
- A desktop helper launcher for macOS.
- `rooms`, `environments` and `themes` in the CLI list everything instead of the first entry.

## Nothing personal ships

- Machine-specific paths are gone from the launchers and docs.
- `tools/make_release.py` builds the source package and refuses if it finds a home folder path, a user or host name, an e-mail address, a Steam ID, a device serial or a compiled binary.
- `tools/doctor.py` leaves the home folder name out of its report.

## Install and release

- [docs/INSTALL.md](https://github.com/ShadowESC95/ELI_VR/blob/main/docs/INSTALL.md): full guides for Linux, Windows and macOS.
- `requirements.txt`, `requirements-linux-capture.txt` and `pyproject.toml` for the Python helper tools.
- A release workflow that builds all three systems from a tag. See [RELEASE.md](https://github.com/ShadowESC95/ELI_VR/blob/main/RELEASE.md).

## Known gaps

- No native app for Quest, Pico or other standalone headsets. Use a PC link.
- No VR on macOS.
- The desktop screen is view-only.
- Builds are not code-signed.
