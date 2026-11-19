"""The fields ELI VR's knowledge rooms read from ELI v3's world message, held against ELI v3's own
contract for it (tests/fixtures/world_feed_v2_contract.json, copied from ELI v3; see the README there).
A field ELI VR reads that the contract does not name, or names with another shape, fails here before
it fails in a room."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent / "fixtures"

# shape -> field -> the shapes ELI VR reads it as (any of them). "?" marks a field ELI VR knows may be
# left out. The readers are named so a change there is changed here too.
READ = {
    # EliBook, Bookcase, the Archive's and ELI's room's arrange()
    "book_object": {"id": {"str"}, "kind": {"str"}, "room": {"str"}, "name": {"str"}, "meaning": {"str"},
                    "when": {"number|null", "number"}, "importance": {"number"}, "form": {"form"}, "book": {"book"}},
    "book": {"of": {"str"}, "title": {"str"}, "spine": {"str"}, "about": {"str"}, "from": {"number|null"},
             "to": {"number|null"}, "length": {"int"}, "?shelf": {"str"}, "?by": {"str"}, "?fiction": {"bool"},
             "?drawn_from": {"array<str>"}, "?sections": {"array<section>"}, "?applies_to": {"str"},
             "?change": {"str"}},         # EvidenceSheet.of_lesson: what a lesson says to do, whole
    "section": {"heading": {"str"}, "text": {"str"}},
    # EliThing's belief sheet, EvidenceSheet.of_claim, the wall's arrange() and its exhibits
    "claim_object": {"id": {"str"}, "name": {"str"}, "kind": {"str"}, "room": {"str"}, "importance": {"number"},
                     "meaning": {"str"}, "claim": {"claim"}, "form": {"form"}},
    "claim": {"relation": {"str"}, "value": {"str"}, "chance": {"number"}, "since": {"number|null"},
              "learned": {"number|null"}, "basis": {"str"}, "contested": {"bool"}, "status": {"str"},
              "sources": {"array<claim_source>"}},
    "claim_source": {"id": {"str"}, "text": {"str"}, "when": {"number|null"}, "origin": {"str"}},
    # EvidenceSheet.of_conflict and the wall's questions
    "conflict_object": {"name": {"str"}, "kind": {"str"}, "relation": {"str"}, "meaning": {"str"}, "form": {"form"}},
    # the Archive's memories, face out
    "memory_object": {"name": {"str"}, "kind": {"str"}, "room": {"str"}, "meaning": {"str"}, "?when": {"number"},
                      "form": {"form"}},
    # EvidenceSheet.of_thought, EliReadout.thought_lines
    "thought": {"kind": {"str"}, "room": {"str"}, "what": {"str"}, "why": {"array<str>"}, "chance": {"number|null"},
                "decision": {"str"}, "reason": {"str"}, "status": {"str"}, "outcome": {"str"}, "when": {"number"},
                "subject": {"str"}},
    # the scoreboard (EvidenceStudioRoom.score_lines, _weeks) and EvidenceSheet.of_action
    "evidence": {"?actions": {"actions"}, "?accuracy": {"array<accuracy>"}, "?wall": {"array<wall_entry>"}},
    # what goes up on the wall of sheets and in what order (EvidenceStudioRoom._as_sent, _once)
    "wall_entry": {"ref": {"str"}, "kind": {"str"}, "also": {"array<str>"}},
    "actions": {"rows": {"array<action>"}},
    "action": {"id": {"str"}, "action": {"str"}, "name": {"str"}, "n": {"int"}, "ok": {"int"}, "causes": {"array<cause>"},
               "last": {"number"}, "weeks": {"array<action_week>"}, "instead": {"array<instead>"}},
    "cause": {"words": {"str"}, "n": {"int"}},
    "action_week": {"n": {"int"}, "ok": {"int"}},
    "instead": {"name": {"str"}, "n": {"int"}},
    # the charts (EvidenceStudioRoom._draw_charts) and EvidenceSheet.of_accuracy
    "accuracy": {"id": {"str"}, "kind": {"str"}, "words": {"str"}, "n": {"int"}, "right": {"number|null"}, "ece": {"number|null"},
                 "weeks": {"array<accuracy_week>"}},
    "accuracy_week": {"from": {"number"}, "n": {"int"}, "right": {"number|null"}},
    "form": {"shape": {"str"}, "colour": {"str"}, "pos": {"array<number>"}},
}
# what ELI VR asks for in its hello (EliLink.WANTS) and its rooms read from the "can" they are given
CAPABILITIES = {"books", "evidence", "kept-records"}
# where the rooms look for them in the message
MESSAGE = {"objects": "array<object>", "thoughts": "array<thought>", "evidence": "evidence"}


class Contract(unittest.TestCase):
    contract: dict = {}
    example: dict = {}

    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads((FIXTURES / "world_feed_v2_contract.json").read_text(encoding="utf-8"))
        cls.example = json.loads((FIXTURES / "world_feed_v2_example.json").read_text(encoding="utf-8"))

    def test_every_field_the_rooms_read_is_in_elis_contract_with_the_shape_they_read(self) -> None:
        shapes = self.contract["shapes"]
        wrong = []
        for shape, fields in READ.items():
            given = shapes.get(shape)
            if given is None:
                wrong.append(f"{shape}: not in the contract")
                continue
            for field, wanted in fields.items():
                name = field.lstrip("?")
                key = name if name in given else ("?" + name if "?" + name in given else None)
                if key is None:
                    wrong.append(f"{shape}.{name}: not in the contract")
                elif given[key] not in wanted:
                    wrong.append(f"{shape}.{name}: the contract says {given[key]}, ELI VR reads {sorted(wanted)}")
                elif key.startswith("?") and not field.startswith("?"):
                    wrong.append(f"{shape}.{name}: the contract may leave it out, ELI VR counts on it")
        self.assertEqual(wrong, [])

    def test_the_rooms_find_the_records_where_the_contract_puts_them(self) -> None:
        self.assertEqual({k: self.contract["message"].get(k) for k in MESSAGE}, MESSAGE)
        self.assertTrue(CAPABILITIES <= set(self.contract["capabilities"]))
        self.assertEqual({k: self.contract["object_shapes"][k] for k in ("book", "claim", "conflict", "memory")},
                         {"book": "book_object", "claim": "claim_object", "conflict": "conflict_object", "memory": "memory_object"})
        link = (Path(__file__).resolve().parents[1] / "scripts" / "eli" / "eli_link.gd").read_text(encoding="utf-8")
        self.assertTrue(all(f'"{c}"' in link.split("const WANTS", 1)[1].split("]", 1)[0] for c in CAPABILITIES))

    def test_the_example_has_every_kind_of_record_the_rooms_show(self) -> None:
        kinds = {(o["kind"], o.get("room")) for o in self.example["objects"]}
        for wanted in [("claim", "evidence_wall"), ("conflict", "anomaly_room"), ("memory", "memory_archive"),
                       ("book", "memory_archive"), ("book", "own_room"), ("book", "evidence_wall")]:
            self.assertIn(wanted, kinds)
        self.assertTrue(self.example["evidence"]["actions"]["rows"])
        self.assertTrue(self.example["evidence"]["accuracy"])
        self.assertTrue(self.example["thoughts"])


if __name__ == "__main__":
    unittest.main()
