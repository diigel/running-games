# RunningGames

**RunningGames** is a simple 3D endless runner prototype built with **Godot** and **GDScript**. The player runs forward automatically, avoids obstacles, switches between lanes, jumps, slides, and tries to survive as long as possible while collecting score based on distance.

## Gameplay Overview

The main objective of the game is to keep running without hitting obstacles. The game becomes more challenging over time because the running speed gradually increases. When the player collides with an obstacle, the game stops and the final score is shown on the HUD.

## Features

- 3D endless runner gameplay
- Three-lane player movement
- Jump and slide mechanics
- Procedural track chunk spawning
- Random obstacle placement
- Multiple obstacle types:
  - High obstacle
  - Low obstacle
  - Double-lane obstacle
- Dynamic speed increase over time
- Distance-based score system
- Game over screen
- Restart button
- Simple HUD for score display

## Tech Stack

- **Engine:** Godot 4.6
- **Language:** GDScript
- **Renderer:** Forward Plus
- **Physics:** Jolt Physics 3D

## Project Structure

```text
running-games/
├── project.godot              # Godot project configuration
├── main.tscn                  # Main game scene
├── main.gd                    # Game manager, speed, score, camera, and chunk spawning
├── player.tscn                # Player scene
├── player.gd                  # Player movement, lane switch, jump, and slide logic
├── hud.tscn                   # HUD scene
├── hud.gd                     # Score display, game over panel, and restart logic
├── track_chunk.tscn           # Track segment scene
├── track_chunk.gd             # Track cleanup and obstacle spawning logic
├── obstacle.gd                # Obstacle collision and visual color logic
├── obstacle_high.tscn         # High obstacle scene
├── obstacle_low.tscn          # Low obstacle scene
├── obstacle_double.tscn       # Double-lane obstacle scene
├── icon.svg                   # Project icon
└── README.md                  # Project documentation
```

## Controls

The project uses Godot's built-in input actions.

| Action | Function |
|---|---|
| `ui_left` | Move to the left lane |
| `ui_right` | Move to the right lane |
| `ui_accept` | Jump |
| `ui_down` | Slide |

You can customize the input keys from **Project > Project Settings > Input Map** inside the Godot editor.

## How to Run

### 1. Clone the Repository

```bash
git clone https://github.com/diigel/running-games.git
cd running-games
```

### 2. Open in Godot

1. Open **Godot 4.6**.
2. Click **Import**.
3. Select the `project.godot` file from this repository.
4. Open the project.
5. Press **F5** or click the **Run Project** button.

### 3. Run from CLI

If Godot is available from your terminal PATH, you can run the project with:

```bash
godot --path . --play
```

## How the Game Works

### Main Game Manager

`main.gd` controls the core gameplay loop. It handles player speed, score calculation, camera follow behavior, track chunk spawning, and game-over state.

### Player Controller

`player.gd` manages the player character. The player can move between three lanes, jump over obstacles, and slide under obstacles. Movement is handled through `CharacterBody3D` physics.

### Track System

`track_chunk.gd` creates the endless runner effect by spawning new track chunks ahead of the player and deleting old chunks once they are behind the player. Obstacles are placed randomly on each chunk after the initial grace chunks.

### Obstacles

`obstacle.gd` handles collision detection. When the player enters an obstacle area, the obstacle notifies the game manager and triggers the game-over flow.

### HUD

`hud.gd` updates the score during gameplay, displays the game-over screen, shows the final score, and provides a restart button.

## Development Notes

This project is still an early prototype. The current focus is on core endless runner mechanics such as player movement, obstacle spawning, scoring, and restart flow.

Possible future improvements:

- Add character model and environment assets
- Add sound effects and background music
- Add main menu and pause menu
- Add high score saving
- Add coins or collectible items
- Add more obstacle variations
- Add mobile touch controls
- Add difficulty balancing
- Add export presets for Windows, Linux, macOS, Android, or Web

## Build / Export

Before exporting, configure export presets from the Godot editor:

1. Open **Project > Export**.
2. Add the target platform.
3. Configure the export settings.
4. Export the game.

Example CLI export after presets are configured:

```bash
godot --path . --export-release "Windows Desktop" ./build/RunningGames.exe
```

## License

No license has been specified yet. Consider adding a `LICENSE` file if this project will be shared publicly or used by other developers.

## Author

Created by [diigel](https://github.com/diigel).
