class_name Bounds

## Measuring helpers for instanced art, so placement code never hardcodes the
## dimensions of a model it doesn't own. Imported kits change sizes between
## versions; asking the mesh is cheaper than re-tuning magic numbers.

## Combined AABB of every visual inside `node`, expressed in its PARENT's space
## (so the node's own scale and rotation are included).
## `node` must already be inside the scene tree.
static func in_parent(node: Node3D) -> AABB:
	var parent := node.get_parent() as Node3D
	assert(parent != null, "Bounds.in_parent() needs the node added to a Node3D parent first")
	var to_parent := parent.global_transform.affine_inverse()

	var visuals: Array[Node] = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		visuals.append(node)

	var out := AABB()
	var found := false
	for v in visuals:
		var vi := v as VisualInstance3D
		var box := to_parent * vi.global_transform * vi.get_aabb()
		out = box if not found else out.merge(box)
		found = true
	return out

## Largest horizontal distance from the node's origin — a rotation-safe keep-out
## radius for "don't let this prop reach the track" checks.
static func radius(node: Node3D) -> float:
	var ab := in_parent(node)
	return maxf(
		maxf(absf(ab.position.x), absf(ab.end.x)),
		maxf(absf(ab.position.z), absf(ab.end.z))
	)

## Uniformly rescale `node` so its widest horizontal axis measures `width`.
static func fit_width(node: Node3D, width: float) -> void:
	var ab := in_parent(node)
	var widest := maxf(ab.size.x, ab.size.z)
	if widest > 0.0:
		node.scale *= width / widest
