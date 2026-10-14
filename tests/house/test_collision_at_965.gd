extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	player.global_position = Vector3(4.5, 0.25, 9.65)
	player.rotation.y = 0
	
	print("Collisions at (4.5, 0.25, 9.65):")
	for f in 5:
		player.velocity = Vector3(0, 0, -4.2)
		player.move_and_slide()
		await physics_frame
		print("f=", f, " pos=", player.global_position, " real_vel=", player.get_real_velocity())
		for c in player.get_slide_collision_count():
			var col := player.get_slide_collision(c)
			print("   col c=", c, " norm=", col.get_normal(), " angle=", rad_to_deg(col.get_angle()), " pos=", col.get_position(), " coll=", col.get_collider().name)
			var p: Node = col.get_collider().get_parent()
			while p != null:
				print("     parent: ", p.name, " (", p, ")")
				p = p.get_parent()
	quit(0)

