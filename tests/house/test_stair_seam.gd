extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	print("Player safe_margin: ", player.safe_margin)
	print("Player floor_snap_length: ", player.floor_snap_length)
	print("Player floor_max_angle: ", player.floor_max_angle)
	print("Player floor_block_on_wall: ", player.floor_block_on_wall)
	
	# Test walking with WALK_SPEED (not test velocity 4.2, but walk speed 4.2 or slower)
	# What if player is walking at normal walk speed?
	# What if player is walking from z = 10.5 towards z = 9.5?
	for start_z in [10.5, 10.3, 10.1, 10.05, 10.0]:
		player.global_position = Vector3(4.5, 0.001, start_z)
		player.velocity = Vector3.ZERO
		var stuck := false
		for f in 40:
			# player normal movement logic from first_person_player.gd:
			var dir := Vector3(0, 0, -1)
			player.velocity.x = dir.x * 4.2
			player.velocity.z = dir.z * 4.2
			if not player.is_on_floor():
				player.velocity.y -= 18.0 * (1.0 / 60.0)
			else:
				player.velocity.y = -0.5
			player.move_and_slide()
			await physics_frame
			if f > 5 and player.get_real_velocity().length() < 0.1:
				print("STUCK at start_z=", start_z, " at f=", f, " pos=", player.global_position, " on_floor=", player.is_on_floor(), " vel=", player.velocity, " real_vel=", player.get_real_velocity())
				stuck = true
				break
		if not stuck:
			print("Walked smoothly from start_z=", start_z, " to pos=", player.global_position)

	quit(0)

