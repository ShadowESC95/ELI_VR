# ELI VR 0.3.2 — controller calibration

0.3.1 proved that CV1 Touch pose tracking, button input, pointing and world
grabbing are all working. On this Monado/CV1 setup the controller tracking
frame can still have a large common positional offset relative to the HMD,
placing the virtual hands above the user's head.

0.3.2 separates raw OpenXR tracking from the rendered/interactive hand pose.

```text
Monado/OpenXR raw controller pose
        |
        +--> input/buttons remain untouched
        |
        +--> ELI calibration transform
                |
                +--> rendered hand
                +--> fingertip pointer
                +--> wrist menu
                +--> world grabbing
```

This means ELI VR can correct the visible/interactive hand positions without
breaking the controller action stream.

## Pointer-free emergency calibration

This is intentionally usable when the pointers are unusable.

1. Put on the headset and wait until both Touch controllers track.
2. Look approximately forward.
3. Hold both controllers naturally together in front of the sternum/chest.
4. Hold **both grips + both triggers** for one second.
5. Both controllers pulse when calibration is accepted.

The correction is stored locally in:

```text
user://eli_vr/settings.json
```

No data leaves the machine.

## Calibration widget

Open it in any of three ways:

- left wrist menu -> **CALIBRATE**
- keyboard **F6**
- the both-grips + both-triggers calibration chord opens it automatically

The widget provides:

- CALIBRATE
- RECENTER VIEW
- RESET
- LEFT / RIGHT
- UP / DOWN
- FWD / BACK

Each trim button moves the common hand calibration by 2 cm.

`RECENTER VIEW` uses Godot's XR recenter operation and is deliberately separate
from hand calibration. Recentring the HMD does not fix a controller-only
tracking-frame offset, while the hand calibration does not alter head tracking.

## Development shortcut

Keyboard F7 performs the guided hand calibration immediately when both
controllers are tracked.
