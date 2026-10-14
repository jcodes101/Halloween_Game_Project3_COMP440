extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	
	# Test with default settings vs modified settings:
	print("--- TEST 1: Current settings ---")
	player.global_position = Vector3(4.5, 0.1, 11.0)
	player.rotation.y = 0
	var f1: int = await _test_run(player, false)
	print("Current settings reached: ", player.global_position, " (stopped at f=", f1, ")")

	print("--- TEST 2: Modified settings (safe_margin=0.05, floor_block_on_wall=false, no -0.5 clamp) ---")
	player.global_position = Vector3(4.5, 0.1, 11.0)
	player.rotation.y = 0
	player.safe_margin = 0.05
	player.floor_block_on_wall = false
	player.floor_max_angle = deg_to_rad(50)
	var f2: int = await _test_run(player, true)
	print("Modified settings reached: ", player.global_position, " (reached top at f=", f2, ")")

	quit(0)

func _test_run(player: CharacterBody3D, fix_y: bool) -> int:
	for f in 150:
		var dir := Vector3(0, 0, -1)
		player.velocity.x = dir.x * 4.2
		player.velocity.z = dir.z * 4.2
		if not player.is_on_floor():
			player.velocity.y -= 18.0 * (1.0 / 60.0)
		else:
			if fix_y:
				# Don't clamp velocity.y to -0.5 if on a slope!
				# If on slope, velocity should slide up the slope
				if player.get_floor_angle() > 0.05:
					# Let floor projection work or keep slope velocity
					player.velocity.y = 0.0
				else:
					player.velocity.y = -0.5
			else:
				player.velocity.y = -0.5
		player.move_and_slide()
		await physics_frame
		if player.global_position.y > 3.4:
			return f
		if f > 20 and player.get_real_velocity().length() < 0.05:
			return f
	return 150
