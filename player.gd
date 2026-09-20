extends CharacterBody3D

enum State { RUNNING, SLIDING, JUMPING }

const LANE_POSITIONS: Array[float] = [-3.0, 0.0, 3.0]
const LANE_SWITCH_SPEED: float = 12.0
const JUMP_FORCE: float = 8.0
const GRAVITY: float = 20.0
const SLIDE_DURATION: float = 0.9
const NORMAL_HEIGHT: float = 1.8
const SLIDE_HEIGHT: float = 0.9
const LEAN_ANGLE: float = 0.30        # radians of bank while changing lanes
const LEAN_SPEED: float = 10.0

# --- Body proportions (metres, feet at y=0) ---
const HIP_HEIGHT: float = 0.88
const THIGH_LEN: float = 0.42
const SHIN_LEN: float = 0.40
const UPPER_ARM_LEN: float = 0.30
const FOREARM_LEN: float = 0.28
const SHOULDER_Y: float = 0.52
const SHOULDER_X: float = 0.27
const HEAD_Y: float = 0.64

# --- Palette lifted from player.png ---
const C_SHIRT: Color = Color(0.93, 0.94, 0.97)
const C_SKIN: Color = Color(0.86, 0.55, 0.32)
const C_HAIR: Color = Color(0.07, 0.07, 0.09)
const C_PANTS: Color = Color(0.24, 0.36, 0.22)
const C_SHOE: Color = Color(0.16, 0.28, 0.55)

# --- Animation tuning ---
const RUN_CYCLE_SPEED: float = 8.0    # strides/sec at base speed
const RUN_BOB: float = 0.07
const POSE_LERP: float = 16.0         # how fast a pose change settles

var z_speed: float = -10.0      # set by GameManager every frame
var current_lane: int = 1
var state: State = State.RUNNING
var slide_timer: float = 0.0
var run_phase: float = 0.0

var rig: Node3D
var hips: Node3D
var joint: Dictionary = {}      # joint name -> Node3D pivot

@onready var col_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	position.x = LANE_POSITIONS[current_lane]
	col_shape.position.y = NORMAL_HEIGHT / 2.0
	add_to_group("player")
	_build_rig()

# --- Rig construction ------------------------------------------------------
# Built in code rather than as a .tscn blob: ten primitives, no hand-authored
# transform soup to keep in sync with the constants above.
func _build_rig() -> void:
	rig = Node3D.new()
	# -Z is both Godot's forward and the running direction, so the default
	# orientation already has the character running away from the camera.
	add_child(rig)

	hips = Node3D.new()
	hips.position.y = HIP_HEIGHT
	rig.add_child(hips)
	_box(hips, Vector3(0, 0.02, 0), Vector3(0.40, 0.18, 0.26), C_PANTS)

	joint["torso"] = _pivot(hips, Vector3.ZERO)
	var torso: Node3D = joint["torso"]
	_box(torso, Vector3(0, 0.30, 0), Vector3(0.44, 0.58, 0.26), C_SHIRT)

	joint["head"] = _pivot(torso, Vector3(0, HEAD_Y, 0))
	var head: Node3D = joint["head"]
	_sphere(head, Vector3.ZERO, 0.17, C_SKIN)
	# Hair cap — this is the back of the head, which is what the camera sees.
	_sphere(head, Vector3(0, 0.03, 0.02), 0.175, C_HAIR, Vector3(1.0, 0.95, 1.0))

	for side in [-1, 1]:
		var tag: String = "l" if side < 0 else "r"
		var shoulder: Node3D = _limb(torso, Vector3(SHOULDER_X * side, SHOULDER_Y, 0),
				UPPER_ARM_LEN, 0.075, C_SHIRT)
		joint["arm_" + tag] = shoulder
		joint["elbow_" + tag] = _limb(shoulder, Vector3(0, -UPPER_ARM_LEN, 0),
				FOREARM_LEN, 0.065, C_SKIN)

		var thigh: Node3D = _limb(hips, Vector3(0.12 * side, 0, 0), THIGH_LEN, 0.095, C_PANTS)
		joint["leg_" + tag] = thigh
		var knee: Node3D = _limb(thigh, Vector3(0, -THIGH_LEN, 0), SHIN_LEN, 0.08, C_PANTS)
		joint["knee_" + tag] = knee
		_box(knee, Vector3(0, -SHIN_LEN - 0.03, -0.05), Vector3(0.15, 0.10, 0.27), C_SHOE)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p

func _limb(parent: Node3D, pos: Vector3, length: float, radius: float, color: Color) -> Node3D:
	# Pivot sits at the joint; the capsule hangs down from it, so rotating the
	# pivot swings the limb the way a real joint does.
	var p := _pivot(parent, pos)
	var mesh := CapsuleMesh.new()
	mesh.height = length
	mesh.radius = radius
	_attach(p, mesh, Vector3(0, -length / 2.0, 0), color)
	return p

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_attach(parent, mesh, pos, color)

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color,
		scale_v: Vector3 = Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_attach(parent, mesh, pos, color).scale = scale_v

func _attach(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# --- Loop ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_input()
	_tick_slide(delta)
	_smooth_lane()
	_animate(delta)
	velocity.z = z_speed
	move_and_slide()

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_left") and current_lane > 0:
		current_lane -= 1
	if Input.is_action_just_pressed("ui_right") and current_lane < 2:
		current_lane += 1
	if Input.is_action_just_pressed("ui_accept") and state == State.RUNNING and is_on_floor():
		velocity.y = JUMP_FORCE
		state = State.JUMPING
	if Input.is_action_just_pressed("ui_down") and state == State.RUNNING:
		_start_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		if state == State.JUMPING:
			state = State.RUNNING

func _tick_slide(delta: float) -> void:
	if state != State.SLIDING:
		return
	slide_timer -= delta
	if slide_timer <= 0.0:
		_end_slide()

func _smooth_lane() -> void:
	var target_x: float = LANE_POSITIONS[current_lane]
	velocity.x = (target_x - position.x) * LANE_SWITCH_SPEED

# --- Animation -------------------------------------------------------------
# Skeletal, not frame-by-frame: joint angles are the "frames", so the run cycle
# stays smooth at any frame rate and blends into jump/slide instead of popping.
# ponytail: primitive-mesh rig. Swap _build_rig() for an imported rigged .glb +
# AnimationPlayer when real art lands; the pose tables below map 1:1 to clips.
func _animate(delta: float) -> void:
	var pose: Dictionary = {}
	var hip_y: float = HIP_HEIGHT

	match state:
		State.RUNNING:
			# Stride rate follows real ground speed, so it tightens as the run accelerates.
			run_phase += delta * RUN_CYCLE_SPEED * (absf(z_speed) / 10.0)
			var s: float = sin(run_phase)
			hip_y = HIP_HEIGHT + absf(s) * RUN_BOB - RUN_BOB * 0.5
			pose = {
				"torso": -0.20,
				"head": 0.10,
				"leg_l": s * 0.95, "leg_r": -s * 0.95,
				# Knees only bend backwards, and most on the forward swing.
				"knee_l": -0.25 - maxf(s, 0.0) * 1.20,
				"knee_r": -0.25 - maxf(-s, 0.0) * 1.20,
				# Arms counter-swing against the legs, elbows locked at ~90°.
				"arm_l": -s * 0.85, "arm_r": s * 0.85,
				"elbow_l": 1.45, "elbow_r": 1.45,
			}
		State.JUMPING:
			var rise: float = clampf(velocity.y / JUMP_FORCE, -1.0, 1.0)
			# Tuck knees on the way up, reach for the ground on the way down.
			pose = {
				"torso": -0.10 - maxf(rise, 0.0) * 0.15,
				"head": 0.15,
				"leg_l": 0.50 + rise * 0.35, "leg_r": 0.50 + rise * 0.35,
				"knee_l": -0.60 - maxf(rise, 0.0) * 0.90,
				"knee_r": -0.60 - maxf(rise, 0.0) * 0.90,
				"arm_l": -1.90, "arm_r": -1.90,
				"elbow_l": 0.70, "elbow_r": 0.70,
			}
		State.SLIDING:
			# Duck low, front leg shoots forward, back leg folds underneath.
			hip_y = HIP_HEIGHT * 0.42
			pose = {
				"torso": -0.95,
				"head": 0.55,
				"leg_l": 1.35, "knee_l": -0.15,
				"leg_r": 0.35, "knee_r": -1.90,
				"arm_l": 0.90, "arm_r": 0.90,
				"elbow_l": 0.40, "elbow_r": 0.40,
			}

	var t: float = minf(1.0, POSE_LERP * delta)
	for name: String in pose:
		var j: Node3D = joint[name]
		j.rotation.x = lerpf(j.rotation.x, pose[name], t)
	hips.position.y = lerpf(hips.position.y, hip_y, t)

	# Bank into the lane change.
	var lean: float = -clampf(velocity.x / (LANE_SWITCH_SPEED * 0.5), -1.0, 1.0) * LEAN_ANGLE
	rig.rotation.z = lerpf(rig.rotation.z, lean, minf(1.0, LEAN_SPEED * delta))

func _start_slide() -> void:
	state = State.SLIDING
	slide_timer = SLIDE_DURATION
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = SLIDE_HEIGHT
	col_shape.position.y = SLIDE_HEIGHT / 2.0

func _end_slide() -> void:
	state = State.RUNNING
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = NORMAL_HEIGHT
	col_shape.position.y = NORMAL_HEIGHT / 2.0
