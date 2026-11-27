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

## The licence store: the one remote contact

ELI VR contacts one host on the internet, ELI's licence store (`licences.geteli.tech`, over HTTPS),
and only from the desktop helper (`native/desktop_bridge/src/store.rs`):

- when you enter a key bought from the store, once per computer, to activate it (the store counts
  the computer against the licence's seats), and when you choose **Deactivate this computer**;
- at launch, when the computer is online and without waiting for it: the signed list of withdrawn
  licences, and, during the trial, this computer's trial (so the trial is not restarted by deleting
  its records).

It sends the licence key and this computer's activation code (a one-way code made from the
operating system's install id: nothing about you, your rooms or your desktop), and nothing else.
An internet connection is still never required: a computer that cannot go online is activated
from any other device at https://licences.geteli.tech/activate. `tools/network_audit.py` allows this
host in that one file and fails on it anywhere else.

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
