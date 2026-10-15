# ELI VR desktop bridge

This optional helper supplies the live desktop surface to the standalone Godot app.

Protocol:

1. TCP localhost, default `127.0.0.1:47831`.
2. Each frame is `u32 big-endian JPEG byte length`.
3. Followed by that many JPEG bytes.
4. Godot decodes the JPEG and updates the desktop material.

The bridge uses `xcap 0.9.8`, which provides a common monitor-capture API on Windows, macOS and Linux. Linux/Wayland capture behavior is compositor/portal dependent, so test the exact distro/session.

This alpha deliberately uses compressed frames over localhost because it is simple and portable. The production path should add zero-copy GPU/shared-texture adapters per OS while preserving this protocol as a fallback.

## Licence check

The same program decides whether a copy of ELI VR may run, since Godot can't verify Ed25519 signatures. `eli-vr-desktop-bridge licence` reads the keys in the folder every ELI product shares and checks them offline against ELI's public key (`eli.pub`), by the rules the ELI SDK sets out. `tests/vectors.json` is the SDK's conformance set, and `cargo test` reads every key in it the way ELI does.

## Build

```bash
cargo build --release
```

Binary:

```text
target/release/eli-vr-desktop-bridge
```

## Run

```bash
./target/release/eli-vr-desktop-bridge --fps 15 --width 1600 --quality 72
```

Select monitor 1:

```bash
./target/release/eli-vr-desktop-bridge --monitor 1
```

## Network boundary

This helper is deliberately loopback-only.

It refuses to bind to non-loopback addresses. Desktop frames therefore remain on the local machine in this package.
