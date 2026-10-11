extends SceneTree
# Headless self-check: the imported Blender rig is wired up and each state
# drives the right clip + collider.
# Run: godot --path . --headless --script res://tests/test_player_anim.gd

var player: CharacterBody3D
var failed: bool = false

func _initialize() -> void:
	player = preload("res://player.tscn").instantiate()
	root.add_child(player)

# quit() only takes effect once the frame returns, so a failed check has to stop
# the remaining assertions itself or they run on a known-bad rig.
func _check(cond: bool, msg: String) -> void:
	if cond or failed:
		return
	failed = true
	printerr("FAIL: " + msg)
	print("FAIL: " + msg)
	quit(1)

# Nodes added during _initialize() only get _ready() on the first idle frame,
# so every assertion runs here.
func _process(_delta: float) -> bool:
	var sk: Skeleton3D = player.model.find_child("Skeleton3D", true, false)
	if sk == null:
		_check(false, "imported rig has no Skeleton3D")
		return true
	_check(sk != null, "imported rig has no Skeleton3D")
	_check(sk.get_bone_count() == 17, "expected 17 bones, got %d" % sk.get_bone_count())
	for bone in ["Hips", "Head", "UpperLeg_L", "UpperArm_R", "Foot_L"]:
		_check(sk.find_bone(bone) != -1, "missing bone: " + bone)

	for clip in ["Idle", "Run", "Jump", "Slide"]:
		_check(player.anim.has_animation(clip), "missing clip: " + clip)
	_check(player.anim.get_animation("Run").loop_mode == Animation.LOOP_LINEAR,
		"Run must loop, otherwise the character freezes mid-stride")

	# Running is the default and its playback rate tracks ground speed.
	_check(player.anim.current_animation == "Run", "did not start in Run")
	player.z_speed = -20.0
	player._animate(1.0 / 60.0)
	_check(player.anim.speed_scale > 1.5, "run cycle does not speed up with the track")

	# Sliding: clip swaps and the collider shrinks so the player fits underneath.
	player._start_slide()
	_check(player.anim.current_animation == "Slide", "slide clip did not play")
	_check((player.col_shape.shape as CapsuleShape3D).height < 1.0, "collider did not shrink")

	# ...and comes back up afterwards.
	player._end_slide()
	_check(player.anim.current_animation == "Run", "did not return to Run after sliding")
	_check((player.col_shape.shape as CapsuleShape3D).height == player.NORMAL_HEIGHT,
		"collider did not restore")

	# Lane changes bank the model rather than the collider.
	player.velocity.x = 6.0
	for i in 30:
		player._animate(1.0 / 60.0)
	_check(absf(player.model.rotation.z) > 0.1, "model does not lean into a lane change")

	if failed:
		return true
	print("player rig + anim OK")
	return true   # true = quit the main loop
