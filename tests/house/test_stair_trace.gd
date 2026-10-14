extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	player.global_position = Vector3(4.5, 0.001, 10.5)
	
	for f in 10:
		var dir := Vector3(0, 0, -1)
		player.velocity.x = dir.x * 4.2
		player.velocity.z = dir.z * 4.2
		if not player.is_on_floor():
			player.velocity.y -= 18.0 * (1.0 / 60.0)
		else:
			player.velocity.y = -0.5
		print("BEFORE f=", f, " pos=", player.global_position, " vel=", player.velocity, " on_floor=", player.is_on_floor())
		player.move_and_slide()
		print("AFTER  f=", f, " pos=", player.global_position, " vel=", player.velocity, " real_vel=", player.get_real_velocity(), " on_floor=", player.is_on_floor(), " is_on_wall=", player.is_on_wall())
		for c in player.get_slide_collision_count():
			var col := player.get_slide_collision(c)
			print("   c=", c, " norm=", col.get_normal(), " angle=", rad_to_deg(col.get_angle()), " coll=", col.get_collider().name, " parent=", col.get_collider().get_parent().name)

	quit(0)

