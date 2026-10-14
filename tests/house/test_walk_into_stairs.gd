extends SceneTree

func _init() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	
	# Raycast from (4.5, 0.5, 11) into the stairs along -Z: (4.5, 0.5, 8)
	print("--- RAYCASTS ALONG STAIRS ---")
	for y in [0.1, 0.5, 1.0, 1.5, 2.0]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(4.5, y, 11.0), Vector3(4.5, y, 9.0))
		var hit: Dictionary = space.intersect_ray(ray)
		print("Ray at y=", y, " hit=", hit)

	# Now test walking from (4.5, 0.1, 11.0) into the stairs:
	var player: CharacterBody3D = main.player
	player.global_position = Vector3(4.5, 0.1, 11.0)
	player.rotation.y = 0 # Facing -Z (straight at stairs)
	
	# What if player is looking slightly down? E.g. camera tilted down by 15 degrees:
	player._camera.rotation.x = deg_to_rad(-15)
	
	print("--- TEST PLAYER WALKING FORWARD INTO STAIRS ---")
	for f in 60:
		# Simulate W pressed
		var dir := -player.global_transform.basis.z
		player.velocity.x = dir.x * 4.2
		player.velocity.z = dir.z * 4.2
		if not player.is_on_floor():
			player.velocity.y -= 18.0 * (1.0 / 60.0)
		else:
			player.velocity.y = -0.5
		player.move_and_slide()
		await physics_frame
		print("f=", f, " pos=", player.global_position, " on_floor=", player.is_on_floor(), " on_wall=", player.is_on_wall(), " vel=", player.velocity, " real_vel=", player.get_real_velocity())
		if player.get_slide_collision_count() > 0:
			for c in player.get_slide_collision_count():
				var col := player.get_slide_collision(c)
				print("   col c=", c, " norm=", col.get_normal(), " angle=", rad_to_deg(col.get_angle()), " collider=", col.get_collider().name)
		if f > 20 and player.get_real_velocity().length() < 0.1:
			print("BLOCKED AT f=", f, " pos=", player.global_position)
			break

	quit(0)

