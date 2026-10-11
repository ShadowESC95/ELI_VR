# Ubuntu + native Monado + Rift CV1 reference quickstart

This file is a **reference adapter only**. ELI VR itself remains cross-platform.

## 1. Install Godot 4.7.2

Make the Godot executable available as `godot`, `godot4`, or set:

```bash
export GODOT_BIN=/full/path/to/Godot_v4.7.2-stable_linux.x86_64
```

## 2. Optional: build live desktop bridge

Install native headers:

```bash
./launch/setup-ubuntu-dev-deps.sh
```

Install Rust through rustup if required, then:

```bash
./native/desktop_bridge/build-linux.sh
```

## 3. Start native CV1 + ELI VR

```bash
./launch/run-linux-monado-cv1-reference.sh
```

This launcher:

- uses the Monado stdin-FIFO workaround;
- forces Wayland direct mode;
- finds a Monado OpenXR runtime JSON;
- optionally starts the desktop bridge if it was built;
- starts Godot directly with `--xr-mode on`;
- does **not** start WayVR;
- does **not** start SteamVR.

## Flat-mode sanity check

Before involving the headset:

```bash
./launch/run-linux.sh flat
```

You should be able to walk through every room with mouse + keyboard and test all settings.
