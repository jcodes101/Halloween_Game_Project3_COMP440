extends SceneTree

func _init() -> void:
	var s: Node = load("res://assets/environment/building/stairs-closed.glb").instantiate()
	print("STAIRS INSTANCE: ", s)
	_dump(s, 0)
	quit(0)

func _dump(n: Node, depth: int) -> void:
	print("  ".repeat(depth), n.name, " (", n.get_class(), ")")
	if n is MeshInstance3D:
		print("  ".repeat(depth + 1), "AABB: ", n.get_aabb())
	for c in n.get_children():
		_dump(c, depth + 1)

