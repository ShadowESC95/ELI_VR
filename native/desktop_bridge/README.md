# ELI VR desktop bridge

This optional helper supplies the live desktop surface to the standalone Godot app.

Protocol, over TCP on `127.0.0.1:47831` only:

1. ELI VR's first line is `{"kind": "hello", "key": "..."}` with the key this helper made when it started (`src/key.rs`), kept where only the same account can read it. A connection without it is closed.
2. The helper sends the screen as messages of lossless tiles (`src/screen.rs`): `ELIT`, the screen's width and height, the number of tiles, then each tile's x, y, width and height followed by its RGBA rows; every number a big-endian u32. A client that has just joined gets every tile, then only the tiles that changed, and nothing while nothing does.
3. ELI VR sends pointer lines back (`src/pointer.rs`): `{"kind": "move", "x", "y"}` with x and y from 0 to 1 across and down the screen, `{"kind": "button", "button": "left"|"right"|"middle", "down"}`, `{"kind": "scroll", "steps"}` (up is negative). They move and click the desktop's own pointer through `enigo`: XTest on X11, Quartz events on macOS (which asks for Accessibility permission the first time), `SendInput` on Windows (the main display only). `--no-input` shows the screen and never touches the pointer.

The Wayland helper (`native/desktop_portal_bridge/eli_portal_bridge.py`) speaks the same protocol through the desktop's portal.

The bridge uses `xcap 0.9.8`, which provides a common monitor-capture API on Windows, macOS and Linux.

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
./target/release/eli-vr-desktop-bridge --fps 15 --width 1600
```

Select monitor 1:

```bash
./target/release/eli-vr-desktop-bridge --monitor 1
```

## Network boundary

This helper is deliberately loopback-only.

It refuses to bind to non-loopback addresses. Desktop frames therefore remain on the local machine in this package.
