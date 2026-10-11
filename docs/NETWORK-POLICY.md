# ELI VR network policy

ELI VR 0.2.1 is **offline-capable by design**.

## Runtime guarantees of this package

The application does not require:

- an account;
- sign-in;
- cloud storage;
- telemetry;
- analytics;
- an update server;
- an asset CDN;
- a third-party API;
- an internet connection.

Normal world rendering, OpenXR operation, settings, room switching, themes, audio and local assets are offline.

## Loopback IPC

Two optional local services use loopback-only IPC:

```text
127.0.0.1:47831   local desktop capture bridge
127.0.0.1:8081    ELI v3's local server, only when the ELI link is switched on
```

ELI VR's standalone `NetworkPolicy` defaults to:

```text
LOCAL_ONLY
```

The desktop client refuses a non-loopback host.

The Rust desktop bridge refuses to bind to a non-loopback IP.

The ELI link is off by default and refuses any address that is not loopback. With it on, the microphone is recorded only while the talk button is held, and the clip goes to ELI v3 on this machine and nowhere else.

## First-time dependency downloads

Development/setup can require network access once, for example:

- installing Godot;
- `apt install` / operating-system packages;
- installing Rust/rustup;
- `cargo build` downloading Rust crates;
- installing Godot export templates.

Those actions are outside the normal ELI VR runtime.

Once dependencies and desired local room packs are installed, ELI VR is designed to run offline.

## Room packs

ELI VR does not download third-party room packs.

Users can install an already-downloaded/local pack with:

```bash
python3 tools/install_room_pack.py /path/to/room-pack.zip
```

This installer accepts local `.zip` files only.

## ELI v3

When ELI VR runs beside ELI v3, this local policy sits underneath ELI's stronger socket-level network toggle.

If ELI's network toggle is OFF, that higher-level control should remain authoritative.
