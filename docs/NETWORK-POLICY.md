# ELI VR network policy

ELI VR is **offline by design**.

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

## Licensing is offline too

ELI VR never contacts anything about its licence. A key is checked on this computer against ELI's
public key. A licence covers a number of computers, each with its own key: the buyer sends the
seller the computer's activation code (shown in the control dock's **Licence…**, a one-way code made
from the operating system's install id), and enters the key they get back. Withdrawn licences are
listed inside each release. The seven-day trial is kept on this computer.

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

The desktop client refuses a non-loopback host; which hosts count as this machine is one list, `NetworkPolicy.is_loopback_host` in `scripts/core/network_policy.gd`.

The Rust desktop bridge refuses to bind to a non-loopback IP.

The ELI link is on by itself only where ELI v3 is installed on the machine or started ELI VR, and refuses any address that is not loopback. With it on, the microphone is recorded only while the talk button is held, and the clip goes to ELI v3 on this machine and nowhere else.

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

This installer accepts local `.zip` files only and unpacks them into `assets/user_packs/`. The app does not load packs from there yet.

## ELI v3

When ELI VR runs beside ELI v3, this local policy sits underneath ELI's stronger socket-level network toggle.

If ELI's network toggle is OFF, that higher-level control should remain authoritative.

Opened from ELI v3 as a bundle, nothing here changes. ELI v3 starts its server on `127.0.0.1` if it was not running, and ELI VR is told the port. Registering ELI VR with ELI v3 writes one local file and opens no socket.
