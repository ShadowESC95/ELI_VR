# Local ELI VR room packs

This directory is for locally installed room/environment packs.

ELI VR 0.2.1 does not download packs itself.

Install a pack already present on the machine:

```bash
python3 tools/install_room_pack.py /path/to/ELIVR-room-pack.zip
```

Pack archives must contain exactly one `manifest.json`.

Example:

```json
{
  "schema": 1,
  "id": "mountain_deluxe",
  "name": "Mountain Deluxe",
  "version": "1.0.0",
  "author": "Local User",
  "environments": [
    {
      "id": "mountain_deluxe",
      "scene": "environment.tscn"
    }
  ]
}
```

The installer rejects URL input and only reads local files.
