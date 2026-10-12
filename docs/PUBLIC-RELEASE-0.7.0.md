# ELI VR 0.7.0 — ELI is in the rooms

ELI VR still runs on its own. With ELI v3 running beside it, ELI is now present and you can talk to him. Linux gets a one-file AppImage, and closing ELI VR now takes the VR runtime down with it.

Tested on Linux with Monado and a Rift CV1: the app, the new launcher and the clean shutdown were run in the headset. The link to ELI was tested against ELI v3's own routes without a headset, and talking has not yet been tried with a real microphone or ELI's real model. Windows and macOS builds come from CI and have not been run on real hardware.

## With ELI v3

Off by default. Needs an ELI v3 that has the world feed.

- **ELI's presence.** A body of light in whichever room ELI's own world puts him in. The status line says where he is when it is not your room. Doubt warms the light, repair work reddens it.
- **Talking.** Hold A or X on a controller, or T on the keyboard, speak, let go. He answers in his own voice from where he stands. The microphone is only open while the button is held.
- **He knows where you are.** ELI VR tells ELI's world when a session starts and which room you enter. Nothing else.
- **As a bundle.** `python3 tools/register_eli_bundle.py` puts ELI VR on ELI v3's list of bundles, so ELI can start it.

Switch it on with `--eli` on the Linux launcher, `-- --eli-link=on` on a release build, or `python3 tools/eli_vr.py eli on`. Everything stays on `127.0.0.1`. See [docs/ELI_INTEGRATION.md](https://github.com/ShadowESC95/ELI_VR/blob/main/docs/ELI_INTEGRATION.md).

## Leaving cleanly

- **An Exit button** on the spatial console, the wrist menu and the settings dock. Press it twice: the first press arms it for four seconds, so a stray trigger pull cannot end the session.
- **Nothing left holding the GPU.** The Linux launcher (`launch/eli-vr.sh`, and the AppImage) stops the desktop helper and every VR runtime process the session started when ELI VR closes, then says what is left and how much GPU memory is in use. A runtime that was already running before is left alone. On the reference machine, GPU memory went from about 1,500 MiB in the headset back to the desktop's own after exit, with no Monado process left.

## One file on Linux

`ELI_VR-0.7.0-x86_64.AppImage` starts the desktop helper and the app, and cleans up on exit.

```bash
chmod +x ELI_VR-0.7.0-x86_64.AppImage
./ELI_VR-0.7.0-x86_64.AppImage                # system OpenXR runtime, flat if there is none
./ELI_VR-0.7.0-x86_64.AppImage --monado       # start native Monado first (Rift CV1 on Wayland)
./ELI_VR-0.7.0-x86_64.AppImage --eli          # with the link to ELI v3
```

Options you always want go on one line in `~/.config/eli-vr/launch.conf`, which is how a double-click is told what to start. Monado itself and the Wayland capture pieces are not inside the AppImage; they come from your system.

## Fixes

- The settings CLI was overruled by settings the app had already saved, so `theme`, `room` and the rest did nothing once you had changed anything in the app. Each command now applies to both.
- The loopback check judged an address by how it began, so `127.0.0.1.example.com` would have passed. It now checks the host itself.
- Every launcher passes extra options through to the app.

## Known gaps

- ELI's world objects arrive but are not drawn, and ELI cannot build or change rooms yet.
- The presence is a light, not a figure.
- The rooms themselves are unchanged from 0.6.3.
- Clean shutdown of the runtime is Linux only. On Windows and macOS the Exit button closes ELI VR and leaves SteamVR or the vendor runtime to you.
- No native app for standalone headsets, no VR on macOS, builds are not code-signed.
