extends Area3D

## Per-type colour set in each obstacle scene, so the player can read
## "jump" (warm) vs "slide" (cool) at a glance instead of guessing a random hue.
@export var accent_color: Color = Color(0.9, 0.3, 0.2)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_materials()

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
			child.material_override = body_mat if child.name == "MeshInstance3D" else trim_mat
