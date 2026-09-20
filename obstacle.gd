extends Area3D

## Per-type colour set in each obstacle scene, so the player can read
## "jump" (warm) vs "slide" (cool) at a glance instead of guessing a random hue.
@export var accent_color: Color = Color(0.9, 0.3, 0.2)

## Optional imported art. One entry is picked at random per spawn so repeated
## obstacles don't look copy-pasted. Collision lives in the scene and is never
## derived from these, so swapping art cannot change difficulty.
@export var prop_scenes: Array[PackedScene] = []
## Bounding size the chosen prop is rescaled to, in metres. Set it to the
## collider's size so what the player sees is exactly what they hit.
## Vector3.ZERO keeps the model's authored scale.
@export var prop_fit_size: Vector3 = Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_materials()
	# After _apply_materials, so the imported prop keeps its own kit materials.
	_add_prop()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("game_manager", "on_obstacle_hit")

func _apply_materials() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = accent_color
	body_mat.roughness = 0.45
	body_mat.metallic = 0.1
	body_mat.emission_enabled = true
	body_mat.emission = accent_color
	body_mat.emission_energy_multiplier = 0.35

	# Trim parts (caps/posts) get a brighter emissive edge for silhouette readability.
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = accent_color.lightened(0.5)
	trim_mat.roughness = 0.3
	trim_mat.emission_enabled = true
	trim_mat.emission = accent_color.lightened(0.6)
	trim_mat.emission_energy_multiplier = 1.4

	for child in get_children():
		if child is MeshInstance3D:
			# Themed props author their own material in-scene; don't overwrite it.
			if child.material_override != null:
				continue
			child.material_override = body_mat if child.name == "MeshInstance3D" else trim_mat

func _add_prop() -> void:
	if prop_scenes.is_empty():
		return
	var prop: Node3D = prop_scenes[randi() % prop_scenes.size()].instantiate()
	prop.rotation.y = randf_range(0.0, TAU)
	add_child(prop)
	if prop_fit_size == Vector3.ZERO:
		return
	var ab := Bounds.in_parent(prop)
	if ab.size.x <= 0.0 or ab.size.y <= 0.0 or ab.size.z <= 0.0:
		push_warning("%s: prop has no measurable bounds, left unscaled" % name)
		return
	prop.scale = prop_fit_size / ab.size
	# Re-seat the art: horizontally centred, resting on the collider's base.
	var scaled_min: Vector3 = ab.position * prop.scale
	prop.position = Vector3(-prop_fit_size.x * 0.5, 0.0, -prop_fit_size.z * 0.5) - scaled_min
