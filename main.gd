extends Node

const CHUNK_SCENE: PackedScene = preload("res://track_chunk.tscn")

const START_SPEED: float = -10.0
const MAX_SPEED: float = -22.0
const SPEED_INCREMENT: float = 0.05    # units/s² — 240s to reach max speed
const CHUNK_LENGTH: float = 20.0
const CHUNKS_AHEAD: int = 5
const GRACE_CHUNKS: int = 2
const CAM_OFFSET: Vector3 = Vector3(0, 5, 8)
const CAM_LOOK_OFFSET: Vector3 = Vector3(0, 0, -5)

var current_speed: float = START_SPEED
var score: float = 0.0
var is_playing: bool = true
var chunks_spawned: int = 0
var next_chunk_z: float = 0.0

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Camera3D
@onready var track_spawner: Node3D = $TrackSpawner
@onready var hud = $HUD


func _ready() -> void:
	add_to_group("game_manager")
	# Pre-fill chunk pool ahead of player
	for _i in range(CHUNKS_AHEAD):
		_spawn_chunk()


func _process(delta: float) -> void:
	if not is_playing:
		return

	# Gradually increase speed (negative = forward in -Z)
	current_speed = max(MAX_SPEED, current_speed - SPEED_INCREMENT * delta)
	player.z_speed = current_speed

	# Score: accumulate distance equivalent
	score += abs(current_speed) * delta
	hud.update_score(int(score))

	# Camera follows player with fixed offset
	camera.global_position = player.global_position + CAM_OFFSET
	camera.look_at(player.global_position + CAM_LOOK_OFFSET, Vector3.UP)

	# Maintain chunk pool: spawn when fewer than CHUNKS_AHEAD are ahead
	var threshold: float = player.global_position.z - (CHUNK_LENGTH * CHUNKS_AHEAD)
	if next_chunk_z > threshold:
		_spawn_chunk()


func _spawn_chunk() -> void:
	var chunk: StaticBody3D = CHUNK_SCENE.instantiate()
	# y = -0.1 so the top surface (BoxMesh H=0.2, centered) sits at y=0
	chunk.position = Vector3(0.0, -0.1, next_chunk_z)
	next_chunk_z -= CHUNK_LENGTH
	track_spawner.add_child(chunk)
	chunk.setup(player, chunks_spawned < GRACE_CHUNKS)
	chunks_spawned += 1


func on_obstacle_hit() -> void:
	if not is_playing:
		return
	is_playing = false
	player.z_speed = 0.0
	player.velocity = Vector3.ZERO
	hud.show_game_over(int(score))
