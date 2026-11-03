# Settings

Defaults are in `config/defaults.json`. What you change in the app is saved per user, outside the project ([where](INSTALL.md#where-your-settings-live)). In a checkout, `config/user.json` (copy `config/user.example.json`) overrides the defaults for that folder.

Change one from a terminal with `python3 tools/eli_vr.py set <key> <value>`, or for one run with the app options in [COMMANDS.md](COMMANDS.md#start).

## Headset

| Key | Default | Meaning |
|---|---|---|
| `xr.mode` | `auto` | `auto` uses a headset when an OpenXR runtime is active; `on` and `off` force it |
| `xr.render_scale` | `1.0` | Pixels given to the headset, as a multiple of what it asks for. Read when the session starts |
| `xr.foveation` | `auto` | `auto` uses it when the runtime can, `off` never |
| `xr.pause_when_unfocused` | `true` | Pause the world when the headset says the session lost focus |
| `xr.controller_rays` | `true` | Pointer rays from the controllers |
| `xr.smooth_locomotion` | `true` | Move with the left stick |
| `xr.move_speed` | `2.0` | Metres a second |
| `xr.fly_speed` | `5.0` | Metres a second in free flight |
| `xr.boost_multiplier` | `2.4` | Left stick click |
| `xr.universal_flight` | `true` | Free flight in every place, not only the open ones |
| `xr.snap_turn_degrees` | `30` | Snap turn angle |
| `xr.turn_cooldown_seconds` | `0.3` | Delay before a held stick turns again |

`xr.controller_calibration` holds the hand offsets the calibration gesture works out. Leave it to the gesture.

## Graphics

| Key | Default | Meaning |
|---|---|---|
| `graphics.quality` | `auto` | `low`, `medium`, `high`, `ultra`, or `auto`: a profile picked at start from this machine's CPU, memory and GPU type. The pick is not saved, so the same settings file works on another machine |
| `graphics.shadows` | `true` | Lights cast shadows |
| `graphics.fog` | `true` | Fog and haze |
| `graphics.particles` | `true` | Dust, snow, sparks and the like |
| `graphics.world_detail_scale` | `1.0` | How much moves and drifts in a room |

A profile sets the last four and the render scale together. The table is in [ADVANCED-PLATFORM-OPTIMIZATION.md](ADVANCED-PLATFORM-OPTIMIZATION.md); the files are `config/profiles/`.

## World

| Key | Default | Meaning |
|---|---|---|
| `world.room` | `core_room` | The room you start in |
| `world.environment_override` | empty | A place to use instead of the room's own. Empty means the room decides |
| `world.theme` | `frontier` | Colour of the lights: `frontier`, `obsidian`, `nebula`, `emerald`, `solar`, `abyssal`, `aurora`, `monolith` |
| `world.portals` | `true` | Doors between rooms |
| `world.spatial_console` | `true` | The control panels in the room |
| `world.object_manipulation` | `true` | Grab and move things |

## Desktop screen

| Key | Default | Meaning |
|---|---|---|
| `desktop.enabled` | `true` | Show the screen |
| `desktop.bridge_host` | `127.0.0.1` | Where the capture helper is. Loopback only |
| `desktop.bridge_port` | `47831` | Its port |
| `desktop.display_mode` | `auto` | `auto`: the headset runtime's own layer where it has one, else drawn in the room; `mesh`: always drawn in the room |
| `desktop.distance_m` | `0.0` | How far the screen stands from you; `0` is as far as the console's panels (`ui.console_distance_m`) |
| `desktop.scale` | `1.0` | Its size: `1` is one desktop pixel to one pixel of the display, as sharp as the display can show; `0.5` is half that size |
| `desktop.curve` | `1.0` | `1` curves it round you, `0` is flat |
| `desktop.yaw_deg` | `0.0` | Where it is round you, from straight ahead |
| `desktop.lift_deg` | `0.0` | How far above eye level its middle is |

Holding the screen with the grip changes the last five, and recentring the workspace sets the last two to where you are looking. Frame rate and capture width are the helper's (`ELI_VR_CAPTURE_FPS`, `ELI_VR_CAPTURE_WIDTH`, see [INSTALL.md](INSTALL.md#tuning)).

## Interface

| Key | Default | Meaning |
|---|---|---|
| `ui.desktop_dock` | `true` | The settings dock in the flat window (`F1`) |
| `ui.performance_hud` | `true` | Frame rate and state (`F3`) |
| `ui.wrist_menu` | `true` | The menu on your left wrist |
| `ui.console_distance_m` | `2.7` | How far the control panels stand |
| `ui.spatial_panels_grabbable` | `true` | Panels can be grabbed and moved |
| `ui.show_help_on_start` | `true` | Controls shown at start |

## Sound

| Key | Default | Meaning |
|---|---|---|
| `audio.enabled` | `true` | Room sound |
| `audio.ambient_volume_db` | `-18.0` | Its level |
| `audio.spatial_ui_volume_db` | `-10.0` | Level of button sounds |

## ELI link

| Key | Default | Meaning |
|---|---|---|
| `eli_bridge.enabled` | `false` | The link to ELI v3. Off: ELI VR runs on its own |
| `eli_bridge.endpoint` | `http://127.0.0.1:8081` | ELI v3's local server. Loopback only; the port a running ELI v3 says it serves on is used, and `ELI_API_PORT` overrides it |
| `eli_bridge.voice` | `true` | Push to talk |
| `eli_bridge.microphone` | (none) | The microphone to talk through, by the name the log prints (`ELI VR VOICE: listening through ...`). Without it: the one that last gave sound, else the headset's own, else the system's default, else the others; one that gives only digital silence is passed over in the same press |
| `eli_bridge.model` | empty | A model of ELI's, by name, asked for when ELI has nothing loaded yet. Empty means whichever ELI has |
| `eli_bridge.token_env` | `ELI_VR_TOKEN` | Name of an environment variable holding ELI's API token, if you set one |

More in [ELI_INTEGRATION.md](ELI_INTEGRATION.md).

## Network

```json
{
  "network": {
    "mode": "local_only",
    "allow_loopback": true,
    "allow_remote": false,
    "telemetry": false,
    "analytics": false,
    "sign_in": false,
    "cloud_sync": false,
    "auto_update": false,
    "remote_asset_downloads": false
  }
}
```

These are not switches to turn on. The app has no code for sign-in, telemetry, sync, updates or remote downloads; the block states what the build is, and `tools/network_audit.py` checks it. See [NETWORK-POLICY.md](NETWORK-POLICY.md).
