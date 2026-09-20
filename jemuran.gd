extends "res://obstacle.gd"

## Laundry hung across the path. Colours and garment shapes are rolled per spawn
## so the same obstacle never looks copy-pasted, and exactly one item is a pair
## of trousers placed in a random slot.
##
## Geometry is decorative only — the collider lives in obstacle_slide.tscn. The
## constants below keep every garment inside that collider's y band, so the art
## never promises clearance the physics won't honour.

const ROPE_Y: float = 2.1        # the washing line; garments hang down from here
const HEM_FLOOR: float = 1.15    # collider bottom is 1.10 — never hang below this
const SLOT_X: Array[float] = [-0.82, 0.0, 0.84]

func _ready() -> void:
	super()
	_hang_laundry()

func _hang_laundry() -> void:
	var pants_slot: int = randi() % SLOT_X.size()
	for i in SLOT_X.size():
		var item := _garment(_random_cloth_color(), i == pants_slot)
		item.position = Vector3(SLOT_X[i], 0.0, randf_range(-0.04, 0.04))
		item.rotation.z = randf_range(-0.09, 0.09)
		add_child(item)

func _random_cloth_color() -> Color:
	return Color.from_hsv(randf(), randf_range(0.15, 0.8), randf_range(0.62, 0.97))

func _garment(color: Color, is_pants: bool) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # cloth is a single-sided slab

	if is_pants:
		var waist: float = 0.3
		root.add_child(_cloth(Vector3(0.62, waist, 0.05), mat, ROPE_Y - waist * 0.5))
		var leg: float = _hang_length(waist, randf_range(0.45, 0.66))
		for sx in [-1.0, 1.0]:
			var leg_node := _cloth(Vector3(0.26, leg, 0.05), mat, ROPE_Y - waist - leg * 0.5)
			leg_node.position.x = sx * 0.17
			root.add_child(leg_node)
	else:
		var body: float = _hang_length(0.0, randf_range(0.62, 0.9))
		root.add_child(_cloth(Vector3(randf_range(0.58, 0.78), body, 0.05), mat, ROPE_Y - body * 0.5))
		var sleeve: float = body * 0.45
		for sx in [-1.0, 1.0]:
			var arm := _cloth(Vector3(0.22, sleeve, 0.05), mat, ROPE_Y - 0.1 - sleeve * 0.5)
			arm.position.x = sx * randf_range(0.34, 0.42)
			arm.rotation.z = sx * randf_range(0.15, 0.5)
			root.add_child(arm)
	return root

## Clamp a randomised drop so the hem stops at HEM_FLOOR instead of dangling
## through the collider's underside.
func _hang_length(used: float, wanted: float) -> float:
	return minf(wanted, ROPE_Y - used - HEM_FLOOR)

func _cloth(size: Vector3, mat: StandardMaterial3D, centre_y: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, centre_y, 0.0)
	return mi
