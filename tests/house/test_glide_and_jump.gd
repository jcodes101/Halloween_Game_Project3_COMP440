extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	player.floor_constant_speed = true
	player.floor_max_angle = deg_to_rad(55)
	player.floor_snap_length = 0.4
	player.floor_block_on_wall = false
	player.safe_margin = 0.05
	player.allow_jump = true
	
	print("--- TEST 1: GLIDE UP MAIN STAIRS ---")
	player.global_position = Vector3(4.5, 0.1, 11.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	
	for f in 160:
		var dir := Vector3(0, 0, -1)
		player.velocity.x = dir.x * 4.2
		player.velocity.z = dir.z * 4.2
		if not player.is_on_floor():
			player.velocity.y -= 18.0 * (1.0 / 60.0)
		else:
			player.velocity.y = 0.0
		player.move_and_slide()
		await physics_frame
		if f % 20 == 0:
			print("Glide UP f=", f, ": pos=", player.global_position, " on_floor=", player.is_on_floor())
	print("Final Glide UP pos: ", player.global_position)
	assert(player.global_position.y > 3.4, "Failed to glide up main stairs!")

	print("--- TEST 2: GLIDE DOWN MAIN STAIRS ---")
	player.global_position = Vector3(4.5, 3.65, 2.0)
	player.rotation.y = PI
	player.velocity = Vector3.ZERO
	
	for f in 160:
		var dir := Vector3(0, 0, 1) # Moving towards +Z (down)
		player.velocity.x = dir.x * 4.2
		player.velocity.z = dir.z * 4.2
		if not player.is_on_floor():
			player.velocity.y -= 18.0 * (1.0 / 60.0)
		else:
			player.velocity.y = 0.0
		player.move_and_slide()
		await physics_frame
		if f % 20 == 0:
			print("Glide DOWN f=", f, ": pos=", player.global_position, " on_floor=", player.is_on_floor())
	print("Final Glide DOWN pos: ", player.global_position)
	assert(player.global_position.y < 0.5, "Failed to glide down main stairs!")

	print("--- TEST 3: JUMP ON STEPS TO MOVE FORWARD ---")
	player.global_position = Vector3(4.5, 0.1, 10.5)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	
	for f in 160:
		var dir := Vector3(0, 0, -1)
		player.velocity.x = dir.x * 4.2
		player.velocity.z = dir.z * 4.2
		# Jump every 25 frames
		if f % 25 == 0 and (player.is_on_floor() or player.is_on_wall()):
			player.velocity.y = 7.5
			player.floor_snap_length = 0.0
			print("JUMP at f=", f, " pos=", player.global_position)
		elif not player.is_on_floor():
			player.velocity.y -= 18.0 * (1.0 / 60.0)
			player.floor_snap_length = 0.0
		else:
			player.velocity.y = 0.0
			player.floor_snap_length = 0.4
		player.move_and_slide()
		await physics_frame
		if f % 20 == 0:
			print("Jumping UP f=", f, ": pos=", player.global_position, " on_floor=", player.is_on_floor())
	print("Final Jumping UP pos: ", player.global_position)
	assert(player.global_position.y > 3.4, "Failed to jump up stairs!")

	print("ALL GLIDE AND JUMP TESTS PASSED!")
	quit(0)

