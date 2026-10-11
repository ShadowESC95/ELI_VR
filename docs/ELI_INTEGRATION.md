# Future ELI v3 integration

This standalone alpha does not launch, embed, import or modify ELI.

The intended future contract is a local bridge that sends semantic state, not internal implementation files.

Example future message:

```json
{
  "type": "eli_world_state",
  "room": "workshop",
  "objects": [
    {
      "id": "project_workbench",
      "kind": "workbench",
      "status": "active"
    }
  ],
  "widgets": {
    "task": "Build ELI VR",
    "confidence": 0.88
  }
}
```

ELI VR can then:

- move the user's world to a requested room;
- render ELI world objects spatially;
- display evidence/status widgets;
- show tasks, memories, simulation state or tool activity.

The integration boundary is `FutureEliBridge`.

No ELI v2 or v3 source files are included in this standalone project.
