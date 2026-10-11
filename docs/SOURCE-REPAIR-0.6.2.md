# ELI VR 0.6.2 — source repair

The 0.6.1 overlay contained three generated GDScript blocks where newline
characters were accidentally written as the two literal characters `\` and `n`.

That corrupted:

- `RoomFactory._distant_star()` plus `_asteroid_belt()`
- `RoomFactory._build_space()`
- `SpatialConsole.set_desktop_workspace()` plus its layout helpers

Godot therefore could not parse `room_factory.gd` or `spatial_console.gd`, and
`app.gd` only surfaced the downstream preload failures.

0.6.2 converts those serialized blocks back into normal GDScript source lines.

A new `tools/source_sanity.py` check and equivalent validator guard now reject
this class of packaging corruption before a project is shipped.

No environment design, input mapping, networking policy, desktop capture
architecture, or XR runtime behavior is intentionally changed by this patch.
