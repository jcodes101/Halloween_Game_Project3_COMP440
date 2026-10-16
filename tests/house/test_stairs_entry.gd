extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	
	# Test various X positions at the bottom of the stairs:
	# Stairs are at x = 4.5, width = 2.4 (x from 3.3 to 5.7)
	print("--- TESTING STAIR ENTRY AT VARIOUS X ---")
	for test_x in [3.4, 3.8, 4.2, 4.5, 4.8, 5.2, 5.6]:
		player.global_position = Vector3(test_x, 0.05, 10.8)
		player.velocity = Vector3.ZERO
		var reached_y := 0.0
		for f in 150:
			player.velocity = Vector3(0, -0.5, -4.2)
			player.move_and_slide()
			await physics_frame
			reached_y = maxf(reached_y, player.global_position.y)
		print("Entry at x=", test_x, " reached y=", reached_y, " final_pos=", player.global_position)

	# Test entering from z = 10.1, 10.0, 9.9:
	print("--- TESTING STAIR ENTRY AT VARIOUS Z ---")
	for test_z in [11.2, 10.8, 10.4, 10.0, 9.8]:
		player.global_position = Vector3(4.5, 0.05, test_z)
		player.velocity = Vector3.ZERO
		var reached_y := 0.0
		for f in 150:
			player.velocity = Vector3(0, -0.5, -4.2)
			player.move_and_slide()
			await physics_frame
			reached_y = maxf(reached_y, player.global_position.y)
		print("Entry at z=", test_z, " reached y=", reached_y, " final_pos=", player.global_position)

	# Test kitchen stairs:
	# Kitchen stairs: bottom = (-7, -3.6, -6.4), top = (-7, 0, 1.4), width = 2.4
	# Down: from kitchen (z = 2.0) moving -Z to basement (z = -7.0)
	# Up: from basement (z = -7.0) moving +Z to kitchen (z = 2.0)
	print("--- TESTING KITCHEN STAIRS UP ---")
	player.global_position = Vector3(-7, -3.55, -7.0)
	var reached_kitchen_y := -3.6
	for f in 150:
		player.velocity = Vector3(0, -0.5, 4.2)
		player.move_and_slide()
		await physics_frame
		reached_kitchen_y = maxf(reached_kitchen_y, player.global_position.y)
	print("Kitchen stairs UP reached y=", reached_kitchen_y, " final_pos=", player.global_position)

	quit(0)

