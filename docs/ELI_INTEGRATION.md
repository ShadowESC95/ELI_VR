# ELI VR and ELI v3

ELI VR runs on its own. Nothing in it starts, installs or needs ELI.

When ELI v3 is running on the same machine and the link is switched on, ELI is present in the rooms: you can see which room he is in, how he is, and talk to him. Everything stays on `127.0.0.1`.

Needs an ELI v3 that has the world feed (`/v1/world/*` on its local server).

## Switching it on

Start ELI v3's local server first (in ELI v3: `./scripts/eli_serve.sh`, or the server switch in its window). Then any one of:

```bash
python3 tools/eli_vr.py eli on                                # remembered, source checkout
./launch/run-linux.sh -- --eli-link=on                        # this run only
./launch/run-linux-monado-cv1-reference.sh --eli-link=on      # Rift CV1 launcher, this run only
./ELI-VR.x86_64 -- --eli-link=on                              # release build, this run only
```

Off again with `python3 tools/eli_vr.py eli off`. If ELI is not running, ELI VR says so on the status line and keeps trying quietly.

## What you get

**ELI's presence.** A body of light in the room ELI's own world puts him in. ELI v3 decides that from his state: unsure of his evidence, he goes to the Anomaly Room; repairing, to the Debug Basement; using tools, to the Workshop. When he is in another room the status line says where. Doubt warms the light, repair work reddens it.

**Talking to him.** Hold **A** or **X** on a controller, or **T** on the keyboard, speak, and let go. Your words go to ELI's own speech-to-text, his reply comes back as text and as his voice from where he stands, and he comes to your room for a minute. The microphone is only open while the button is held.

**He knows where you are.** ELI VR tells ELI's world when a session starts and which room you walk into. That is all it reports.

## What moves between them

| Direction | Route on ELI v3 | What |
|---|---|---|
| ELI → VR | `WS /v1/world/ws` | His room, avatar state, awareness and world objects, again whenever they change |
| VR → ELI | same socket | `vr_session_started`, `vr_room_entered` |
| VR → ELI | `POST /v1/voice/stt` | The clip you recorded while holding the talk button |
| VR → ELI | `POST /v1/chat` | What you said, as text |
| ELI → VR | `POST /v1/voice/tts` | His answer, as speech |

The world message looks like this:

```json
{
  "type": "eli_world_state",
  "version": 1,
  "room": "workshop",
  "avatar": { "name": "ELI", "room": "workshop", "activity": "repairing", "expression": "focused" },
  "awareness": { "focus": 0.9, "uncertainty": 0.1, "repair_pressure": 0.6 },
  "objects": [ { "id": "bench", "name": "Workbench", "kind": "workbench", "room": "workshop" } ],
  "widgets": { "activity": "repairing", "confidence": 0.8, "last_event": "ran the tests" }
}
```

World objects arrive but are not drawn yet.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `eli_bridge.enabled` | `false` | The link |
| `eli_bridge.endpoint` | `http://127.0.0.1:8081` | ELI v3's local server. 8081 is ELI's default port; if you moved it in ELI's settings, change this to match, or set `ELI_API_PORT`. Only loopback addresses are accepted. |
| `eli_bridge.voice` | `true` | Push to talk |
| `eli_bridge.token_env` | `ELI_VR_TOKEN` | Name of an environment variable holding ELI's API token, if you set one |

## As an ELI bundle

ELI v3 shows the bundles installed beside it and can start them. To put ELI VR on that list:

```bash
python3 tools/register_eli_bundle.py            # register
python3 tools/register_eli_bundle.py --show     # see what it would write
python3 tools/register_eli_bundle.py --remove   # take it out
```

It writes one file, `vr.json`, into the `bundles` folder of ELI v3's data. ELI then lists ELI VR when it starts and under its Bundles menu, and starts it with the link on. Standalone use is unchanged.

## Not there yet

- ELI's world objects are received but not placed in the rooms.
- ELI cannot build or change rooms.
- The presence is a light, not a figure.
- Talking has been tested against ELI v3's request and reply formats, not yet with a real microphone in the headset.
