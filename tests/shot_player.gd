extends SceneTree
# Renders the player so the imported rig can be eyeballed against player.png
# without opening the editor.
#
# Run: godot --path . --script res://tests/shot_player.gd -- <clip> <out.png> [back|front|side]
#
# NOTE: deliberately *not* --headless. The dummy renderer has no framebuffer, so
# Viewport.get_texture().get_image() always returns null there.

const MAX_FRAMES: int = 180        # hard stop; a stuck capture must not spin forever

var frames: int = 0
var viewport: SubViewport
var player: Node3D
var anim: AnimationPlayer
var clip: String = "Run"
var out_path: String = "user://shot.png"
var view: String = "back"

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		clip = argv[0]
	if argv.size() > 1:
		out_path = argv[1]
	if argv.size() > 2:
		view = argv[2]

	viewport = SubViewport.new()
	viewport.size = Vector2i(520, 640)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.84, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.88)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.8
	viewport.add_child(sun)

	player = (load("res://player.tscn") as PackedScene).instantiate()
	viewport.add_child(player)
	player.set_physics_process(false)

	viewport.add_child(_make_camera())

# The rig is modelled facing -Z, so "back" is the in-game chase angle and
# "front" is the pose player.png was drawn from.
func _make_camera() -> Camera3D:
	var cam := Camera3D.new()
	match view:
		"front":
			cam.position = Vector3(0.0, 0.85, -3.4)
			cam.rotation = Vector3(0.0, deg_to_rad(180.0), 0.0)
			cam.fov = 40.0
		"side":
			cam.position = Vector3(3.4, 0.85, 0.0)
			cam.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
			cam.fov = 40.0
		_:
			cam.position = Vector3(0.0, 1.6, 3.4)
			cam.rotation = Vector3(deg_to_rad(-12.0), 0.0, 0.0)
			cam.fov = 45.0
	cam.make_current()
	return cam

func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		printerr("FAIL: gave up after %d frames (anim=%s)" % [frames, str(anim)])
		quit(1)
		return true

	# @onready does not run until the instance's first idle frame, so the
	# AnimationPlayer has to be resolved here rather than in _initialize().
	if anim == null:
		anim = player.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim == null:
			return false
		if not anim.has_animation(clip):
			printerr("FAIL: no clip named " + clip)
			quit(1)
			return true
		anim.play(clip)
		anim.seek(anim.current_animation_length * 0.3, true)
		return false

	if frames < 8:    # let the skeleton pose and the render target settle
		return false

	var tex := viewport.get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		return false

	var err := img.save_png(out_path)
	if err != OK:
		printerr("FAIL: save_png(%s) -> %d" % [out_path, err])
		quit(1)
		return true
	print("shot saved: ", out_path)
	return true
