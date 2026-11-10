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
        env.update(XDG_RUNTIME_DIR=sandbox, XDG_DATA_HOME=sandbox, HOME=sandbox, LOCALAPPDATA=sandbox, APPDATA=sandbox,
                   ELI_VR_TEST_SANDBOX=sandbox)
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

    def test_a_game_eli_set_begins_on_its_pieces_and_its_result_is_told(self) -> None:
        self.check("a_game_set_in_the_room_begins_with_its_first_piece_up")
        self.check("a_hit_scores_a_piece_left_too_long_is_a_miss_and_the_result_is_told")

    def test_sorting_order_catching_and_hiding_are_played_as_eli_set_them(self) -> None:
        self.check("a_piece_let_go_on_its_mat_scores_and_on_the_wrong_one_is_a_miss")
        self.check("the_lights_are_hit_in_the_order_shown_and_stopping_tells_how_far_it_got")
        self.check("a_piece_coming_down_is_caught_in_the_hand_and_one_that_lands_is_a_miss")
        self.check("a_hidden_piece_is_found_by_looking_at_it_then_hides_elsewhere")

    def test_a_game_elis_world_takes_down_ends_quietly(self) -> None:
        self.check("a_game_taken_down_by_elis_world_ends_without_a_word")

    def test_a_piece_out_of_sight_is_out_of_reach_of_the_trigger_and_the_grip(self) -> None:
        self.check("a_piece_out_of_sight_does_not_stop_a_ray_at_the_live_one_behind_it")

    def test_a_hand_resting_on_a_light_touches_it_once_and_not_the_light_beside_it(self) -> None:
        self.check("a_hand_on_a_light_is_one_touch_and_the_light_beside_it_is_not_touched")

    def test_the_pieces_of_a_game_leave_the_room_when_elis_world_takes_them(self) -> None:
        self.check("the_pieces_of_games_played_out_are_gone_once_elis_world_takes_them")

    def test_eli_is_told_of_the_session_once_and_told_when_it_ends_however_it_ends(self) -> None:
        self.check("the_session_is_told_once_whichever_comes_first")
        self.check("closing_the_window_or_ending_the_app_tells_eli_the_session_ended")

    def test_the_hello_says_how_big_a_message_the_link_takes(self) -> None:
        self.check("the_hello_says_how_big_a_message_the_link_takes")

    def test_the_range_begins_with_guns_on_the_table_and_shots_score_by_their_ring(self) -> None:
        self.check("the_range_begins_with_the_guns_on_the_table_and_a_target_up")
        self.check("a_shot_scores_by_the_ring_it_hits")

    def test_bolts_fly_beams_rest_and_rails_go_through(self) -> None:
        self.check("a_bolt_flies_and_hits_what_it_meets_and_one_that_meets_nothing_is_gone")
        self.check("a_beam_must_rest_on_a_target_and_a_rail_goes_through_every_target_on_its_line")

    def test_a_gun_let_go_goes_back_and_the_result_tells_each_guns_part(self) -> None:
        self.check("a_gun_let_go_goes_back_to_the_table")
        self.check("the_range_tells_each_guns_part_in_the_result")
        self.check("a_click_on_a_flat_screen_fires_the_first_gun")

    def test_the_hud_readouts_are_off_for_normal_use_and_switched_each_or_all(self) -> None:
        self.check("the_readouts_are_off_for_normal_use_each_or_all_switched_and_kept")
        self.check("a_diagnostic_run_shows_every_readout_and_what_is_switched_lasts_that_run")
        self.check("the_hud_says_only_the_readouts_switched_on_and_always_what_must_be_seen")
        self.check("the_hud_and_the_input_diagnostics_on_the_camera_go_when_switched_off")
        self.check("the_calibration_coordinates_show_only_with_their_readout")

    def test_the_pointer_is_recalibrated_by_the_chord_or_from_the_wrist(self) -> None:
        self.check("the_chord_shows_its_hold_then_recalibrates_once_says_so_and_goes")
        self.check("letting_the_chord_go_early_or_firing_with_both_triggers_recalibrates_nothing")
        self.check("b_y_alone_toggles_the_console_on_letting_go_and_the_chord_never_does")
        self.check("recalibrate_pointer_takes_both_triggers_pressed_afresh_and_gives_them_back")
        self.check("a_recalibration_without_both_controllers_says_so_and_waits")

    def test_the_wrist_menu_and_the_settings_dock_reach_recalibration_and_every_readout(self) -> None:
        self.check("the_wrist_menu_recalibrates_and_switches_each_readout_or_all_saying_how_they_stand")
        self.check("the_settings_dock_switches_each_readout_or_all_and_follows_the_other_switches")


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

    def test_elis_thoughts_are_lines_with_their_decision_chance_and_outcome(self) -> None:
        self.check("thoughts_are_lines")
        self.check("thoughts_keep_their_kind")
        self.check("thoughts_keep_their_room")

    def test_the_debug_basement_board_shows_what_eli_tried(self) -> None:
        self.check("board_shows_what_eli_tried")

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

    def test_the_upgrade_bay_racks_blink_at_their_own_pace_whatever_eli_is_doing(self) -> None:
        self.check("the_racks_keep_their_own_pace_whatever_eli_is_doing")

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

    def test_a_model_eli_brought_in_is_fetched_once_measured_and_drawn(self) -> None:
        self.check("a_model_eli_brought_in_is_fetched_once_measured_and_drawn")

    def test_elis_thought_sheets_hang_in_six_rooms_and_the_one_in_hand_is_reported(self) -> None:
        self.check("thought_sheets_have_places_in_six_rooms")
        self.check("a_thought_sheet_is_written_under_its_kinds_tab")
        self.check("the_sheet_in_the_users_hand_is_reported_as_its_record")

    def test_the_land_carries_what_stands_on_it(self) -> None:
        self.check("the_land_knows_its_height_and_what_stands_on_it_stands_on_it")
        self.check("ground_cover_blades_are_drawn_and_the_guns_have_their_sounds")
        self.check("the_forest_stands_on_its_floor_with_boughs_and_cover")

    def test_the_ocean_gulls_flock_bank_and_keep_over_the_sea_and_things_ride_its_swell(self) -> None:
        self.check("the_ocean_gulls_are_birds_that_flock_bank_and_keep_their_height")
        self.check("the_ocean_floats_its_buoys_and_boat_on_the_swell_it_draws")

    def test_the_fish_under_the_sea_school_over_the_seabed(self) -> None:
        self.check("the_underwater_fish_school_over_the_seabed")

    def test_the_black_hole_bends_light_as_general_relativity_does(self) -> None:
        self.check("light_bends_round_the_black_hole_as_general_relativity_bends_it")

    def test_the_desert_is_dunes_and_mesas_under_a_night_sky(self) -> None:
        self.check("the_desert_is_wind_built_dunes_with_mesas_beyond_under_a_night_sky")

    def test_the_desert_moon_shows_its_phase_and_casts_its_light(self) -> None:
        self.check("the_desert_moon_is_in_the_sky_at_its_phase_and_casts_the_light_its_phase_and_height_give")

    def test_the_desert_ground_is_made_without_pausing_the_room(self) -> None:
        self.check("the_desert_ground_is_made_in_the_background_and_is_the_same_land")

    def test_the_arctic_hut_is_a_log_cabin_with_all_it_had(self) -> None:
        self.check("the_arctic_hut_is_a_log_cabin_and_keeps_what_stood_at_it")

    def test_the_rebuilt_rooms_shaders_compile(self) -> None:
        self.check("the_rebuilt_rooms_shaders_compile_and_the_mountain_has_its_birds")


    def test_writing_is_sized_for_where_it_is_read_and_stands_out_from_its_paper(self) -> None:
        self.check("writing_is_sized_for_where_it_is_read_and_stands_out_from_its_paper")

    def test_a_book_cuts_its_writing_into_pages_that_fit_and_says_on_its_cover_what_it_is_and_when(self) -> None:
        self.check("a_book_cuts_its_writing_into_pages_that_fit_and_keeps_every_word_in_order")
        self.check("a_book_says_on_its_cover_and_spine_what_it_is_and_when")

    def test_a_book_taken_down_opens_in_the_hand_turns_its_pages_and_goes_back(self) -> None:
        self.check("a_book_taken_down_opens_in_the_hand_turns_its_pages_and_goes_back_to_its_place")
        self.check("a_hand_holding_a_book_is_known_to_the_book_for_the_other_hand")

    def test_the_archive_shelves_elis_books_by_time_and_bare_shelves_say_why(self) -> None:
        self.check("the_archive_shelves_elis_books_by_time_with_a_plate_where_each_month_begins")
        self.check("bare_shelves_say_why_from_the_data")

    def test_elis_room_is_built_once_and_has_a_bookcase_of_its_own_books(self) -> None:
        self.check("elis_room_is_built_once_with_the_look_eli_gave_it")
        self.check("elis_room_has_a_bookcase_of_its_own_books_a_shelf_for_each_kind")

    def test_the_evidence_wall_shows_beliefs_disputes_exhibits_and_threads(self) -> None:
        self.check("a_belief_is_a_case_card_saying_how_sure_eli_is_and_since_when")
        self.check("the_evidence_wall_pins_up_nothing_that_is_not_elis")
        self.check("the_evidence_wall_is_a_full_wall_of_pinned_sheets")
        self.check("no_sheet_on_the_wall_says_anything_elis_records_do_not")
        self.check("disputes_come_first_with_their_question_and_thread_runs_between_related_cards")
        self.check("the_exhibits_are_the_records_elis_beliefs_rest_on")

    def test_the_evidence_wall_scores_actions_charts_figures_and_lays_out_lessons(self) -> None:
        self.check("the_scoreboard_says_how_often_each_action_worked_how_that_changed_and_what_worked_instead")
        self.check("the_charts_show_how_often_elis_figures_proved_right_week_by_week")
        self.check("the_case_files_of_what_eli_learned_lie_on_the_desk")
        self.check("a_bare_board_says_why_from_the_data")

    def test_a_book_sent_without_its_pages_is_read_whole_by_its_id(self) -> None:
        self.check("a_book_sent_without_its_pages_is_read_whole_by_its_id_when_opened")

    def test_the_rooms_show_elis_example_world_message(self) -> None:
        self.check("the_evidence_wall_shows_elis_example_world_message")
        self.check("the_archive_shelves_elis_example_books")
        self.check("elis_room_shelves_its_example_books")

    def test_a_record_let_go_goes_back_and_one_without_a_place_lets_go_of_it(self) -> None:
        self.check("a_record_let_go_goes_back_to_its_place_and_is_not_moved_in_elis_world")
        self.check("a_record_that_loses_its_place_lets_go_of_it")


if __name__ == "__main__":
    unittest.main()
