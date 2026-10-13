# ELI VR and ELI v3

ELI VR runs on its own. Nothing in it starts, installs or needs ELI.

When ELI v3 is running on the same machine and the link is switched on, ELI is present in the rooms: you can see which room he is in, how he is, and talk to him. Everything stays on `127.0.0.1`.

Needs an ELI v3 that has the world feed (`/v1/world/*` on its local server): 3.0.131 or newer for presence and talking, and one that speaks world protocol 2 (newer than 3.0.133) for building, his own room, his mind and his knowing where he is.

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

**ELI's presence.** A body of light in the room ELI's own world puts him in. ELI v3 decides that from his state: unsure of his evidence, he goes to the Anomaly Room; repairing, to the Debug Basement; using tools, to the Workshop; building, to the room he is building in. When he is in another room the status line says where. Doubt warms the light, repair work reddens it.

**Talking to him.** Hold **A** or **X** on a controller, or **T** on the keyboard, speak, and let go. Your words go to ELI's own speech-to-text, his reply comes back as text and as his voice from where he stands, and he comes to your room for a minute. The microphone is only open while the button is held.

**He knows where he is.** Every few seconds, and just before you speak, ELI VR tells ELI the scene: the room and what that place is, where you are standing and which way you face, what you are looking at (him, one of his things, the desktop screen), whether he is in the room and how far away, and what of his is near. ELI keeps that in memory only while it is fresh, and while it is, his prompt carries a few plain lines saying so. Nothing of it is written down, and it stops when you leave.

**He can build.** A sentence that asks for the place to be changed is his to carry out: make a thing, move it, change its colour, size or glow, take it away, undo. What he makes comes up out of the floor. You can grab it and move it, and ELI is told where you put it.

**He has a room of his own.** ELI'S ROOM on the console. Open ground under an open sky, with nothing in it but what he has made. There he may also change the sky (stars, dawn, mist, sunset, void), the ground (stone, marble, wood, sand, snow, moss, metal, dark), the colour of the light and the mist. ELI: BUILD on the console (or `B`) has him make one thing there of his own accord, with a meaning he gives it; UNDO (or `Z`) takes the last change back.

## His mind

No model is assumed anywhere. ELI v3 says which model is loaded, which would be used if none is, and which he has; ELI VR shows that and lets you choose.

| How ELI VR was started | Which model answers |
|---|---|
| From ELI v3's window (Bundles menu) | The one loaded in that window. ELI v3 serves ELI VR from that same process, so nothing is loaded twice |
| On its own, or from ELI v3's start-up question, and ELI already has a model in memory | That one |
| The same, and nothing is loaded yet | The model kept in ELI VR's settings (`eli_bridge.model`), if you kept one; otherwise whichever ELI v3 used last, and the status line says nobody chose it |
| With `--eli-model=<name>` | That one, for this run |

In the room, the **ELI'S MIND** panel lists his models with their sizes; `>` marks the one loaded, `~` the one that would be used. Pressing another has him load it and keeps it as ELI VR's choice. Choosing a model here is choosing ELI's model: it is the same setting his own window changes. Names are shown, never the folders they are in.

How well he fits the model beside VR is ELI v3's own loader's work; if it does not load, the status line says why.

## Anything at all, and of his own accord

**A thing need not come from a list.** Beside the sixteen named shapes, a thing can be made part by part, up to twenty-four parts: box, ball, cylinder, cone, torus, capsule, prism, a lathe (a profile of `[radius, height]` points turned round), an extrude (an outline pulled up into a solid), a tube (along a path of points), text. Each part has its own place, turn, size, colour, metal, roughness, glow, clearness, and may spin, bob or pulse.

**Nor need the room.** In his own room the sky can be one by name or painted: `sky_top`, `sky_horizon`, `stars`, and a `sun` with a height, a bearing, a colour and a size. The ground can be any colour, and `terrain` raises it into hills round the flat middle.

A model of three billion parameters or more is offered all of this. A smaller one is held to the named shapes: it can manage those, and free parts from a very small model are noise. `ELI_WORLD_FREEFORM=1` or `0` on ELI v3 overrides the judgement.

**What he makes unasked comes from him.** Nothing runs on a timer of its own and nothing picks for him.

1. When something happens in ELI that has words (an insight is synthesised, a goal is taken on or closed, he proposes an improvement to himself) the event already passes through his world. It is kept there as an *urge*: the moment, in its own words, with where it came from.
2. When he is free (a model already in memory, nobody waiting on him, your mood not asking him to hold back) ELI v3's own background loop lets him answer one. A model is never loaded for this.
3. He is given what is truly on his mind, from his records: his persona in his own words, his latest insight, his goals, his recent memories, his tone, his own measures of himself. Then the moment. What he makes of it is his: a thing, a change, a new sky, or nothing.
4. What he makes is linked to the record it came from and written in his world's journal with the reason. If he gives no meaning of his own, the moment's words are the meaning.

ELI: BUILD asks him now: the oldest urge if one is waiting, otherwise simply what is on his mind. He may make nothing.

**His records in his rooms.** The Memory Archive carries his real recent memories as lights, each with its words; the Upgrade Bay carries the goals he holds now. They are read from his memory and goal store, refreshed every half minute. You can pick one up; moving it changes nothing in him.

## How building works

ELI VR draws; ELI v3 decides and remembers. The split is the same as for his presence.

1. Your sentence goes to `POST /v1/world/say`. If it reads as a request about the place, ELI v3 composes edits; otherwise it is an ordinary turn of conversation.
2. One call to whichever GGUF is loaded gives what he says and the edits. The model is held to that exact shape by a grammar, so it cannot invent an operation, name a shape that does not exist or change a thing that is not there. Nothing depends on a model's own tool-calling format.
3. What you plainly said is not left to the model: "undo" is done directly; a colour, shape or size you named is what the thing gets; "behind me", "to my left", "next to the lantern" are worked out from where you and the things actually are; and "the orb" when there is no orb is answered "There is no orb here."
4. Each edit becomes one of his world's own actions, judged by its policy and kept in its provenance ledger with who asked. It is applied to his world state.
5. The world feed carries the result to ELI VR, which draws it.

If nothing changed, he says so, whatever the model claimed.

**With a very small model** (tried with a 0.6B one) every plain request in the list above does the right thing. Its spoken sentences are clumsy, its names are plain, and what it makes unasked is simple. A larger model is better at all three; the building itself is the same.

Sixteen shapes: orb, pillar, block, slab, arch, ring, crystal, tree, lamp, board, cone, stair, table, seat, pool, beacon. Positions are metres from the middle of the room's floor, `[right, up, forward]`. Sixty things to a room.

## What moves between them

The world protocol has versions and they are agreed, not assumed. On connecting, ELI VR says which versions it speaks (1 and 2) and what it would like; ELI v3 answers with the one both have, or with a refusal that says why. An ELI v3 from before that (3.0.131 to 3.0.133) never answers, and is spoken to in version 1.

| Version | What it carries |
|---|---|
| 1 | His room, avatar state, awareness and world objects; you entering a room. Presence and talking |
| 2 | All of 1, and: how each thing looks and where it stands, his own room and its sky and ground, the last things he did and why; the scene; sentences; edits by hand; undo |

| Direction | Route on ELI v3 | What | Version |
|---|---|---|---|
| ELI → VR | `WS /v1/world/ws` | The world state, again whenever it changes | 1 |
| VR → ELI | same socket | `hello` with versions and capabilities; `vr_session_started`, `vr_room_entered` | 1 |
| VR → ELI | `POST /v1/voice/stt` | The clip you recorded while holding the talk button | 1 |
| VR → ELI | `POST /v1/chat` | What you said, as text, when ELI v3 only has version 1 | 1 |
| ELI → VR | `POST /v1/voice/tts` | His answer, as speech | 1 |
| VR → ELI | `POST /v1/world/scene` | What you and he can see now | 2 |
| VR → ELI | `POST /v1/world/say` | What you said: he answers, or builds | 2 |
| VR → ELI | `POST /v1/world/edit` | A thing you moved by hand | 2 |
| VR → ELI | `POST /v1/world/compose` | ELI: BUILD | 2 |
| VR → ELI | `POST /v1/world/undo` | UNDO | 2 |
| ELI → VR | `GET /v1/world/mind` | Which model is loaded, and which he has, by name | 2 |
| VR → ELI | `POST /v1/world/mind` | The model you chose | 2 |

A turn is the owner's. ELI VR is a surface of yours, not another user: it sends a session id and its surface name, never a user of its own, so what you say in a headset is in the same conversation and memory as what you say anywhere else.

A version 2 world message, shortened:

```json
{
  "type": "eli_world_state",
  "version": 2,
  "room": "own_room",
  "avatar": { "name": "ELI", "room": "own_room", "activity": "building" },
  "awareness": { "focus": 0.9, "uncertainty": 0.1 },
  "objects": [
    { "id": "built_lantern_1a2b3c4d", "name": "Lantern", "kind": "built", "room": "own_room",
      "meaning": "a light left on", "made_by": "eli",
      "form": { "shape": "lamp", "colour": "#f5b942", "size": 1.0, "glow": 0.8, "pos": [1.0, 0.0, 3.0] } }
  ],
  "own_room": "own_room",
  "spaces": { "own_room": { "name": "ELI's Room",
              "mood": { "sky": "dawn", "ground": "moss", "light": "#f5b942", "mist": 0.15 } } },
  "recent": [ { "what": "create_object", "who": "eli", "room": "own_room", "why": "Asked for by the user.", "allowed": true } ]
}
```

## When something goes wrong

A failure has a kind, and the status line and the line under ELI say which:

| Shown | Meaning |
|---|---|
| ELI is not running | Nothing answers on his port |
| ELI refused the token | He wants a token, or the one in `ELI_VR_TOKEN` is wrong |
| ELI has no model loaded | The server is up but no GGUF is |
| ELI did not catch that | Speech-to-text heard nothing it could use |
| ELI took too long to answer | The request timed out |
| ELI answered, but his voice is not available | The reply came; text-to-speech did not |
| This ELI v3 is older: presence and talking only | Version 1 was agreed, so no building |
| This ELI speaks world protocol …; the client offered … | No version in common, in his own words |

## Settings

| Key | Default | Meaning |
|---|---|---|
| `eli_bridge.enabled` | `false` | The link |
| `eli_bridge.endpoint` | `http://127.0.0.1:8081` | ELI v3's local server. 8081 is ELI's default port; if you moved it in ELI's settings, change this to match, or set `ELI_API_PORT`. Only loopback addresses are accepted. |
| `eli_bridge.voice` | `true` | Push to talk |
| `eli_bridge.model` | empty | A model of ELI's, by name, to ask for when he has nothing loaded yet. Empty: whichever he has |
| `eli_bridge.token_env` | `ELI_VR_TOKEN` | Name of an environment variable holding ELI's API token, if you set one |

## Opened from ELI v3: ELI VR as a bundle

ELI v3 lists the ELI applications installed beside it, its *bundles*, and opens them: it asks at start-up, there is a Bundles menu in its window, and `eli --bundle vr` on the command line. ELI VR is a bundle the same way ELI Legal is. The contract is ELI v3's (`eli/bundles`, and `docs/BUNDLES.md` there); ELI VR's side of it is the small Python package in `src/eli_vr/`.

There are two ways ELI v3 can find ELI VR.

| How | Do this once | Runs |
|---|---|---|
| **Registered.** ELI VR is installed on its own: the AppImage, a release folder, a checkout. | `--register-eli` on the AppImage or `./launch/eli-vr.sh`, or `python3 tools/register_eli_bundle.py` | As its own program, started by ELI v3 |
| **Installed beside ELI v3.** The Python package is in ELI v3's own environment. | `pip install -e /path/to/ELI_VR` in that environment | Started from inside ELI v3's process |

Registering writes one file, `vr.json`, into the `bundles` folder of ELI v3's data, and keeps a note of where this copy is, and its icon, in ELI VR's own config folder. `--show` prints what would be written and writes nothing; `--remove` (or `--unregister-eli`) takes it back. The installed package advertises itself under the `eli.bundles` entry point and needs nothing written. If both are there, ELI v3 uses the installed one.

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

- ELI is a light, not a figure.
- He builds from parts and colours, not yet from textures or pictures of his own, and only his own room can be given a new sky.
- A very small model keeps to the named shapes, says little worth hearing about what it made, and unasked often makes nothing. That is the model, not a rule.
- Free parts and a painted sky have been drawn from edits sent by hand. No model large enough to be offered them has been tried yet.
- His building of his own accord has been tested with ELI v3's own engine and a stand-in for the model, not yet left running over days.
- The Evidence Wall does not yet show his real claims, nor the Anomaly Room his open contradictions.
- Talking and building have been tried flat against ELI v3's real server, not yet with a real microphone in the headset.
- Opening ELI VR from ELI v3 has been tested with ELI v3's own launch code and a stand-in for the app, not yet into a headset.
- Licences do not carry editions yet, so ELI v3 allows every bundle.
