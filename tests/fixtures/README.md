# ELI v3's world feed, as ELI VR's tests read it

`world_feed_v2_contract.json` and `world_feed_v2_example.json` are copied unchanged from ELI v3's
`tests/fixtures/` (branch `wave4/VRE_feed`, commit `5911af7d`), where `tests/test_world_spatial_feed.py`
checks every real world message against the contract and writes the example from real records
(`ELI_WRITE_WORLD_FIXTURES=1`). The example's records are invented test data, not anyone's own.

- `tests/test_world_feed_contract.py` checks that every field ELI VR's rooms read is in the contract
  with the shape ELI VR expects.
- `tests/gd/eli_screens_check.gd` builds the Evidence Wall, the Memory Archive and ELI's room headless
  from the example and checks what they show.

When ELI v3's contract changes, copy both files again from ELI v3 and run the tests.
