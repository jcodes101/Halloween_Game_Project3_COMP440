extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var player: CharacterBody3D = main.player
	print("Initial player position: ", player.global_position)
	
	# Step 1: Turn towards stairs (+X, rotation.y = -PI/2) and walk right
	player.rotation.y = -PI/2
	player.velocity = Vector3.ZERO
	
	var key_w := InputEventKey.new()
	key_w.keycode = KEY_W
	key_w.physical_keycode = KEY_W
	key_w.pressed = true
	Input.parse_input_event(key_w)
	Input.flush_buffered_events()
	
	for f in 60:
		await physics_frame
		if f % 15 == 0:
			print("Walk to stairs f=", f, ": pos=", player.global_position)
			
	key_w.pressed = false
	Input.parse_input_event(key_w)
	Input.flush_buffered_events()
	print("Reached foot of stairs: ", player.global_position)
	assert(player.global_position.x > 3.5, "Failed to reach foot of stairs! Blocked!")

	# Step 2: Turn towards stairs (-Z, rotation.y = 0) and walk UP the stairs
	player.rotation.y = 0.0
	key_w.pressed = true
	Input.parse_input_event(key_w)
	Input.flush_buffered_events()
	
	for f in 150:
		await physics_frame
		if f % 20 == 0:
			print("Walking UP main stairs f=", f, ": pos=", player.global_position, " on_floor=", player.is_on_floor())
			
	key_w.pressed = false
	Input.parse_input_event(key_w)
	Input.flush_buffered_events()
	print("Position after walking up main stairs: ", player.global_position)
	assert(player.global_position.y > 3.4, "Failed to walk up main stairs!")

	# Step 3: Kitchen stairs - test walking up from basement
	print("--- Testing Kitchen stairs from basement ---")
	player.global_position = Vector3(-7, -3.55, -6.4)
	player.rotation.y = PI # Facing +Z (towards kitchen)
	player.velocity = Vector3.ZERO
	
	key_w.pressed = true
	Input.parse_input_event(key_w)
	Input.flush_buffered_events()
	
	for f in 150:
		await physics_frame
		if f % 20 == 0:
			print("Walking UP kitchen stairs f=", f, ": pos=", player.global_position, " on_floor=", player.is_on_floor())
			
	key_w.pressed = false
	Input.parse_input_event(key_w)
	Input.flush_buffered_events()
	print("Position after walking up kitchen stairs: ", player.global_position)
	assert(player.global_position.y > -0.5, "Failed to walk up kitchen stairs!")

	print("ALL STAIR WALKING TESTS PASSED COMPLETELY!")
	quit(0)

