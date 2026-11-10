# ELI VR 0.9.17 — the pointer stays where you set it, pieces really go, lighter textures

**The pointer stays calibrated.** Holding both grips and both triggers for a second used to re-run the hand calibration: that is exactly what you do when you fire a gun in each hand at the range, so a round of shooting saved the hands wherever they were and left the calibration panel in front of your face. That chord is gone. Recalibrate when you mean to: hold **B/Y on both controllers** for a moment (a bar fills while you hold, the controllers pulse when it is done), or press **RECALIBRATE POINTER** on the wrist menu and then hold the controllers together and pull both triggers. Nothing else on Touch, Index or generic OpenXR controllers uses that chord; a single B/Y still opens the console, now on release.

**The HUD readouts can be switched off, and are off by default.** The FPS counter, the controller coordinates, the input diagnostics and the status lines each have a switch on the wrist menu, on the settings dock and on F3, one at a time or all together; they are saved. In a headset they really go now (their text used to sit on the camera, where nothing could hide it). Started with `ELI_VR_XR_DIAGNOSTICS=1` they are all on for that run. The wrist menu sizes itself to your view.

**Game pieces really leave.** A piece put away when a game ends is gone from the room, and a vanished piece no longer catches the trigger or the grip. A hand resting on a light in the order game counts once, and only on the light it is on.

**ELI hears your sessions end.** Closing the window or leaving the app any way sends ELI the end of the session, and the start of a session is sent once.

**The Upgrade Bay's racks blink at their own pace**; ELI's feeling shows on the orb and its light only.

**Lighter on the headset.** Every texture is compressed on the GPU with mipmaps: the model library takes about 0.8 GB of video memory instead of 3.6 GB, and far or slanted surfaces stop shimmering. Godot re-imports the textures once the first time the project is opened.

Works with ELI v3 3.0.158. Not yet: the reworked Ocean, Desert and Anomaly rooms and the readable books of the Memory Archive, the Evidence Wall and ELI's own room come in the next release.
