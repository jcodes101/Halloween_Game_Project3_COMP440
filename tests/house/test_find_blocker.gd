extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.position = Vector3(2.2, 0.5, 10.4)
	var hits: Array[Dictionary] = space.intersect_point(query, 10)
	print("Hits at (2.2, 0.5, 10.4): ", hits)
	for h in hits:
		print("  collider: ", h.collider, " parent: ", h.collider.get_parent())

	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 0.5, 10.5), Vector3(4.5, 0.5, 10))
	var hit: Dictionary = space.intersect_ray(ray)
	print("Raycast hit: ", hit)
	if not hit.is_empty():
		var col: Object = hit.collider
		print("Ray hit collider: ", col, " parent: ", col.get_parent(), " pos=", hit.position)

	quit(0)

