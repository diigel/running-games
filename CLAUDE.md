# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**RunningGames** — Godot 4.6 3D game project, early prototype stage.

## Running & Building

This project has no custom build scripts — everything is managed by Godot.

```bash
# Open project in Godot editor
godot --path .

# Run the project headlessly (from CLI)
godot --path . --play

# Export (configure export presets in Godot editor first)
godot --path . --export-release "Windows Desktop" ./build/RunningGames.exe
```

## Project Configuration

- **Engine:** Godot 4.6, Forward Plus rendering
- **Physics:** Jolt Physics 3D
- **Rendering driver (Windows):** DirectX 12 (D3D12)
- **C# assembly:** RunningGames (C# support is configured, but GDScript is the active language)

## Architecture

The project is in bootstrap stage — a single player script with no game logic yet:

- `player.gd` — extends `MeshInstance3D`, lifecycle stubs only (`_ready`, `_process`)
- No scene files (`.tscn`) or resources (`.tres`) created yet
- No scenes are registered as main scene in `project.godot`

When adding new nodes/scripts, follow Godot conventions:
- Scripts extending Node types go alongside their `.tscn` scene files
- Attach scripts via the Godot editor (not manually creating `.uid` files)
- Use `res://` paths for all in-project resource references
