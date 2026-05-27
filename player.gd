extends CharacterBody3D

enum State { RUNNING, SLIDING, JUMPING }

const LANE_POSITIONS: Array[float] = [-3.0, 0.0, 3.0]
const LANE_SWITCH_SPEED: float = 12.0
const JUMP_FORCE: float = 8.0
const GRAVITY: float = 20.0
const SLIDE_DURATION: float = 0.9
const NORMAL_HEIGHT: float = 1.8
const SLIDE_HEIGHT: float = 0.9

var z_speed: float = -10.0      # set by GameManager every frame
var current_lane: int = 1
var state: State = State.RUNNING
var slide_timer: float = 0.0

@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_inst: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	position.x = LANE_POSITIONS[current_lane]
	# Center capsule so its bottom sits at y=0 (player feet at floor level)
	col_shape.position.y = NORMAL_HEIGHT / 2.0
	mesh_inst.position.y = NORMAL_HEIGHT / 2.0
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_handle_input()
	_apply_gravity(delta)
	_tick_slide(delta)
	_smooth_lane()
	velocity.z = z_speed
	move_and_slide()


func _handle_input() -> void:
	# Lane switch — always allowed
	if Input.is_action_just_pressed("ui_left") and current_lane > 0:
		current_lane -= 1
	if Input.is_action_just_pressed("ui_right") and current_lane < 2:
		current_lane += 1

	# Jump — only from floor while RUNNING
	if Input.is_action_just_pressed("ui_accept") and state == State.RUNNING and is_on_floor():
		velocity.y = JUMP_FORCE
		state = State.JUMPING

	# Slide — only while RUNNING
	if Input.is_action_just_pressed("ui_down") and state == State.RUNNING:
		_start_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0   # clear accumulated fall velocity on landing
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
	# Proportional velocity gives ease-out naturally
	velocity.x = (target_x - position.x) * LANE_SWITCH_SPEED


func _start_slide() -> void:
	state = State.SLIDING
	slide_timer = SLIDE_DURATION
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = SLIDE_HEIGHT
	col_shape.position.y = SLIDE_HEIGHT / 2.0
	mesh_inst.position.y = SLIDE_HEIGHT / 2.0
	mesh_inst.scale.y = SLIDE_HEIGHT / NORMAL_HEIGHT   # visual feedback


func _end_slide() -> void:
	state = State.RUNNING
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = NORMAL_HEIGHT
	col_shape.position.y = NORMAL_HEIGHT / 2.0
	mesh_inst.position.y = NORMAL_HEIGHT / 2.0
	mesh_inst.scale.y = 1.0
