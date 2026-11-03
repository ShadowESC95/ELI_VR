"""ELI moving in its rooms and acting of its own accord, driven headless through Godot with the real
scripts (tests/gd/eli_alive_check.gd prints one line per check)."""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class Alive(unittest.TestCase):
    lines: dict = {}

    @classmethod
    def setUpClass(cls) -> None:
        godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
        if not godot:
            raise unittest.SkipTest("Godot is not installed here")
        env = {k: v for k, v in os.environ.items() if k not in ("DISPLAY", "WAYLAND_DISPLAY")}
        # the desktop link's key goes in a folder of the test's own, never the session's
        sandbox = tempfile.mkdtemp(prefix="eli-vr-test-")
        cls.addClassCleanup(shutil.rmtree, sandbox, True)
        env.update(XDG_RUNTIME_DIR=sandbox, HOME=sandbox, LOCALAPPDATA=sandbox, ELI_VR_TEST_SANDBOX=sandbox)
        out = ""
        for check in ("eli_alive_check.gd", "eli_screens_check.gd"):
            out += subprocess.run([godot, "--headless", "--xr-mode", "off", "--path", str(ROOT),
                                   "--script", str(ROOT / "tests" / "gd" / check)],
                                  env=env, capture_output=True, text=True, timeout=300).stdout
        for line in out.splitlines():
            if line.startswith(("PASS ", "FAIL ")):
                name = line.split(" ", 1)[1].split(":", 1)[0]
                cls.lines[name] = line

    def check(self, name: str) -> None:
        line = self.lines.get(name, f"FAIL {name}: the check never ran")
        self.assertTrue(line.startswith("PASS"), line)

    def test_eli_is_there_when_you_come_into_its_room(self) -> None:
        self.check("there_when_you_come_in")

    def test_eli_goes_to_what_it_is_making(self) -> None:
        self.check("goes_to_what_it_makes")

    def test_eli_acts_on_a_waiting_moment_only_when_free(self) -> None:
        self.check("not_when_not_free")
        self.check("acts_when_free")

    def test_eli_does_not_act_while_you_talk(self) -> None:
        self.check("not_while_you_talk")

    def test_the_next_act_is_paced_by_how_long_the_last_took(self) -> None:
        self.check("paced_by_the_last")
        self.check("acts_again_after")

    def test_leaving_the_room_yourself_is_not_eli_leaving(self) -> None:
        self.check("gone_when_you_leave")

    def test_eli_hears_you_through_the_headsets_microphone_or_one_that_gives_sound(self) -> None:
        self.check("the_headsets_own_microphone_is_tried_before_the_default")
        self.check("a_microphone_giving_only_silence_is_passed_over_and_the_one_heard_is_kept")


class Screens(Alive):
    """The screens in the rooms show ELI's real log and state, and nothing made up."""

    def test_a_screen_shows_what_fits_and_cuts_what_does_not(self) -> None:
        self.check("fits_its_rows")
        self.check("cuts_a_long_line")

    def test_the_log_reads_in_order_with_troubles_marked(self) -> None:
        self.check("log_in_order")
        self.check("trouble_in_amber")
        self.check("tail_is_the_newest")

    def test_a_terminal_follows_one_strand_of_the_log(self) -> None:
        self.check("strand_keeps_its_kind")

    def test_without_eli_a_screen_says_so_and_shows_nothing_else(self) -> None:
        self.check("says_when_not_connected")

    def test_the_basement_board_shows_the_log(self) -> None:
        self.check("board_shows_the_log")

    def test_elis_memories_stand_face_out_on_the_archive_shelves(self) -> None:
        self.check("memories_stand_on_the_shelf")
        self.check("only_memories_have_a_place")
        self.check("no_book_where_a_memory_stands")

    def test_a_memory_is_written_on_its_cover_inside_the_page(self) -> None:
        self.check("a_memory_is_written_on_its_cover")
        self.check("writing_starts_inside_the_page")
        self.check("a_written_record_holds_still")

    def test_what_eli_did_for_you_stands_where_it_belongs(self) -> None:
        self.check("what_eli_did_has_its_places")

    def test_what_eli_found_is_printed_and_the_radio_says_what_is_playing(self) -> None:
        self.check("a_finding_is_printed_with_its_lines")
        self.check("the_radio_says_what_is_playing")

    def test_the_upgrade_bay_racks_blink_as_hard_as_eli_is_working(self) -> None:
        self.check("the_racks_work_as_hard_as_eli")

    def test_eli_can_place_real_things_and_paint_its_own_pictures(self) -> None:
        self.check("eli_is_told_the_real_things_there_are")
        self.check("a_real_thing_is_its_model_turned_as_eli_turned_it")
        self.check("a_painting_is_painted_and_stands_on_an_easel_on_the_floor")

    def test_the_core_room_shows_what_is_coming_up_on_your_agenda(self) -> None:
        self.check("the_core_shows_what_is_coming_up")

    def test_a_picture_eli_took_is_pinned_up_as_a_photograph(self) -> None:
        self.check("a_picture_eli_took_is_pinned_up_as_a_photograph")

    def test_changing_rooms_does_not_read_the_models_from_disk_again(self) -> None:
        self.check("models_load_once_in_the_background_and_are_kept")

    def test_the_desktop_can_be_pointed_at_clicked_and_scrolled(self) -> None:
        self.check("pointing_at_the_desktop_moves_clicks_and_scrolls_it")

    def test_the_desktop_curves_round_you_and_is_pointed_at_where_it_shows(self) -> None:
        self.check("the_desktop_curves_round_you_one_pixel_to_one_and_is_pointed_at_where_it_shows")
        self.check("a_flat_desktop_is_pointed_at_where_it_shows")
        self.check("the_runtime_layer_has_the_screens_shape")

    def test_holding_the_desktop_moves_sizes_curves_and_brings_it_nearer(self) -> None:
        self.check("holding_the_desktop_moves_sizes_curves_and_brings_it_nearer")

    def test_hands_panels_and_eli_are_drawn_over_the_desktop(self) -> None:
        self.check("hands_panels_and_eli_are_drawn_over_the_desktop_and_the_room_is_not")

    def test_the_desktop_link_gives_the_key_and_reads_the_screen_as_tiles(self) -> None:
        self.check("the_desktop_link_gives_the_key_and_reads_the_screen_as_tiles")


if __name__ == "__main__":
    unittest.main()
