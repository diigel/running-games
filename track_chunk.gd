extends StaticBody3D

# Loaded at spawn time — missing paths are skipped gracefully
const OBSTACLE_PATHS: Array[String] = [
	"res://obstacle_high.tscn",
	"res://obstacle_low.tscn",
	"res://obstacle_double.tscn",
]
const LANE_POSITIONS: Array[float] = [-3.0, 0.0, 3.0]
const CHUNK_LENGTH: float = 20.0
const DELETE_BUFFER: float = 30.0   # units behind player before deletion

var player: CharacterBody3D = null


func setup(player_ref: CharacterBody3D, grace: bool = false) -> void:
	player = player_ref
	if not grace:
		_spawn_obstacle()


func _process(_delta: float) -> void:
	# Delete this chunk when it's sufficiently behind the player
	if player and global_position.z > player.global_position.z + DELETE_BUFFER:
		queue_free()


func _spawn_obstacle() -> void:
	# Only use scene paths that actually exist (safe during incremental dev)
	var available: Array[String] = []
	for path in OBSTACLE_PATHS:
		if ResourceLoader.exists(path):
			available.append(path)
	if available.is_empty():
		return

	var path: String = available[randi() % available.size()]
	var obstacle: Node3D = (load(path) as PackedScene).instantiate()

	var lane_x: float
	if "double" in path:
		# Place at midpoint between two adjacent lanes (covers both)
		var pair: int = randi() % 2    # 0 = left+center, 1 = center+right
		lane_x = (LANE_POSITIONS[pair] + LANE_POSITIONS[pair + 1]) / 2.0
	else:
		lane_x = LANE_POSITIONS[randi() % LANE_POSITIONS.size()]

	# Offset into the back half of the chunk so player has reaction time
	var z_local: float = randf_range(-CHUNK_LENGTH * 0.35, CHUNK_LENGTH * 0.1)
	obstacle.position = Vector3(lane_x, 0.0, z_local)
	add_child(obstacle)
