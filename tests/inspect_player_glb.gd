extends SceneTree
# Prints the imported rig's node tree, bones and animation clips.
# Run: godot --path . --headless --script res://tests/inspect_player_glb.gd

func _dump(n: Node, depth: int) -> void:
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		_dump(c, depth + 1)

# Dumping from _initialize() and quitting there truncates stdout, so the work
# runs on the first idle frame instead.
func _process(_delta: float) -> bool:
	var scene := load("res://models/player.glb") as PackedScene
	var root := scene.instantiate()
	_dump(root, 0)
	for n in root.find_children("*", "AnimationPlayer", true, false):
		print("clips: ", (n as AnimationPlayer).get_animation_list())
	for n in root.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		print("bones(", sk.get_bone_count(), "): ",
			range(sk.get_bone_count()).map(func(i): return sk.get_bone_name(i)))
	var aabb := AABB()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge((n as MeshInstance3D).get_aabb())
	print("aabb pos=", aabb.position, " size=", aabb.size)
	root.free()
	return true
