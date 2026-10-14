extends Node
var game: Node
var failures := 0
var checks := 0

func _check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: ",message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds,false,true).timeout

func _until(predicate: Callable, limit: float) -> bool:
	var elapsed := 0.0
	while elapsed<limit:
		if predicate.call(): return true
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	return bool(predicate.call())

func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _fixture(position: Vector3, yaw: float = 0) -> void:
	game.player.global_position = position
	game.player.rotation.y = yaw
	game.player._camera.rotation = Vector3.ZERO
	game.player.velocity = Vector3.ZERO
	await _wait(0.2)
	game.environment._on_player_moved()

func _reset() -> void:
	get_tree().reload_current_scene()
	await _wait(0.5)
	game = get_tree().current_scene
	await _until(func() -> bool: return game.navigation_is_ready,5)

func _freeze() -> void:
	game.monster.set_physics_process(false)
	game.familiar.set_physics_process(false)

func _interactable(kind: String) -> Dictionary:
	for entry in game.environment._interactables:
		if entry.kind==kind: return entry
	return {}

func _shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://design/house/"+name+".png")

func run(root: Node) -> void:
	game = root
	Engine.time_scale = 2
	_freeze()
	_check(game.house_mode and game.environment.builder.asset_instances>600,"F5 builds furnished Kenney house with surrounding neighborhood")
	_check(game.navigation_is_ready,"multi-level navigation bakes successfully")
	await _shot("foyer")
	await _fixture(Vector3(4.5,0.05,10.8))
	_key(KEY_W,true)
	await _wait(3.8)
	_key(KEY_W,false)
	_check(game.player.global_position.y>3.4,"player physically walks main staircase to second floor")
	await _shot("second_floor")
	await _fixture(Vector3(-7,0.05,1.8))
	_key(KEY_W,true)
	await _wait(3.8)
	_key(KEY_W,false)
	_check(game.player.global_position.y< -3.3,"kitchen stairs physically descend into basement")
	await _fixture(Vector3(-4,0.05,-3),PI/2)
	await _shot("kitchen")
	await _fixture(Vector3(0,3.65,-2.5))
	game.environment.interact(_interactable("hatch"))
	_check(not game.environment.attic_open,"boarded hatch cannot open without basement crowbar")
	await _fixture(Vector3(5,-3.55,-6.7))
	game.player._camera.look_at(Vector3(5,-2.55,-8))
	_key(KEY_E,true)
	_key(KEY_E,false)
	await _wait(0.1)
	_check(game.environment.has_crowbar and not game.environment.builder.crowbar.visible,"E picks up real basement crowbar once")
	game.environment.interact(_interactable("hatch"))
	await _wait(0.1)
	_check(game.environment.attic_open and game.environment.builder.ladder.visible and not game.environment.builder.has_node("HatchBlocker"),"crowbar removes ceiling boards and deploys pull-down ladder")
	await _fixture(Vector3(0,3.65,-1.6))
	game.environment.climb_ladder(true)
	await _until(func() -> bool: return not game.environment.climb_in_progress,4)
	_check(game.player.global_position.y>7 and game.player.is_physics_processing(),"E-style ladder climb reaches attic through ceiling opening and restores controls")
	await _shot("attic")
	game.environment.interact(_interactable("window"))
	_check(not game.environment.window_open,"attic window stays locked without Mother's key")
	game.environment.climb_ladder(false)
	await _until(func() -> bool: return not game.environment.climb_in_progress,4)
	_check(game.player.global_position.y<4,"attic ladder also descends to second floor")
	await _fixture(Vector3(0,3.65,-3.5),-PI/2)
	_key(KEY_E,true)
	_key(KEY_E,false)
	await _wait(0.15)
	_check(game.environment.builder.doors["mother_room"].open,"E opens Mother's real bedroom door and navigation link")
	_key(KEY_W,true)
	await _wait(0.6)
	_key(KEY_W,false)
	_check(game.player.global_position.x>1.7,"player physically passes bedroom doorway")
	await _fixture(Vector3(2.5,3.65,-5.5))
	game.player._camera.look_at(Vector3(3.5,4.325,-5.5))
	await _shot("mothers_room")
	_key(KEY_E,true)
	_key(KEY_E,false)
	await _wait(0.1)
	_check(game.environment.has_window_key,"E collects window key from Mother's room")
	game.environment.interact(_interactable("window"))
	_check(game.environment.window_open and game.environment.builder.window_barrier.collision_layer==0,"bedroom key unlocks attic window collision and glass")
	await _fixture(Vector3(0,7.25,10.6),PI)
	_key(KEY_W,true)
	await _wait(0.6)
	_key(KEY_W,false)
	_check(not game.environment.crossed_window,"walking at window sill is not an escape")
	await _fixture(Vector3(0,7.25,10.6),PI)
	_key(KEY_SPACE,true)
	_key(KEY_SPACE,false)
	_key(KEY_W,true)
	await _until(func() -> bool: return game.environment.crossed_window,2)
	_check(game.environment.crossed_window and game.environment.escape_progress!=3,"physical Space jump crosses window and begins landing sequence before victory")
	await _shot("window_jump")
	await _until(func() -> bool: return game.environment.escape_progress==3,4)
	_key(KEY_W,false)
	_check(game.environment.escape_progress==3 and game.player.global_position.y<0.5,"victory occurs only after physically landing outside")
	await _shot("neighborhood_landing")
	await _reset()
	_check(not game.environment.has_crowbar and not game.environment.has_window_key and not game.environment.attic_open and not game.environment.window_open and not game.environment.crossed_window,"restart resets crowbar, bedroom key, boards, window and landing")
	_freeze()
	for hide in game.environment.builder.hide_spots:
		var entry: Vector3 = hide.hide_config.entry
		await _fixture(entry+Vector3.UP*0.05)
		game.environment.interact(hide)
		var hidden := await _until(func() -> bool: return game.environment.is_hidden,4)
		_check(hidden,"collision-checked hiding works: "+str(hide.title))
		if hidden:
			game.environment._escape_from_hide()
			await _until(func() -> bool: return not game.player.is_transitioning(),4)
			_check(not game.environment.is_hidden,"player can leave "+str(hide.title))
		if game.environment.is_hidden:
			print("HIDE EXIT DIAGNOSTIC ",game.environment._status.text," standing=",game.player._has_standing_clearance()," position=",game.player.global_position)
			await _reset()
			_freeze()
	# Resume Monster takeover for the false-exit case.
	# The false exit is tested separately from the real attic escape.
	game.environment.interact({"kind":"door","door_id":"false_exit","position":Vector3(0,-2.6,12)})
	_check(game.environment.false_exit_attempted and game.environment.escape_progress==1,"trying false basement exit triggers interception without winning")
	var arrived := await _until(func() -> bool: return game.monster.arrived_for_interception,40)
	if not arrived:
		var route := NavigationServer3D.map_get_path(game.monster.agent.get_navigation_map(),game.monster.global_position,game.monster.interception_anchor.global_position,true)
		print("INTERCEPTION DIAGNOSTIC ",game.monster.global_position," route=",route)
	_check(arrived and game.environment.door_state["basement_door"]=="open","monster walks real stairs and basement passage before false exit opens")
	_check(game.environment.escape_progress!=3,"false exit never serves as real victory")
	await _reset()
	game.monster.global_position = Vector3(0,0.05,9)
	game.monster.look_at(Vector3(0,0.05,10.5))
	game.observation.set_test_suspicion(100)
	var captured := await _until(func() -> bool: return game.capture_started,3)
	_check(captured and game.capture_camera.current and int(game.audio.events.get("capture_sting",0))==1,"house pursuit triggers capture close-up and one jump-scare sting")
	await _wait(1.1)
	_check(game.environment.escape_progress==4 and game.environment._overlay.visible,"house capture ends in captured/restart screen")
	await _reset()
	_check(not game.capture_started and game.player.is_physics_processing() and game.observation.suspicion_level==0,"capture restart restores player and all threat controls")
	_freeze()
	await _fixture(Vector3(0,0.05,19),PI)
	await _shot("exterior_evening")
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(24,6,33)
	game.player._camera.look_at(Vector3(0,4,4))
	await _shot("house_exterior")
	Engine.time_scale = 1
	print("HOUSE CHECKS: ",checks," / failures: ",failures)
	get_tree().quit(0 if failures==0 else 1)
