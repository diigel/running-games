extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_random_color()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("game_manager", "on_obstacle_hit")


func _apply_random_color() -> void:
	var mat := StandardMaterial3D.new()
	# Random hue, high saturation + brightness — vivid and distinct from floor
	mat.albedo_color = Color.from_hsv(randf(), 0.85, 0.95)
	mat.roughness = 0.6
	$MeshInstance3D.material_override = mat
