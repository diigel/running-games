extends CharacterBody3D

enum State { RUNNING, SLIDING, JUMPING }

const LANE_POSITIONS: Array[float] = [-3.0, 0.0, 3.0]
const LANE_SWITCH_SPEED: float = 12.0
const JUMP_FORCE: float = 8.0
const GRAVITY: float = 20.0
const SLIDE_DURATION: float = 0.9
const NORMAL_HEIGHT: float = 1.5     # matches the imported rig's AABB
const SLIDE_HEIGHT: float = 0.75
const LEAN_ANGLE: float = 0.30       # radians of bank while changing lanes
const LEAN_SPEED: float = 10.0

# Blender authors Run as a 24-frame cycle at 30 fps, i.e. 0.8 s per stride at
# z_speed 10; scaling speed by the same ratio keeps the feet from skating.
const RUN_BASE_SPEED: float = 10.0
const BLEND_TIME: float = 0.12

var z_speed: float = -10.0      # set by GameManager every frame
var current_lane: int = 1
var state: State = State.RUNNING
var slide_timer: float = 0.0

@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer

func _ready() -> void:
	position.x = LANE_POSITIONS[current_lane]
	col_shape.position.y = NORMAL_HEIGHT / 2.0
	add_to_group("player")
	# build_player.py yaws the rig 180 deg before export so the glb already faces
	# -Z, i.e. away from the chase camera; no extra rotation is needed here.
	_play("Run")

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
		_play("Jump")
	if Input.is_action_just_pressed("ui_down") and state == State.RUNNING:
		_start_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
		if state == State.JUMPING:
			state = State.RUNNING
			_play("Run")

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
func _play(clip: String) -> void:
	if anim and anim.has_animation(clip):
		anim.play(clip, BLEND_TIME)

func _animate(delta: float) -> void:
	if state == State.RUNNING and anim:
		# Stride rate follows real ground speed so the run tightens as it accelerates.
		anim.speed_scale = maxf(0.35, absf(z_speed) / RUN_BASE_SPEED)
	elif anim:
		anim.speed_scale = 1.0

	# Bank into the lane change.
	var lean: float = -clampf(velocity.x / (LANE_SWITCH_SPEED * 0.5), -1.0, 1.0) * LEAN_ANGLE
	model.rotation.z = lerpf(model.rotation.z, lean, minf(1.0, LEAN_SPEED * delta))

func _start_slide() -> void:
	state = State.SLIDING
	slide_timer = SLIDE_DURATION
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = SLIDE_HEIGHT
	col_shape.position.y = SLIDE_HEIGHT / 2.0
	_play("Slide")

func _end_slide() -> void:
	state = State.RUNNING
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = NORMAL_HEIGHT
	col_shape.position.y = NORMAL_HEIGHT / 2.0
	_play("Run")
