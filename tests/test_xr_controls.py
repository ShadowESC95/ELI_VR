"""The recalibration chord is a button pair nothing else uses: read from the real action map
(openxr_action_map.tres) and the real scripts, so a binding or a script that takes the chord's
button for something else fails here. The chord's behaviour is checked in Godot
(tests/gd/eli_alive_check.gd, tests/test_eli_alive.py)."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIDGET = ROOT / "scripts" / "xr" / "calibration_widget.gd"
PROFILES = {
    "touch": "/interaction_profiles/oculus/touch_controller",
    "index": "/interaction_profiles/valve/index_controller",
    "generic": "/interaction_profiles/khr/generic_controller",
}


def action_map() -> dict[str, dict[str, list[str]]]:
    """profile path -> action name -> the input paths bound to it."""
    text = (ROOT / "openxr_action_map.tres").read_text()
    actions: dict[str, str] = {}
    bindings: dict[str, tuple[str, str]] = {}
    profiles: dict[str, dict[str, list[str]]] = {}
    for block in re.split(r"\n(?=\[)", text):
        head = block.split("\n", 1)[0]
        found = re.search(r'id="([^"]+)"', head)
        if not found:
            continue
        rid = found.group(1)
        if 'type="OpenXRAction"' in head:
            actions[rid] = re.search(r'resource_name = "([^"]+)"', block).group(1)
        elif 'type="OpenXRIPBinding"' in head:
            bindings[rid] = (re.search(r'action = SubResource\("([^"]+)"\)', block).group(1),
                             re.search(r'binding_path = "([^"]+)"', block).group(1))
        elif 'type="OpenXRInteractionProfile"' in head:
            path = re.search(r'interaction_profile_path = "([^"]+)"', block).group(1)
            per: dict[str, list[str]] = {}
            for ref in re.findall(r'SubResource\("([^"]+)"\)', block.split("bindings", 1)[1]):
                action, binding = bindings[ref]
                per.setdefault(actions[action], []).append(binding)
            profiles[path] = per
    return profiles


def chord_action() -> str:
    return re.search(r'const CHORD_ACTION: String = "([^"]+)"', WIDGET.read_text()).group(1)


class RecalibrationChord(unittest.TestCase):
    def test_the_chord_button_is_bound_on_both_hands_in_touch_index_and_generic(self) -> None:
        profiles = action_map()
        chord = chord_action()
        for name, path in PROFILES.items():
            with self.subTest(profile=name):
                bound = profiles[path].get(chord, [])
                self.assertTrue(any(b.startswith("/user/hand/left/") for b in bound), f"{name}: {bound}")
                self.assertTrue(any(b.startswith("/user/hand/right/") for b in bound), f"{name}: {bound}")

    def test_no_other_action_is_bound_to_the_chords_inputs(self) -> None:
        profiles = action_map()
        chord = chord_action()
        for name, path in PROFILES.items():
            with self.subTest(profile=name):
                mine = set(profiles[path][chord])
                for action, bound in profiles[path].items():
                    if action != chord:
                        self.assertFalse(mine & set(bound), f"{name}: {action} is bound to {mine & set(bound)} too")

    def test_only_the_calibration_panel_reads_the_chord_button(self) -> None:
        chord = chord_action()
        readers = [p.relative_to(ROOT).as_posix() for p in (ROOT / "scripts").rglob("*.gd")
                   if f'"{chord}"' in p.read_text(errors="ignore")]
        self.assertEqual(readers, ["scripts/xr/calibration_widget.gd"])

    def test_the_old_grips_and_triggers_chord_is_gone(self) -> None:
        # both grips and both triggers is what holding a gun in each hand and firing is
        self.assertFalse('"grip_click"' in WIDGET.read_text(), "the calibration panel still reads the grips")


if __name__ == "__main__":
    unittest.main()
