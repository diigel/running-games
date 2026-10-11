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

A three-lane endless runner. `main.tscn` is the registered main scene.

- `player.gd` / `player.tscn` — `CharacterBody3D` with a `CollisionShape3D` and a
  `Model` instance of `res://models/player.glb`. Lanes, jump, slide, and clip
  playback live here.
- `models/player.glb` — the animated character (peci, baju koko, sarung,
  sandal jepit). **Generated, not hand-modelled.** Clips: `Idle`, `Run`,
  `Jump`, `Slide`.
- `blender/build_player.py` — the source of truth for that glb. Edit the
  constants there and re-export; never edit the glb directly.

### Rebuilding the character

```
blender --background --python-exit-code 1 --python blender/build_player.py
godot --path . --headless --import
```

`models/player.glb.import` pins `loop_mode: 1` on `Idle` and `Run`; re-adding
the glb from scratch loses that and the run cycle will freeze mid-stride.

The rig is modelled facing -Y in Blender and yawed 180 deg before export, so the
glb faces -Z in Godot — away from the chase camera.

### Headless caveats

- Scene-tree scripts: nodes added in `_initialize()` do not get `_ready()` (and
  so no `@onready`) until the first idle frame; resolve children in `_process`.
- `--headless` uses the dummy renderer, which has no framebuffer, so
  `Viewport.get_texture().get_image()` returns null. `tests/shot_player.gd`
  therefore runs windowed.

When adding new nodes/scripts, follow Godot conventions:
- Scripts extending Node types go alongside their `.tscn` scene files
- Attach scripts via the Godot editor (not manually creating `.uid` files)
- Use `res://` paths for all in-project resource references
