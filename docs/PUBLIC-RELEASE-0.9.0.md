# ELI VR 0.9.0 — ELI builds, and the rooms are his

With ELI v3 beside it, ELI now knows where he is, builds in the rooms from what you say, has a room of his own, and uses whichever model you choose. ELI VR still runs on its own, and with an older ELI v3 it still gives presence and talking.

![ELI's room: a sky he painted, and things made part by part](https://raw.githubusercontent.com/ShadowESC95/ELI_VR/main/docs/images/eli-room-freeform.jpg)

**Needs for the new parts:** an ELI v3 that speaks world protocol 2. That is ELI v3's `main` after 3.0.133; no ELI v3 release has it yet. With 3.0.131 to 3.0.133, ELI VR agrees version 1 and says so.

**How far it has been tried.** Flat, without a headset, against ELI v3's real server: building from sentences with a real and very small model (0.6B), the mind panel, and free-form things and a painted sky drawn from edits sent by hand. ELI's room was run in a Rift CV1 at 90 frames a second before the free-form work. Not yet tried: any of the building spoken into a headset, a model large enough to be offered free-form parts, changing model from inside the room, and ELI building of his own accord with a real model. Windows and macOS builds come from CI.

## His mind is your choice

No model is named or assumed.

- **Opened from ELI v3's window:** the model already loaded there answers. Nothing is loaded twice.
- **In the room:** the ELI'S MIND panel lists ELI's models by name. Press one and he loads it.
- **Before starting:** `--eli-model=<name>`, or `python3 tools/eli_vr.py model <name>` to keep it.

The status line always says which model he is using.

## He knows where he is

ELI is told the room and what the place is, where you stand, what you are looking at and what of his is near, for as long as you are there and no longer. Ask him "where are we".

## He builds

"Build me a tall red pillar." "Put a lamp to my left." "Make the pillar green and bigger." "Move it behind me." "Undo." Things rise out of the floor where you asked, and you can grab and move them. Every change goes through his world's own policy and ledger.

- **With any GGUF.** His answer is held to an exact grammar, and what you plainly said (a colour, a size, "behind me", "the orb" when there is none) is worked out without the model. A 0.6B model manages every plain request.
- **In any way he likes.** A thing is a named shape, or anything made part by part: boxes, balls, cones, rings, a lathe, an extruded outline, a tube along a path, text, each with its own colour, metal, glow, clearness and motion. A model of three billion parameters or more is offered this; a smaller one keeps to the named shapes.
- **If nothing changed, he says so,** whatever the model claimed.

## A room of his own

ELI'S ROOM on the console: open ground under an open sky, with nothing in it but what he has made. The sky is his, by name or painted from two colours, stars and a sun wherever he puts it. So is the ground: any colour, flat or rising into hills.

## Of his own accord

Nothing is scheduled and nothing is chosen for him. When something happens in him that has words (an insight, a goal taken on or finished, an improvement he proposes) the moment is kept. When he is free he may make something of it in his room, from his own records: his persona, his latest insight, his goals, his recent memories. What he makes is tied to the record it came from. He may also make nothing. ELI: BUILD asks him now.

## His records in his rooms

The Memory Archive holds his real recent memories as lights, each with its words. The Upgrade Bay holds the goals he has now.

## Under it

- The world protocol has versions, agreed on connecting, with a plain refusal when there is none in common.
- A failure says which failure it is: ELI is not running, he has no model loaded, he did not catch that, his voice is not available.
- What you say in the headset is your turn, in the same conversation and memory as anywhere else. ELI VR is a surface of yours, not another user.

## Known gaps

- ELI is a light, not a figure.
- A very small model keeps to named shapes, says little worth hearing about what it made, and unasked often makes nothing.
- Only his own room can be given a new sky.
- The Evidence Wall and Anomaly Room do not yet show his real claims. He cannot yet paint pictures of his own, and you are not yet told on arriving what he made while you were away.
- The desktop screen is still view only.
- Clean shutdown of the VR runtime is Linux only. No native app for standalone headsets, no VR on macOS, builds are not code-signed.
