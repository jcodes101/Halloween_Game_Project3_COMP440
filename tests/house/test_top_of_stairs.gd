extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	player.global_position = Vector3(4.5, 2.0, 6.0)
	for f in 180:
		player.velocity = Vector3(0, -0.5, -4.2)
		player.move_and_slide()
		await physics_frame
		if f % 10 == 0:
			print("f=", f, " pos=", player.global_position, " on_floor=", player.is_on_floor(), " vel=", player.velocity)
			for c in player.get_slide_collision_count():
				var col := player.get_slide_collision(c)
				print("   col c=", c, " norm=", col.get_normal(), " coll=", col.get_collider().name, " parent=", col.get_collider().get_parent().name, " pos=", col.get_position())
	quit(0)

