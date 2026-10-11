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

Two optional local services reserve loopback-only IPC:

```text
127.0.0.1:47831   local desktop capture bridge
127.0.0.1:47832   future local ELI bridge (disabled)
```

ELI VR's standalone `NetworkPolicy` defaults to:

```text
LOCAL_ONLY
```

The desktop client refuses a non-loopback host.

The Rust desktop bridge refuses to bind to a non-loopback IP.

The future ELI bridge refuses a non-loopback WebSocket URL.

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

## Future ELI v3 integration

When ELI VR becomes part of ELI v3, this local policy is intended to sit underneath ELI's stronger socket-level network toggle.

If ELI's network toggle is OFF, that higher-level control should remain authoritative.
