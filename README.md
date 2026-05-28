# RunningGames

3D endless runner built with Godot 4.6. Prototype stage.

## Gameplay

The player runs automatically down a 3-lane track at increasing speed. Avoid obstacles by:

| Action | Input | Obstacle |
|---|---|---|
| Switch lane | ← → Arrow keys | Any obstacle in your lane |
| Jump | Space / ui_accept | `obstacle_high` (floor hurdle) |
| Slide | ↓ Arrow / ui_down | `obstacle_low` (overhead beam) |

Game over on obstacle hit. Score = distance traveled.

## Running

Everything is managed by the Godot editor — no custom build scripts.

```bash
# Open in editor
godot --path .

# Run headlessly
godot --path . --play

# Export (configure export presets first)
godot --path . --export-release "Windows Desktop" ./build/RunningGames.exe
```

## Project Config

| Setting | Value |
|---|---|
| Engine | Godot 4.6 |
| Rendering | Forward Plus |
| Physics | Jolt Physics 3D |
| Driver (Windows) | DirectX 12 (D3D12) |
| Language | GDScript |

## Architecture

```
main.tscn (GameManager)
├── Player          → player.tscn + player.gd
├── Camera3D        → fixed offset follow cam
├── TrackSpawner
│   └── TrackChunk  → track_chunk.tscn + track_chunk.gd  (pooled, 5 chunks ahead)
│       └── Obstacle → obstacle_*.tscn + obstacle.gd
├── DirectionalLight3D + WorldEnvironment
└── HUD             → hud.tscn + hud.gd
```

### Scripts

| File | Node | Responsibility |
|---|---|---|
| `main.gd` | Node | Speed scaling, chunk pool, camera, score, game over |
| `player.gd` | CharacterBody3D | 3-lane movement, jump, slide, gravity |
| `track_chunk.gd` | StaticBody3D | Floor mesh, single obstacle spawn per chunk |
| `obstacle.gd` | Area3D | Hit detection → calls `game_manager` group |
| `hud.gd` | CanvasLayer | Score label, game over panel, restart |

### Obstacle Types

| Scene | Type | Player Action | Clearance |
|---|---|---|---|
| `obstacle_high.tscn` | Floor hurdle (h=1.4) | Jump | Peak bottom 1.6 > top 1.4 |
| `obstacle_low.tscn` | Overhead beam (bottom=1.1) | Slide | Slide top 0.9 < bottom 1.1 |
| `obstacle_double.tscn` | Full-height wall × 2 lanes | Switch lane | Third lane always free |

Spawn weights: `obstacle_high` 50%, `obstacle_low` 25%, `obstacle_double` 25%.

### Player Physics

```
JUMP_FORCE  = 8.0       → peak height = 1.6 units
GRAVITY     = 20.0
SLIDE_HEIGHT = 0.9      → capsule shrinks for 0.9s
NORMAL_HEIGHT = 1.8

Lanes: x ∈ {-3, 0, 3}
Speed: -10 → -22 units/s (increments 0.05/s²)
```
