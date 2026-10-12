# ELI VR and ELI v3

ELI VR runs on its own. Nothing in it starts, installs or needs ELI.

When ELI v3 is running on the same machine and the link is switched on, ELI is present in the rooms: you can see which room he is in, how he is, and talk to him. Everything stays on `127.0.0.1`.

Needs an ELI v3 that has the world feed (`/v1/world/*` on its local server): 3.0.131 or newer.

ELI VR names no model and ships none. Whichever model ELI v3 has loaded answers, and speech goes through ELI v3's own recognition and voice.

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

## Opened from ELI v3: ELI VR as a bundle

ELI v3 lists the ELI applications installed beside it, its *bundles*, and opens them: it asks at start-up, there is a Bundles menu in its window, and `eli --bundle vr` on the command line. ELI VR is a bundle the same way ELI Legal is. The contract is ELI v3's (`eli/bundles`, and `docs/BUNDLES.md` there); ELI VR's side of it is the small Python package in `src/eli_vr/`.

There are two ways ELI v3 can find ELI VR.

| How | Do this once | Runs |
|---|---|---|
| **Registered.** ELI VR is installed on its own: the AppImage, a release folder, a checkout. | `--register-eli` on the AppImage or `./launch/eli-vr.sh`, or `python3 tools/register_eli_bundle.py` | As its own program, started by ELI v3 |
| **Installed beside ELI v3.** The Python package is in ELI v3's own environment. | `pip install -e /path/to/ELI_VR` in that environment | Started from inside ELI v3's process |

Registering writes one file, `vr.json`, into the `bundles` folder of ELI v3's data, and notes in ELI VR's own config folder where this copy is. `--show` prints what would be written and writes nothing; `--remove` (or `--unregister-eli`) takes it back. The installed package advertises itself under the `eli.bundles` entry point and needs nothing written. If both are there, ELI v3 uses the installed one.

```bash
python3 tools/register_eli_bundle.py            # register
python3 tools/register_eli_bundle.py --show     # see what it would write
python3 tools/register_eli_bundle.py --remove   # take it out
eli-vr bundle register                          # the same, with the package installed
eli-vr where                                    # which copy would be started, and how
```

### What happens when ELI v3 opens it

ELI Legal runs inside ELI v3 and calls the model directly. ELI VR is a Godot application and cannot, so it reaches ELI over his local server. Its description says `"needs": ["server"]`, and ELI v3 then:

1. uses its local server if it is already running, or starts one on `127.0.0.1` for as long as ELI VR is open;
2. tells ELI VR the port (`ELI_API_PORT`);
3. starts ELI VR with the link on, and waits for it to close.

On Linux ELI VR is started through its launcher, so the desktop helper comes up with it and the VR runtime it started is stopped again on exit. Options you keep in `~/.config/eli-vr/launch.conf` still apply.

ELI v3 3.0.131 has the world feed but does not start its server for a bundle. With it, switch ELI's server on first, or use the installed package, which starts the server itself.

Opened either way, ELI VR keeps its settings in its own folder, never ELI v3's, and running it on its own is unchanged.

### Finding the app

The installed package has to know where the application is:

| Variable | Meaning |
|---|---|
| `ELI_VR_HOME` | The ELI VR folder: a release folder or a checkout |
| `ELI_VR_APP` | One file to run instead, such as the AppImage |
| `GODOT_BIN` | Godot, for a checkout with no build in it |

Without them it uses the folder the package came with (`pip install -e`), then the place noted at the last registration.

### In ELI v3

ELI v3 carries an edition pack for ELI VR (`eli/editions/vr/`), the same shape as ELI Legal's: a manifest and policy hooks. It is a scaffold. Nothing in ELI VR depends on it; it is where what ELI can do in his rooms will go.

## Not there yet

- ELI's world objects are received but not placed in the rooms.
- ELI cannot build or change rooms.
- The presence is a light, not a figure.
- Talking has been tested against ELI v3's request and reply formats, not yet with a real microphone in the headset.
- Opening ELI VR from ELI v3 has been tested with ELI v3's own launch code and a stand-in for the app, not yet into a headset.
- Licences do not carry editions yet, so ELI v3 allows every bundle.
