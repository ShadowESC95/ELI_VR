# Settings

All default settings live in `config/defaults.json`.

## XR

| Key | Default | Purpose |
|---|---:|---|
| `xr.mode` | `auto` | `auto`, `on`, or `off` |
| `xr.render_scale` | `1.0` | OpenXR render target multiplier |
| `xr.snap_turn_degrees` | `30` | snap turn angle |
| `xr.smooth_locomotion` | `true` | left-stick movement |
| `xr.move_speed` | `2.0` | metres/second |
| `xr.turn_cooldown_seconds` | `0.30` | snap-turn repeat delay |

## Graphics

| Key | Default |
|---|---|
| `graphics.quality` | `medium` |
| `graphics.shadows` | `true` |
| `graphics.fog` | `true` |
| `graphics.particles` | `true` |
| `graphics.world_detail_scale` | `1.0` |

Quality profiles live under `config/profiles/`.

## World

| Key | Default |
|---|---|
| `world.room` | `core_room` |
| `world.environment_override` | empty |
| `world.theme` | `cyan` |
| `world.portals` | `true` |
| `world.spatial_console` | `true` |

An empty `environment_override` means the symbolic room chooses its normal environment.

## Desktop

| Key | Default |
|---|---:|
| `desktop.enabled` | `true` |
| `desktop.bridge_host` | `127.0.0.1` |
| `desktop.bridge_port` | `47831` |
| `desktop.bridge_fps` | `15` |
| `desktop.bridge_width` | `1600` |
| `desktop.jpeg_quality` | `72` |
| `desktop.distance_m` | `3.6` |
| `desktop.width_m` | `5.2` |
| `desktop.height_m` | `2.925` |
| `desktop.vertical_offset_m` | `1.7` |

`desktop.curvature_reserved` and `desktop.interactive_input_reserved` are intentionally present for the later production desktop bridge.

## ELI link

`eli_bridge.enabled` is false by default: ELI VR runs on its own.

Switch it on to have ELI v3 present in the rooms and to talk to him. See [ELI_INTEGRATION.md](ELI_INTEGRATION.md) for the settings and what moves between the two.

## Network

Standalone 0.2.1 defaults:

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

`ONLINE` is intentionally not implemented by the standalone application.
