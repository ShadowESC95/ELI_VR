# ELI VR 0.8.0 — fifteen real places, and ELI v3 can open it

Every room has been rebuilt as somewhere to be, and ELI VR is now a bundle of ELI v3: ELI v3 lists it and opens it, the same way it does ELI Legal. It still runs on its own.

![All fifteen rooms](https://raw.githubusercontent.com/ShadowESC95/ELI_VR/main/docs/images/rooms-all.jpg)

Tested on Linux with Monado and a Rift CV1: all fifteen rooms were run in the headset and hold its 90 frames a second at the `ultra` profile on a mid-range desktop GPU. How they look was judged from rendered pictures. The bundle link was tested with ELI v3's own launch code and a stand-in for the app. Windows and macOS builds come from CI and have not been run on real machines.

## The rooms

All fifteen are new. None is a box with a sky any more, and none is still.

The nine ELI rooms:

- **Core Room.** An open deck on a station in orbit, Earth below, the real Milky Way overhead.
- **Memory Archive.** A marble hall open to the stars, walls shelved with small lights that each keep their own time.
- **Workshop.** A repair bay with its door open to space: a welding arm, a crane on its rails, Earth going by.
- **Reflection Chamber.** A stone terrace on a mountain plateau at dawn, ringed by still water.
- **Debug Basement.** A concrete bunker of racks, scrolling terminals and one strip light on its way out.
- **Upgrade Bay.** A white lab where a printer builds a part and an arm sorts crates off a belt.
- **Simulation Lab.** A world that is only being computed: grid, wire hills, towers of falling data.
- **Anomaly Room.** A cracked deck drifting towards a black hole.
- **Evidence Wall.** A dim studio with a long wall of pinned sheets strung with thread.

Six more workspaces: a pine forest in morning mist, a rig at sea at sunset, a glass dome on the seabed, a platform beside a ringed giant, a snowfield under the northern lights, dunes under the Milky Way.

The night sky is NASA's star map and the Earth is NASA's Blue Marble. The forest, the mountain and the sunset are photographs of real places. Stone, wood, metal, snow and sand are scanned materials. All of it is free to use and listed in [assets/CREDITS.md](https://github.com/ShadowESC95/ELI_VR/blob/main/assets/CREDITS.md). Themes colour the lights in every room.

## Opened from ELI v3

ELI v3 lists the ELI applications installed beside it and opens them: at start-up, from its Bundles menu, or with `eli --bundle vr`. Tell it once where ELI VR is:

```bash
./ELI_VR-0.8.0-x86_64.AppImage --register-eli     # the AppImage
./launch/eli-vr.sh --register-eli                 # a Linux folder
python3 tools/register_eli_bundle.py              # any OS
```

Opened that way, ELI v3 has its local server answering first, tells ELI VR the port, and ELI VR starts with the link on. ELI v3 newer than 3.0.131 does that by itself; with 3.0.131, switch ELI's server on first. `--unregister-eli` takes it off the list. Everything stays on `127.0.0.1`.

ELI VR names no model. Whichever one ELI v3 has loaded answers.

See [docs/ELI_INTEGRATION.md](https://github.com/ShadowESC95/ELI_VR/blob/main/docs/ELI_INTEGRATION.md).

## Also

- Quality is `auto` out of the box and picks a profile from the machine; the four profiles are documented with what each one changes.
- `--eli-shot` saves pictures of a room from a flat run, for looking at one without a headset.
- The documents were brought up to date: architecture, settings (every default checked against the code), commands, platforms, roadmap.
- Every package carries the small Python side ELI v3 uses to find ELI VR.

## Known gaps

- The indoor rooms are shapes built in code with scanned surfaces. They have no modelled props yet.
- The forest's near trees are bare trunks; the foliage is in the photograph behind them.
- The downloads are larger than 0.7.0: the art is real now.
- ELI's world objects arrive but are not drawn, ELI cannot build or change rooms, and his presence is a light, not a figure.
- Talking has not yet been tried with a real microphone in the headset.
- Clean shutdown of the VR runtime is Linux only.
- No native app for standalone headsets, no VR on macOS, builds are not code-signed.
- The code and textures of the old generated rooms are still in the tree, unused.
