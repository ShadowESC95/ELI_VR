# ELI VR 0.2.6 — Godot controller tracker-name fix

The 0.2.5 in-headset diagnostic showed:

```text
L active:N track:N
R active:N track:N
```

even though Monado had already detected and tracked both Oculus Touch controllers.

The cause was a namespace mismatch in ELI VR's dynamically-created
`XRController3D` nodes.

## OpenXR paths versus Godot tracker names

The OpenXR action map correctly uses OpenXR paths such as:

```text
/user/hand/left
/user/hand/right
```

However, `XRController3D.tracker` does **not** take those paths for the standard
left/right controller trackers.

Godot reserves these tracker names:

```text
left_hand
right_hand
```

Godot's OpenXR interface internally maps those names to:

```text
/user/hand/left
/user/hand/right
```

ELI VR 0.2.5 incorrectly used the OpenXR path as the Godot tracker name, so the
controller nodes could never bind to the trackers that Monado registered.

0.2.6 changes:

```gdscript
left_hand.tracker = "left_hand"
right_hand.tracker = "right_hand"
```

The pose remains:

```gdscript
pose = "aim_pose"
```

which is supplied by ELI VR's OpenXR action map.

## Expected diagnostic

Once Touch tracking is available:

```text
L left_hand/aim_pose active:Y track:Y
R right_hand/aim_pose active:Y track:Y
```

The sticks/triggers/buttons should then update through the action map.
