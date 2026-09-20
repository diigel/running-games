extends SceneTree
# Headless self-check for the 3D player rig + pose animation.
# Run: godot --path . --headless --script res://tests/test_player_anim.gd

var player: CharacterBody3D

func _initialize() -> void:
	player = preload("res://player.tscn").instantiate()
	root.add_child(player)

func _step(frames: int) -> void:
	for i in frames:
		player._animate(1.0 / 60.0)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FAIL: " + msg)
		printerr("FAIL: " + msg)
		quit(1)

# Nodes added during _initialize() only get _ready() on the first idle frame,
# so all assertions run here rather than in the constructor.
func _process(_delta: float) -> bool:
	# Rig exists and faces away from the camera (-Z is the running direction).
	_check(player.rig != null, "rig was not built")
	_check(player.rig.rotation.y == 0.0, "rig must face -Z, away from the camera")
	for name in ["torso", "head", "leg_l", "leg_r", "knee_l", "knee_r", "arm_l", "arm_r"]:
		_check(player.joint.has(name), "missing joint: %s" % name)

	# Running: legs swing in opposition and keep moving over time.
	_step(20)
	var l1: float = player.joint["leg_l"].rotation.x
	_check(signf(l1) != signf(player.joint["leg_r"].rotation.x), "legs not counter-swinging")
	_step(12)
	_check(absf(player.joint["leg_l"].rotation.x - l1) > 0.05, "run cycle is frozen")

	# Sliding: body ducks, hips drop, one leg extends forward while the other folds.
	player._start_slide()
	_step(90)
	_check(player.hips.position.y < player.HIP_HEIGHT * 0.6, "slide did not lower the hips")
	_check(player.joint["torso"].rotation.x < -0.7, "character did not duck while sliding")
	_check(player.joint["leg_l"].rotation.x > 1.0, "front leg did not extend forward")
	_check(player.joint["knee_r"].rotation.x < -1.5, "back leg did not fold under")
	_check((player.col_shape.shape as CapsuleShape3D).height < 1.0, "collider did not shrink")

	# Jumping: knees tuck on the way up and the body comes back up off the slide.
	player._end_slide()
	player.state = player.State.JUMPING
	player.velocity.y = player.JUMP_FORCE
	_step(40)
	_check(player.joint["knee_l"].rotation.x < -1.2, "knees did not tuck on the jump")
	_check(player.hips.position.y > player.HIP_HEIGHT * 0.9, "hips stayed low after the slide")

	print("player rig + anim OK")
	return true   # true = quit the main loop
