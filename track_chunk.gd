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
const ROAD_EDGE: float = 5.0   # outer face of the curb; scenery must stay beyond this
const CHUNK_LENGTH: float = 20.0
const DELETE_BUFFER: float = 30.0   # units behind player before deletion

# The chunk root sits at y=-0.1 (main.gd) so the floor top lands at y=0.
# Obstacles are authored against world y=0, so lift them back by the same amount.
const FLOOR_TOP_LOCAL: float = 0.1

# Kampung palette: dirt path flanked by grass and village houses.
const ROAD_COLOR_A: Color = Color(0.46, 0.35, 0.24)   # packed dirt
const ROAD_COLOR_B: Color = Color(0.42, 0.31, 0.21)   # alternating tint = speed cue
const STRIPE_COLOR: Color = Color(0.33, 0.24, 0.16)   # wheel ruts, not lane paint
const CURB_COLOR: Color = Color(0.60, 0.52, 0.29)     # bamboo edge rail
const VERGE_COLOR: Color = Color(0.22, 0.44, 0.19)    # grass shoulder

const WALL_COLORS: Array[Color] = [
	Color(0.86, 0.82, 0.72),   # whitewash
	Color(0.58, 0.42, 0.27),   # papan kayu
	Color(0.74, 0.66, 0.45),   # anyaman bambu
	Color(0.80, 0.74, 0.58),
]
const ROOF_COLORS: Array[Color] = [
	Color(0.62, 0.27, 0.18),   # genteng terakota
	Color(0.45, 0.33, 0.22),   # ijuk / rumbia
	Color(0.48, 0.48, 0.50),   # seng
	Color(0.38, 0.26, 0.20),
]
const TRUNK_COLOR: Color = Color(0.36, 0.28, 0.18)

# Art from the Stylized Nature MegaKit (Quaternius) in res://glTF/.
# Houses stay procedural — the kit has no Indonesian vernacular buildings.
const TREE_SCENES: Array[PackedScene] = [
	preload("res://glTF/CommonTree_1.gltf"),
	preload("res://glTF/CommonTree_2.gltf"),
	preload("res://glTF/CommonTree_3.gltf"),
	preload("res://glTF/CommonTree_4.gltf"),
	preload("res://glTF/CommonTree_5.gltf"),
]
const SHRUB_SCENES: Array[PackedScene] = [
	preload("res://glTF/Bush_Common.gltf"),
	preload("res://glTF/Bush_Common_Flowers.gltf"),
	preload("res://glTF/Plant_1_Big.gltf"),
	preload("res://glTF/Plant_7_Big.gltf"),
]
const GROUND_SCENES: Array[PackedScene] = [
	preload("res://glTF/Grass_Common_Short.gltf"),
	preload("res://glTF/Grass_Common_Tall.gltf"),
	preload("res://glTF/Grass_Wispy_Short.gltf"),
	preload("res://glTF/Grass_Wispy_Tall.gltf"),
	preload("res://glTF/Clover_1.gltf"),
	preload("res://glTF/Clover_2.gltf"),
	preload("res://glTF/Flower_3_Group.gltf"),
	preload("res://glTF/Flower_4_Group.gltf"),
	preload("res://glTF/Mushroom_Common.gltf"),
]
# Flat stones pressed into the dirt — what makes the path read as a real village
# road instead of a brown ramp.
const PATH_SCENES: Array[PackedScene] = [
	preload("res://glTF/RockPath_Round_Small_1.gltf"),
	preload("res://glTF/RockPath_Round_Small_2.gltf"),
	preload("res://glTF/RockPath_Round_Small_3.gltf"),
	preload("res://glTF/RockPath_Square_Small_1.gltf"),
	preload("res://glTF/RockPath_Square_Small_2.gltf"),
	preload("res://glTF/RockPath_Square_Small_3.gltf"),
	preload("res://glTF/Pebble_Round_1.gltf"),
	preload("res://glTF/Pebble_Round_3.gltf"),
	preload("res://glTF/Pebble_Square_2.gltf"),
	preload("res://glTF/Pebble_Square_5.gltf"),
]

# Path stones sit BETWEEN lane centres (1.5) and on the shoulder (4.35), never on
# a lane centre, so they can never be misread as something to dodge.
const PATH_OFFSETS: Array[float] = [1.5, 4.35]
const PATH_JITTER: float = 0.25
const PATH_FIT_WIDTH: float = 1.1     # every stone is rescaled to this width
const PATH_LANE_CLEARANCE: float = 0.5   # min gap a stone must leave around a lane centre

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
	var stripe := _make_mat(STRIPE_COLOR, 1.0)
	$StripeL.material_override = stripe
	$StripeR.material_override = stripe
	var curb := _make_mat(CURB_COLOR, 0.85)
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
	# ponytail: repeated props are plain instances, not a MultiMeshInstance3D.
	# Upgrade path: batch trees/grass/stones into multimeshes if draw calls bite.
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var house := _make_house((index * 2 + i) % 4)
		# Offset by the house's own bounding radius so no roof overhang can reach the
		# track, whatever the random size/rotation rolls.
		var clear_x: float = ROAD_EDGE + float(house.get_meta("radius")) + randf_range(0.4, 2.2)
		house.position = Vector3(
			side * clear_x,
			FLOOR_TOP_LOCAL,
			randf_range(-CHUNK_LENGTH * 0.4, CHUNK_LENGTH * 0.4)
		)
		# Front (-Z) turned to face the path.
		house.rotation.y = side * PI / 2.0 + randf_range(-0.22, 0.22)
		add_child(house)

	_scatter(TREE_SCENES, 3, 1.0, 6.0, 0.75, 1.25)
	_scatter(SHRUB_SCENES, 4, 0.3, 5.0, 0.7, 1.3)
	_scatter(GROUND_SCENES, 8, 0.1, 7.0, 0.6, 1.2)
	_scatter_path(5)

## Drops `count` random props from `scenes` on either verge. Each one is pushed
## out by its OWN measured radius plus a gap, so nothing can ever overhang the
## track no matter which model or scale the roll produces.
func _scatter(
	scenes: Array[PackedScene], count: int,
	gap_min: float, gap_max: float,
	scale_min: float, scale_max: float
) -> void:
	for i in count:
		var prop: Node3D = scenes[randi() % scenes.size()].instantiate()
		var s: float = randf_range(scale_min, scale_max)
		prop.scale = Vector3(s, s, s)
		prop.rotation.y = randf_range(0.0, TAU)
		add_child(prop)
		var side: float = 1.0 if randf() < 0.5 else -1.0
		prop.position = Vector3(
			side * (ROAD_EDGE + Bounds.radius(prop) + randf_range(gap_min, gap_max)),
			FLOOR_TOP_LOCAL,
			randf_range(-CHUNK_LENGTH * 0.5, CHUNK_LENGTH * 0.5)
		)

func _scatter_path(count: int) -> void:
	for i in count:
		var stone: Node3D = PATH_SCENES[randi() % PATH_SCENES.size()].instantiate()
		stone.rotation.y = randf_range(0.0, TAU)
		add_child(stone)
		Bounds.fit_width(stone, PATH_FIT_WIDTH * randf_range(0.5, 1.0))
		var side: float = 1.0 if randf() < 0.5 else -1.0
		stone.position = Vector3(
			side * (PATH_OFFSETS[randi() % PATH_OFFSETS.size()] + randf_range(-PATH_JITTER, PATH_JITTER)),
			FLOOR_TOP_LOCAL + 0.005,   # hair above the floor to avoid z-fighting
			randf_range(-CHUNK_LENGTH * 0.5, CHUNK_LENGTH * 0.5)
		)

# --- primitive helpers (position is the mesh centre, local to the returned root) ---

func _mesh(mesh: Mesh, color: Color, pos: Vector3, rough: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat(color, rough)
	mi.position = pos
	return mi

func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, color, pos)

func _prism(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return _mesh(m, color, pos)

func _cyl(top_r: float, bot_r: float, h: float, seg: int, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = seg
	return _mesh(m, color, pos)

func _pick(colors: Array[Color]) -> Color:
	return colors[randi() % colors.size()]

# --- kampung props ---

## style 0 = kampung pelana, 1 = joglo (Jawa), 2 = gadang (Minang), 3 = honai (Papua)
func _make_house(style: int) -> Node3D:
	var root := Node3D.new()
	var wall := _pick(WALL_COLORS)
	var roof := _pick(ROOF_COLORS)
	var w: float = randf_range(3.4, 4.8)
	var d: float = randf_range(3.0, 4.2)
	var h: float = randf_range(1.9, 2.5)

	# Bounding radius of the widest part (roof overhang) — used for track clearance.
	root.set_meta("radius", maxf(w, d) * 0.72)

	if style == 3:
		# Honai: round walls, tall conical thatch. No stilts, no door slab.
		var r: float = w * 0.42
		root.set_meta("radius", r * 1.25)
		root.add_child(_cyl(r, r, h, 10, wall, Vector3(0, h / 2.0, 0)))
		root.add_child(_cyl(0.0, r * 1.25, r * 1.5, 10, ROOF_COLORS[1], Vector3(0, h + r * 0.75, 0)))
		return root

	# Stilts (panggung) for joglo/gadang, slab-on-ground for the plain house.
	var lift: float = 0.0 if style == 0 else randf_range(0.6, 1.0)
	if lift > 0.0:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				root.add_child(_cyl(0.13, 0.15, lift, 6, TRUNK_COLOR,
					Vector3(sx * w * 0.4, lift / 2.0, sz * d * 0.4)))

	root.add_child(_box(Vector3(w, h, d), wall, Vector3(0, lift + h / 2.0, 0)))
	root.add_child(_box(Vector3(0.8, h * 0.72, 0.06), Color(0.32, 0.21, 0.13),
			Vector3(0, lift + h * 0.36, -d / 2.0 - 0.03)))

	var eave_y: float = lift + h
	match style:
		1:
			# Joglo: steep inner tajug stacked on a wide low skirt roof.
			root.add_child(_prism(Vector3(w * 1.35, 0.55, d * 1.35), roof, Vector3(0, eave_y + 0.27, 0)))
			root.add_child(_prism(Vector3(w * 0.78, 1.15, d * 0.8), roof, Vector3(0, eave_y + 1.12, 0)))
		2:
			# Gadang: saddle roof plus upswept gonjong spires at both gable ends.
			root.add_child(_prism(Vector3(w * 1.2, 0.95, d * 1.15), roof, Vector3(0, eave_y + 0.48, 0)))
			for sx in [-1.0, 1.0]:
				var horn := _prism(Vector3(0.5, 1.7, d * 1.1), roof,
						Vector3(sx * w * 0.52, eave_y + 1.15, 0))
				horn.rotation.z = sx * 0.42
				root.add_child(horn)
		_:
			root.add_child(_prism(Vector3(w * 1.15, 0.9, d * 1.12), roof, Vector3(0, eave_y + 0.45, 0)))
	return root

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
