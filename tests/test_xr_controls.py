"""The recalibration chord is a button pair nothing else uses: read from the real action map
(openxr_action_map.tres) and the real scripts, so a binding or a script that takes the chord's
button for something else fails here. The chord's behaviour is checked in Godot
(tests/gd/eli_alive_check.gd, tests/test_eli_alive.py).

The hands and the pointer rays are checked in Godot from simulated controller poses with the real
calibration manager, pointer, hand and panel (tests/gd/xr_calibration_check.gd)."""
from __future__ import annotations

import re
import unittest
from pathlib import Path

from test_eli_alive import run_godot_checks

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


class HandsAndPointer(unittest.TestCase):
    lines: dict = {}

    @classmethod
    def setUpClass(cls) -> None:
        cls.lines = run_godot_checks(cls, ("xr_calibration_check.gd",))

    def check(self, name: str) -> None:
        line = self.lines.get(name, f"FAIL {name}: the check never ran")
        self.assertTrue(line.startswith("PASS"), line)

    def test_with_no_calibration_the_ray_is_the_aim_pose_and_the_hand_the_grip_pose(self) -> None:
        self.check("with_no_calibration_the_ray_leaves_the_aim_pose_along_where_the_controller_points")
        self.check("with_no_calibration_the_hand_is_at_the_grip_pose")
        self.check("a_controller_not_tracked_has_no_ray_and_one_with_only_its_grip_keeps_its_ray")

    def test_the_hand_stands_on_the_grip_pose_as_a_hand_holds_a_controller(self) -> None:
        self.check("the_hand_stands_on_the_grip_pose_as_a_hand_holds_a_controller")

    def test_walking_turning_and_a_room_change_carry_the_hands_and_the_rays(self) -> None:
        self.check("walking_turning_and_a_room_change_carry_the_hands_and_the_rays")

    def test_recalibrating_refines_each_pointer_and_never_moves_the_hands(self) -> None:
        self.check("recalibrating_brings_each_ray_onto_the_mark_and_leaves_the_hands_on_the_controllers")
        self.check("the_pointers_turn_is_each_controllers_own_and_goes_with_the_hand")
        self.check("a_controller_not_pointed_at_the_panel_is_left_as_it_was_and_it_says_why_nothing_was_taken")

    def test_the_calibration_is_kept_per_controller_and_the_old_guess_is_dropped(self) -> None:
        self.check("what_the_old_calibration_saved_is_dropped_and_moves_nothing")
        self.check("the_calibration_is_kept_per_controller_and_comes_back_the_same")
        self.check("a_reset_puts_hands_and_rays_back_on_the_runtimes_poses")

    def test_the_trim_is_a_fixed_turn_and_shift_of_the_controllers_space(self) -> None:
        self.check("the_trim_turns_about_the_head_where_it_is_and_then_holds_when_the_head_moves")

    def test_a_controller_with_no_tracked_position_is_placed_from_the_head(self) -> None:
        self.check("a_tracked_controller_turning_and_a_still_one_stay_on_the_runtimes_poses")
        self.check("a_controller_whose_place_does_not_move_while_it_turns_is_placed_from_the_head")
        self.check("a_hand_placed_from_the_head_goes_with_the_head_whether_its_place_was_held_or_carried")
        self.check("when_its_place_moves_again_the_hand_is_back_on_the_runtimes_pose")

    def test_the_settings_no_longer_carry_a_guess_at_where_the_hands_are(self) -> None:
        import json
        kept = json.loads((ROOT / "config" / "defaults.json").read_text())["xr"]["controller_calibration"]
        self.assertEqual(sorted(kept), ["aim", "frame"])
        self.assertEqual(kept["aim"], {"left": [0.0, 0.0, -1.0], "right": [0.0, 0.0, -1.0]})
        self.assertEqual(kept["frame"], {"offset_m": [0.0, 0.0, 0.0], "yaw_deg": 0.0})


if __name__ == "__main__":
    unittest.main()
