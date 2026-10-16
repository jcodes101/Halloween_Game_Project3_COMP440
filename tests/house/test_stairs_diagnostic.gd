extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	player.global_position = Vector3(0, 0.1, 10.5)
	var target := Vector3(4.5, 0.1, 10)
	var dir := (target - player.global_position).normalized()
	for f in 60:
		player.velocity = dir * 4.2
		player.velocity.y = -0.5
		player.move_and_slide()
		await physics_frame
		print("f=", f, " pos=", player.global_position, " vel=", player.velocity)
		for c in player.get_slide_collision_count():
			var col := player.get_slide_collision(c)
			print("   c=", c, " norm=", col.get_normal(), " coll=", col.get_collider().name, " parent=", col.get_collider().get_parent().name)
		if f > 35:
			break
	quit(0)

