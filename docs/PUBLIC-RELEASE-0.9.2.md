# ELI VR 0.9.2 — the desktop screen asks before the headset starts

On Linux with Wayland, the desktop asks which screen to share. It used to ask after the headset had started, so the question sat unseen on the monitor and the screen in VR kept waiting. The launcher now starts the desktop helper first and, the first time, waits up to two minutes for you to choose a screen. The answer is remembered, so later sessions share at once without asking.

The screen needs no network connection: the helper and ELI VR talk to each other on the same computer. The screen now says what it is waiting for, and the install guide says the same.

Nothing else has changed since [0.9.1](https://github.com/ShadowESC95/ELI_VR/releases/tag/v0.9.1). The parts with ELI v3 need ELI v3 3.0.134 or newer.
