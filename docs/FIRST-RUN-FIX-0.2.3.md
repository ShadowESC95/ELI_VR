# ELI VR 0.2.3 parse + asset repair

This repair addresses issues exposed by the first real Godot 4.7.2 import:

- explicit `float` typing in `RoomFactory` where mixed numeric inference failed;
- explicit `String` typing in `PerformanceHud`;
- proactive explicit typing for XR stick/turn vectors and control-dock display strings;
- replacement of the corrupt `rock_albedo.png`;
- valid empty export option sections for all export presets;
- PNG CRC validation in `tools/validate_project.py`;
- `tools/godot_parse_check.sh` now fails if Godot prints script/import errors even if Godot itself exits with status 0.

The parse check forces XR off and does not require a headset/runtime.
