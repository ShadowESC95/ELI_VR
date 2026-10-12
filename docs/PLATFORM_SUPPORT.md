# What runs where

The same project on every system. What differs is the headset runtime and how the desktop is captured. What has actually been tried is in the [README](../README.md#status).

| | Linux | Windows | macOS |
|---|---|---|---|
| Release build | AppImage, and a folder | Folder | App, Apple Silicon and Intel |
| Flat window | yes | yes | yes |
| Headset | Any OpenXR runtime: Monado, SteamVR, WiVRn | Any OpenXR runtime: the headset maker's, SteamVR | No common OpenXR runtime. Flat only |
| Desktop screen | Wayland: portal + PipeWire helper. X11: native helper | Native helper | Native helper, needs Screen Recording permission |
| VR runtime stopped on exit | yes, through the launcher | no, the vendor runtime is yours to close | not applicable |
| Opened from ELI v3 | yes | yes | yes |

Builds are not code-signed, so Windows and macOS warn on first launch. [INSTALL.md](INSTALL.md) has the way round it for each.

## Headsets

Any PC headset with an OpenXR runtime. Controller layouts for Oculus Touch, Valve Index, HTC Vive and Windows Mixed Reality are bound, with the OpenXR simple profile as the fallback. Touch is the one tested on hardware.

Standalone headsets (Quest, Pico and the like) work through a PC link: Link, Air Link, Virtual Desktop, ALVR, WiVRn. There is no native app for them yet.

## Scaling to the machine

Four quality profiles, the same rooms in each. See [ADVANCED-PLATFORM-OPTIMIZATION.md](ADVANCED-PLATFORM-OPTIMIZATION.md).
