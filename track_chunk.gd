extends StaticBody3D

# Loaded at spawn time — missing paths are skipped gracefully
const OBSTACLE_PATHS: Array[String] = [
	"res://obstacle_jump.tscn",
	"res://obstacle_jump.tscn",    # double weight → ~40% spawn rate
	"res://obstacle_slide.tscn",
	"res://obstacle_slide.tscn",   # double weight → ~40% spawn rate
	"res://obstacle_wide.tscn",
]
const LANE_POSITIONS: Array[float] = [-3.0, 0.0, 3.0]
const CHUNK_LENGTH: float = 20.0
const DELETE_BUFFER: float = 30.0   # units behind player before deletion

# The chunk root sits at y=-0.1 (main.gd) so the floor top lands at y=0.
# Obstacles are authored against world y=0, so lift them back by the same amount.
const FLOOR_TOP_LOCAL: float = 0.1

const ROAD_COLOR_A: Color = Color(0.16, 0.17, 0.22)
const ROAD_COLOR_B: Color = Color(0.13, 0.14, 0.19)
const STRIPE_COLOR: Color = Color(0.95, 0.93, 0.72)
const CURB_COLOR: Color = Color(0.85, 0.28, 0.32)
const VERGE_COLOR: Color = Color(0.10, 0.34, 0.16)
const SCENERY_COLOR: Color = Color(0.09, 0.26, 0.14)

var player: CharacterBody3D = null

func setup(player_ref: CharacterBody3D, grace: bool = false, index: int = 0) -> void:
	player = player_ref
	_apply_materials(index)
	_spawn_scenery(index)
	if not grace:
		_spawn_obstacle()

func _process(_delta: float) -> void:
	# Delete this chunk when it's sufficiently behind the player
	if player and global_position.z > player.global_position.z + DELETE_BUFFER:
		queue_free()

func _apply_materials(index: int) -> void:
	# Alternating road tint gives a sense of speed without scrolling textures.
	var road := ROAD_COLOR_A if index % 2 == 0 else ROAD_COLOR_B
	$MeshInstance3D.material_override = _make_mat(road, 0.8)
	$Verge.material_override = _make_mat(VERGE_COLOR, 0.95)
	var stripe := _make_mat(STRIPE_COLOR, 0.35, 0.5)
	$StripeL.material_override = stripe
	$StripeR.material_override = stripe
	var curb := _make_mat(CURB_COLOR, 0.5, 0.3)
	$CurbL.material_override = curb
	$CurbR.material_override = curb

func _make_mat(color: Color, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _spawn_scenery(index: int) -> void:
	# ponytail: box "trees" keep the world readable with zero art assets.
	# Upgrade path: swap the BoxMesh for an imported model + MultiMeshInstance3D.
	var mat := _make_mat(SCENERY_COLOR, 0.9)
	for i in range(4):
		var side: float = -1.0 if (index + i) % 2 == 0 else 1.0
		var trunk_h: float = randf_range(2.5, 5.5)
		var tree := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.8, 1.6), trunk_h, randf_range(0.8, 1.6))
		tree.mesh = mesh
		tree.material_override = mat
		tree.position = Vector3(
			side * randf_range(6.5, 11.0),
			FLOOR_TOP_LOCAL + trunk_h / 2.0,
			randf_range(-CHUNK_LENGTH * 0.5, CHUNK_LENGTH * 0.5)
		)
		add_child(tree)

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
	if "wide" in path:
		# Place at midpoint between two adjacent lanes (covers both, one lane stays free)
		var pair: int = randi() % 2    # 0 = left+center, 1 = center+right
		lane_x = (LANE_POSITIONS[pair] + LANE_POSITIONS[pair + 1]) / 2.0
	else:
		lane_x = LANE_POSITIONS[randi() % LANE_POSITIONS.size()]

	# Offset into the back half of the chunk so player has reaction time
	var z_local: float = randf_range(-CHUNK_LENGTH * 0.45, -CHUNK_LENGTH * 0.25)
	obstacle.position = Vector3(lane_x, FLOOR_TOP_LOCAL, z_local)
	add_child(obstacle)
