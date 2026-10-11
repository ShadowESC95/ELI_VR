# ELI VR 0.2.8 — WayVR/OpenXR pointer reference fix

The exact WayVR CV1-era OpenXR backend creates a pose action, creates an
OpenXR action space for it, synchronizes actions, and locates that action space
against stage space at predicted display time. Pointer-line rendering is kept
separate from pose tracking.

Godot performs the corresponding OpenXR action-space work internally, but has
an important naming translation:

```text
OpenXR action resource "aim_pose"  -> Godot tracker pose "aim"
OpenXR action resource "grip_pose" -> Godot tracker pose "grip"
```

0.2.7 incorrectly assigned the action-resource names to XRController3D.pose.
That is why buttons worked while both pose nodes reported no positional pose.

0.2.8 keeps `aim_pose` / `grip_pose` in `openxr_action_map.tres`, but uses:

```gdscript
left_hand.pose = "grip"
right_hand.pose = "grip"
left_aim.pose = "aim"
right_aim.pose = "aim"
```

The pointer still prefers aim and falls back to grip. It now renders an
unshaded beam plus hit reticle, changing to green over an interactable target.
