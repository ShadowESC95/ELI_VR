# Quality and performance

ELI VR is built for a headset's frame rate on an ordinary desktop GPU, and scales down from there. It uses Godot's mobile renderer on purpose: forward rendering, a fixed light count per object and effects that are safe in stereo.

## Quality profiles

Out of the box the setting is `auto`: at start ELI VR looks at the CPU, the memory and whether the GPU is a discrete one, and picks a profile. The pick is not saved, so a settings file moved to another machine is judged again there. To choose yourself, use the console (VISUAL), the settings dock (`F1`), or `python3 tools/eli_vr.py quality <name>`.

| Profile | Shadows | Fog | Particles | Detail | Headset render scale |
|---|---|---|---|---|---|
| `low` | off | off | off | 0.55 | 0.75 |
| `medium` | on | on | on | 1.0 | 0.9 |
| `high` | on | on | on | 1.35 | 1.0 |
| `ultra` | on | on | on | 1.8 | 1.15 |

The rooms are the same at every profile. What changes is how much drifts and moves in them, whether lights cast shadows, and how many pixels the headset is given. The files are `config/profiles/*.json`.

Render scale is read once, when the headset session starts. Change the profile and restart to apply it.

## What the app works out for itself

- **The headset's refresh rate.** It follows what the OpenXR runtime reports, and physics ticks at that rate.
- **Foveation.** Switched on when the runtime supports it, lighter at `low` and `medium`. `xr.foveation` set to `off` disables it.
- **Glow.** Off in a headset, where it costs a full-screen pass per eye, and on in the flat window.
- **Textures.** Compressed on the GPU with mipmaps (`tools/set_texture_imports.py`), so the art costs video memory once and not per room.
- **Focus.** The world pauses when the headset says the session has lost focus, and carries on when it has it back. `xr.pause_when_unfocused` set to `false` keeps it running.

OpenXR extensions are treated as optional. A runtime without one loses that feature, not the session.

## What to expect

The reference setup is a mid-range desktop GPU from 2019 driving a 90 Hz PC headset. There, every one of the fifteen places holds 90 frames a second at `ultra`, with roughly 1.5 to 2.1 GB of video memory in use. That is one machine, with the profile chosen by hand. On less, `auto` will pick lower; on integrated graphics expect `low` in the flat window.

The performance HUD (`F3`) shows the frame rate, and `ELI_VR_LOG_FPS=1` writes it to the log every few seconds.

## If it is slow

1. Drop a profile.
2. Turn off the desktop screen if you are not using it (`F2`); frames arriving cost time.
3. In the flat window, `compat` mode uses OpenGL and suits older cards.
4. Run `python3 tools/doctor.py` and read what it says about the GPU driver and the OpenXR runtime.
