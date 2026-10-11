# ELI VR 0.2.7 — controller pose fallback

0.2.6 proved that controller *input* is arriving from both Oculus Touch
controllers, but the user still saw no pointer rays.

Godot treats controller input and a controller node's bound spatial pose as
separate concerns. An `XRController3D` can receive actions from its tracker
while the specific pose bound to that node has no current tracking data.

0.2.7 therefore separates the roles:

```text
left_hand / right_hand tracker
        |
        +-- grip_pose node -> controller body + inputs
        |
        +-- aim_pose node  -> preferred pointing pose
```

Pointer selection policy:

```text
valid aim_pose
    -> use aim pose
else valid grip_pose
    -> use grip pose as fallback
else
    -> hide beam and report NO_POSITIONAL_POSE
```

The in-headset diagnostic now independently reports `grip` and `aim`:

```text
L grip:TRACK aim:TRACK ...
R grip:TRACK aim:TRACK ...
```

or, while Monado is still waiting for controller calibration:

```text
L grip:OFF aim:OFF ...
R grip:OFF aim:OFF ...
```

The terminal also reports tracking transitions and pointer mode:

```text
ELI VR XR POSE: left grip tracking=true
ELI VR XR POINTER [left_hand]: AIM
```

If aim pose is unavailable but grip works:

```text
ELI VR XR POINTER [left_hand]: GRIP_FALLBACK
```

This makes controller tracking failures distinguishable from action/input
binding failures.
