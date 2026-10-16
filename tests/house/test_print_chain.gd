extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 0.5, 10.5), Vector3(4.5, 0.5, 10.5))
	var hit: Dictionary = space.intersect_ray(query)
	print("Raycast result: ", hit)
	if not hit.is_empty():
		var col: Object = hit.collider
		print("Collider: ", col)
		var p: Node = col.get_parent()
		while p != null:
			print(" -> ", p.name, " (", p, ")")
			p = p.get_parent()
	quit(0)

