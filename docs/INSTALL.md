# Installing ELI VR

Guides for Linux, Windows and macOS. Pick your OS, then pick one of two routes:

- **Release build**: download, unpack, run. Nothing else to install.
- **From source**: clone the repo and run it through Godot. Use this to change things.

A headset is optional everywhere. Without one, ELI VR opens as a normal 3D window.

- [What you need](#what-you-need)
- [Linux](#linux)
- [Windows](#windows)
- [macOS](#macos)
- [Headsets and OpenXR runtimes](#headsets-and-openxr-runtimes)
- [Live desktop screen](#live-desktop-screen)
- [With ELI v3](#with-eli-v3)
- [Where your settings live](#where-your-settings-live)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)

## What you need

| | Minimum |
|---|---|
| OS | Linux x86_64, Windows 10/11 64-bit, or macOS 11+ (Apple Silicon or Intel) |
| GPU | Anything with Vulkan 1.0 or newer. Older cards can use the OpenGL fallback. |
| RAM | 8 GB. 16 GB is comfortable. |
| Disk | About 300 MB |
| Headset | Optional. Any PC headset with an OpenXR runtime. |
| Network | Only to download. Nothing at runtime. |

Running from source also needs **Godot 4.7.2** (standard build, not .NET) from <https://godotengine.org/download>.

What has actually been tested is listed in the [README](../README.md#status). Linux with a Rift CV1 is the reference setup; Windows and macOS builds come out of CI and have not been run on real machines yet.

---

## Linux

### Release build

1. Download `ELI_VR-<version>-linux-x86_64.tar.gz` from the [Releases](https://github.com/ShadowESC95/ELI_VR/releases) page.
2. Unpack and run:

   ```bash
   tar -xzf ELI_VR-*-linux-x86_64.tar.gz
   cd ELI_VR-*-linux-x86_64
   ./ELI-VR.x86_64
   ```

3. To force a mode:

   ```bash
   ./ELI-VR.x86_64 --xr-mode on      # headset
   ./ELI-VR.x86_64 --xr-mode off     # flat window
   ./ELI-VR.x86_64 --rendering-method gl_compatibility   # OpenGL fallback
   ```

The bundled desktop helper is built on Ubuntu 24.04 and needs glibc 2.39 or newer (Ubuntu 24.04, Fedora 40, Debian 13 and later). On older systems, build the helper from source.

If it will not start, check the graphics driver first:

```bash
vulkaninfo --summary     # from the vulkan-tools package
```

### From source

1. Install Godot 4.7.2. Download the Linux x86_64 zip, unpack it, then either put it on your `PATH` as `godot` or export its location:

   ```bash
   export GODOT_BIN="$HOME/Apps/Godot_v4.7.2-stable_linux.x86_64"
   ```

2. Make sure a Vulkan driver is installed:

   | Distro | AMD / Intel | NVIDIA |
   |---|---|---|
   | Ubuntu, Debian | `sudo apt install mesa-vulkan-drivers` | the proprietary driver from "Additional Drivers" |
   | Fedora | `sudo dnf install mesa-vulkan-drivers` | `akmod-nvidia` from RPM Fusion |
   | Arch | `sudo pacman -S vulkan-radeon` or `vulkan-intel` | `sudo pacman -S nvidia-utils` |

3. Clone and run:

   ```bash
   git clone https://github.com/ShadowESC95/ELI_VR.git
   cd ELI_VR
   ./launch/run-linux.sh          # auto: headset if there is one, flat if not
   ./launch/run-linux.sh flat
   ./launch/run-linux.sh xr
   ./launch/run-linux.sh compat   # OpenGL fallback
   ```

   The first start takes a minute while Godot imports the textures.

Only the Ubuntu/Debian commands in this guide have been run for real. The Fedora and Arch lines are the matching packages.

---

## Windows

### Release build

1. Download `ELI_VR-<version>-windows-x64.zip` from the [Releases](https://github.com/ShadowESC95/ELI_VR/releases) page.
2. Right-click the zip, **Extract All**, and open the folder.
3. Double-click `ELI-VR.exe`.

   The build is not code-signed, so SmartScreen may stop it the first time. Choose **More info**, then **Run anyway**.

4. To force a mode, run it from a terminal in that folder:

   ```powershell
   .\ELI-VR.exe --xr-mode on
   .\ELI-VR.exe --xr-mode off
   .\ELI-VR.exe --rendering-method gl_compatibility
   ```

Keep `ELI-VR.exe` and `ELI-VR.pck` together.

### From source

1. Install Godot 4.7.2. Download the Windows 64-bit zip and unpack it somewhere stable, for example `C:\Tools\Godot`.
2. Install [Git for Windows](https://git-scm.com/download/win).
3. In PowerShell:

   ```powershell
   git clone https://github.com/ShadowESC95/ELI_VR.git
   cd ELI_VR
   $env:GODOT_BIN = "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
   .\launch\run-windows.ps1            # auto
   .\launch\run-windows.ps1 flat
   .\launch\run-windows.ps1 xr
   .\launch\run-windows.ps1 compat
   ```

   If PowerShell refuses to run the script, allow scripts for this window only and try again:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   ```

4. Update your GPU driver if the window stays black. Vulkan comes with the vendor driver, not with Windows.

---

## macOS

VR is not available on macOS because there is no common OpenXR runtime for it. ELI VR runs there in flat mode.

### Release build

1. Download `ELI_VR-<version>-macos-universal.zip` from the [Releases](https://github.com/ShadowESC95/ELI_VR/releases) page. It runs on Apple Silicon and Intel.
2. Unzip it and move the folder where you want it.
3. The app is not notarised, so the first launch needs one extra step. Either right-click the app, choose **Open**, then **Open** again, or clear the quarantine flag in Terminal:

   ```bash
   xattr -dr com.apple.quarantine "ELI VR.app"
   ```

4. After that it opens like any other app.

### From source

1. Install Godot 4.7.2 and drag `Godot.app` into `/Applications`.
2. Install the command line tools if you do not have git yet:

   ```bash
   xcode-select --install
   ```

3. Clone and run:

   ```bash
   git clone https://github.com/ShadowESC95/ELI_VR.git
   cd ELI_VR
   ./launch/run-macos.command          # auto
   ./launch/run-macos.command flat
   ./launch/run-macos.command compat
   ```

   If Godot is somewhere else, set `GODOT_BIN` to the executable inside the app bundle, for example `/path/to/Godot.app/Contents/MacOS/Godot`.

---

## Headsets and OpenXR runtimes

ELI VR talks to whatever OpenXR runtime is active on the machine. Set that up first, check the headset works in the vendor's own software, then start ELI VR.

### Windows

| Headset | Runtime | Make it the active OpenXR runtime |
|---|---|---|
| Valve Index, HTC Vive, most others | SteamVR | SteamVR → Settings → OpenXR → **Set SteamVR as OpenXR runtime** |
| Quest over Link or Air Link, Rift | Meta Quest Link | Meta Quest Link app → Settings → General → **Set Meta Quest Link as active** |
| Windows Mixed Reality | Mixed Reality Portal | Install **OpenXR Tools for Windows Mixed Reality** from the Microsoft Store and set it active |
| Quest or Pico over Virtual Desktop | VDXR | Virtual Desktop Streamer → Options → OpenXR Runtime → **VDXR** |

### Linux

| Runtime | How ELI VR finds it |
|---|---|
| SteamVR | SteamVR → Settings → OpenXR → set as runtime |
| Monado | Install it, then make it active or point at it for one run (below) |
| WiVRn, ALVR (standalone headsets over Wi-Fi) | Follow their setup; both register themselves as the OpenXR runtime |

To use a specific runtime for a single run without changing the system default:

```bash
export XR_RUNTIME_JSON=/usr/share/openxr/1/openxr_monado.json
./launch/run-linux.sh xr
```

Use the path your install actually has; `/usr/local/share/openxr/1/` is common for builds from source.

For a Rift CV1 on Wayland with a native Monado build there is a dedicated launcher that also starts Monado and the desktop capture: `./launch/run-linux-monado-cv1-reference.sh`. See [QUICKSTART-UBUNTU-CV1.md](QUICKSTART-UBUNTU-CV1.md).

### Standalone headsets

Quest, Pico and similar headsets work as PC headsets through Link, Air Link, Steam Link, Virtual Desktop, ALVR or WiVRn. There is no app to install on the headset itself yet.

### Controllers

| Controller | State |
|---|---|
| Oculus / Meta Touch | Tested |
| Valve Index, HTC Vive wands, Windows Mixed Reality | Mapped, not yet tested on hardware |
| Others | Trigger and menu only, through the OpenXR simple profile |

---

## Live desktop screen

The screen in each room shows your desktop through a small helper that runs beside ELI VR. Start the helper first, then ELI VR. If the screen says it is waiting for the capture adapter, the helper is not running.

Release builds ship the helper inside the same folder, at the same paths used below. From source you build it once.

### Linux on Wayland

Uses the desktop's own screen-sharing portal, so the desktop asks which monitor to share the first time and remembers the answer.

1. Install the pieces it needs:

   | Distro | Command |
   |---|---|
   | Ubuntu, Debian | `./tools/install-linux-wayland-capture-deps.sh` |
   | Fedora | `sudo dnf install python3-dbus python3-gobject gstreamer1-plugins-base pipewire-gstreamer` |
   | Arch | `sudo pacman -S python-dbus python-gobject gst-plugins-base gst-plugin-pipewire` |

2. Start it:

   ```bash
   ./launch/start-desktop-bridge-linux.sh
   ```

3. Pick the monitor when the desktop asks, then start ELI VR.

Check it with `./tools/check-linux-wayland-capture.sh`.

### Linux on X11

1. From source only, build the native helper once. It needs Rust from <https://rustup.rs> and a few headers:

   ```bash
   ./launch/setup-ubuntu-dev-deps.sh      # Ubuntu, Debian
   ./native/desktop_bridge/build-linux.sh
   ```

2. Start it:

   ```bash
   ./launch/start-desktop-bridge-linux.sh
   ```

### Windows

1. From source only, build the helper once. Install Rust from <https://rustup.rs>; when it asks, let it install the Visual Studio C++ build tools. Then:

   ```powershell
   .\native\desktop_bridge\build-windows.ps1
   ```

2. Start it:

   ```powershell
   .\launch\start-desktop-bridge-windows.ps1
   ```

### macOS

1. From source only, build the helper once:

   ```bash
   xcode-select --install
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ./native/desktop_bridge/build-macos.sh
   ```

2. Start it:

   ```bash
   ./launch/start-desktop-bridge-macos.command
   ```

3. macOS asks for **Screen Recording** permission the first time. Allow it under System Settings → Privacy & Security → Screen & System Audio Recording, then start the helper again.

### Tuning

All three helpers read the same optional variables:

| Variable | Default | Meaning |
|---|---|---|
| `ELI_VR_CAPTURE_WIDTH` | 1280 (Wayland), 1600 (others) | Width of the frames sent to the screen |
| `ELI_VR_CAPTURE_FPS` | 18 (Wayland), 15 (others) | Frames per second |
| `ELI_VR_CAPTURE_QUALITY` | 72 | JPEG quality, native helper only |

Frames only ever travel over `127.0.0.1:47831`. The helper refuses to listen on anything else.

---

## With ELI v3

Optional. ELI VR runs on its own; with ELI v3 on the same machine, ELI is present in the rooms and you can talk to him.

1. Start ELI v3's local server (in ELI v3: `./scripts/eli_serve.sh`, or the server switch in its window).
2. Start ELI VR with the link on:

   | | From source | Release build |
   |---|---|---|
   | Linux | `./launch/run-linux.sh -- --eli-link=on` | `./ELI-VR.x86_64 -- --eli-link=on` |
   | Windows | `.\launch\run-windows.ps1 -Eli` | `.\ELI-VR.exe -- --eli-link=on` |
   | macOS | `./launch/run-macos.command -- --eli-link=on` | `"ELI VR.app/Contents/MacOS/ELI VR" -- --eli-link=on` |

3. Hold **A** / **X** on a controller, or **T** on the keyboard, to talk. Your OS may ask for microphone permission the first time.

To have ELI v3 list ELI VR among its bundles and start it for you, run `python3 tools/register_eli_bundle.py` once. More in [ELI_INTEGRATION.md](ELI_INTEGRATION.md).

## Where your settings live

Changes made inside ELI VR are saved per user:

| OS | Folder |
|---|---|
| Linux | `~/.local/share/godot/app_userdata/ELI VR/` |
| Windows | `%APPDATA%\Godot\app_userdata\ELI VR\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/ELI VR/` |

`eli_vr/settings.json` in that folder holds your settings. Delete it to go back to defaults. On Linux, the CV1 launcher and the Wayland helper also keep logs and the remembered screen choice in `~/.local/state/eli-vr-standalone/`.

## Uninstall

Delete the ELI VR folder, then the settings folder above. Nothing else is installed: no services, no registry entries, no system files.

## Troubleshooting

**The window is black or the app closes at once.** Update the GPU driver, then try the OpenGL fallback (`compat` from source, or `--rendering-method gl_compatibility` on a release build).

**It opens flat even though the headset is on.** No OpenXR runtime is active, or the wrong one is. Set the runtime as described [above](#headsets-and-openxr-runtimes) and start the vendor software before ELI VR. Forcing `xr` mode prints the reason in the terminal.

**Linux picks SteamVR when you wanted Monado, or the other way round.** Set `XR_RUNTIME_JSON` for that run.

**No controllers, or the rays are missing.** Wake both controllers before starting. If the buttons work but movement does not, the controller is on the simple profile; see [Controllers](#controllers).

**The desktop screen says it is waiting.** Start the capture helper. On Wayland, check that the share prompt was answered.

**Wayland never asks which screen to share.** Remove `~/.local/state/eli-vr-standalone/portal-restore-token` and start the helper again.

**Windows says the script cannot be loaded.** Run `Set-ExecutionPolicy -Scope Process Bypass` in that PowerShell window.

**macOS says the app is damaged or cannot be opened.** Clear the quarantine flag as shown in the [macOS](#macos) section.

**Something else.** Run `python3 tools/doctor.py` from a source checkout and include its output when you open an issue. It leaves your home folder name out of the report.
