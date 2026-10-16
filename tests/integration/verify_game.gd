extends Node
var game: Node
var failures := 0
var checks := 0

func _check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout

func _until(predicate: Callable, limit: float) -> bool:
	var elapsed := 0.0
	while elapsed < limit:
		if predicate.call():
			return true
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	return bool(predicate.call())

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _reset() -> void:
	get_tree().reload_current_scene()
	await _wait(0.5)
	game = get_tree().current_scene
	await _until(func() -> bool: return game.navigation_is_ready, 3)

func run(root: Node) -> void:
	game = root
	Engine.time_scale = 3
	_check(game.navigation_is_ready, "combined main scene has baked house navigation")
	var player_origin: Vector3 = game.player.global_position
	_key(KEY_W, true)
	await _wait(0.3)
	_key(KEY_W, false)
	_check(game.player.global_position.distance_to(player_origin) > 0.7 and game.player._camera.current, "combined main scene has controllable physical first-person movement")
	_check(game.monster.visual.find_children("*", "Skeleton3D", true, false).size() == 1 and game.visual_adapter.mother_instance == game.monster.visual, "Familiar and Monster share one visible rig")
	var origin: Vector3 = game.monster.global_position
	game.familiar.greeting_distance = 0
	await _wait(0.8)
	_check(game.monster.global_position.distance_to(origin) > 0.3 and not game.monster.is_physics_processing(), "Familiar routines move the shared body without duplicate movement")
	_key(KEY_2, true)
	_key(KEY_2, false)
	await _wait(0.3)
	var alertness_handoff: bool = game.observation.suspicion_level == 50 and game.familiar.behavior_stage == 1 and game.familiar.is_monster_controlled and game.monster.is_physics_processing()
	# Keep a real, unobstructed sighting stable without reaching capture range.
	# Only this fixture's tuning is changed; subsequent cases reload the scene.
	game.monster.tuning = game.monster.tuning.duplicate()
	game.monster.tuning.stalk_speed = 0
	game.monster.tuning.chase_speed = 0
	game.player.global_position = Vector3(0, 0.05, 7)
	game.monster.global_position = Vector3(0, 0.05, 3)
	game.monster.velocity = Vector3.ZERO
	game.monster.look_at(Vector3(0, 0.05, 7))
	var visual_pursuit := await _until(func() -> bool: return game.monster.sees_player and game.monster._visual_contact_seconds >= game.monster.tuning.distant_sight_confirm_seconds and game.monster.monster_state == MonsterController.State.PURSUING and game.monster.target == game.player, 2.0)
	_key(KEY_1, true)
	_key(KEY_1, false)
	await _wait(0.3)
	_check(alertness_handoff and visual_pursuit and game.observation.suspicion_level == 0 and game.monster.sees_player and game.monster.monster_state == MonsterController.State.PURSUING and game.monster.target == game.player and game.familiar.is_monster_controlled and game.monster.is_physics_processing() and not game._routine_active, "approved alertness input hands movement to Monster; zero temporary alertness preserves visually confirmed pursuit")
	# Reclaim is a separate case: remove sight and owned threat state, rather
	# than expecting a debug alertness reset to erase an active pursuit.
	game.player.global_position = Vector3(-5, 0.05, -3)
	game.monster.target = null
	game.monster.has_last_seen = false
	game.monster.sees_player = false
	game.monster._visual_contact_seconds = 0
	game.monster.encounter_cooldown = 0
	game.monster._change_state(MonsterController.State.DISGUISED)
	var threat_free: bool = not game.monster.can_see_player(game.read_monster_observation()) and game.monster.target == null and not game.monster.has_last_seen and game.monster.monster_state == MonsterController.State.DISGUISED and game.monster.encounter_cooldown == 0
	var routine_reclaimed := await _until(func() -> bool: return not game.familiar.is_monster_controlled and game._routine_active and game.monster.target == null, 1.0)
	_check(threat_free and routine_reclaimed and game.observation.suspicion_level == 0, "threat-free zero alertness reclaims the same body after sight, threat ownership and cooldown are cleared")
	await _reset()
	game.player.global_position = Vector3(0, 0.05, 1)
	game.environment._try_interact()
	_check(game.environment.door_state["basement_door"] == "locked" and int(game.audio.events.get("locked_door", 0)) == 1, "Environment owns locked door and audio feedback")
	game.player.global_position = Vector3(-3.5, 0.05, 5)
	game.environment._try_interact()
	_check(game.environment.has_basement_key and game.environment.escape_progress == 1 and int(game.audio.events.get("item_pickup", 0)) == 1, "real house key pickup starts escape progression with audio")
	game.player.global_position = Vector3(0, 0.05, 1)
	game.environment._try_interact()
	_check(game.door_requested and game.environment.door_state["basement_door"] == "locked", "early opening waits for physical interception")
	var previous: Vector3 = game.monster.global_position
	var continuous := true
	var elapsed := 0.0
	while elapsed < 25 and not game.monster.arrived_for_interception:
		await get_tree().physics_frame
		continuous = continuous and game.monster.global_position.distance_to(previous) < 0.4
		previous = game.monster.global_position
		elapsed += get_physics_process_delta_time()
	_check(game.monster.arrived_for_interception and continuous, "monster reaches basement through physical side passage without teleportation")
	await _wait(0.15)
	_check(game.environment.door_state["basement_door"] == "open" and game.door_link.enabled and game.monster.monster_state == MonsterController.State.REVEALING, "arrival opens Environment-owned door and starts reveal")
	await _wait(0.35)
	_check(not game.monster.basement_reveal_done, "readable reveal pause holds while player retains controls")
	await _wait(0.8)
	_check(game.monster.basement_reveal_done and game.observation.suspicion_level == 0, "reveal starts aggression without rewriting suspicion")
	# Reach the actual Environment exit during a fixture with the monster held back.
	game.monster.set_physics_process(false)
	game.player.global_position = Vector3(0, 0.05, -9)
	game.environment._try_interact()
	_check(game.environment.escape_progress == 3 and game.environment._overlay.visible and game.monster.target == null, "actual house escape stops both behavior controllers")
	await _reset()
	_check(game.observation.suspicion_level == 0 and not game.environment.has_basement_key and game.monster.target == null and not game.monster.arrived_for_interception and not game.capture_started and game.audio.events.is_empty(), "restart rebuilds every system with clean owned state")
	# Real crouch entry and raw stillness ensure the three-second rule is not doubled.
	game.familiar.set_physics_process(false)
	game.player.global_position = Vector3(5, 0.05, 6.9)
	await _wait(0.2)
	game.environment._try_interact()
	await _until(func() -> bool: return game.environment.is_hidden, 5)
	_check(game.environment.is_hidden and game.read_monster_observation().player_is_still, "completed house hiding publishes raw motionlessness without another three-second delay")
	# Isolate unseen concealment from the separate witnessed-entry rule.
	game.monster.knows_hiding_place = false
	game.monster._was_hidden = true
	game.monster.tuning = game.monster.tuning.duplicate()
	game.monster.tuning.stalk_speed = 0
	game.monster.tuning.chase_speed = 0
	game.observation.set_test_suspicion(100)
	game.monster.global_position = Vector3(5, 0.05, 8)
	game.monster.look_at(Vector3(5, 0.05, 5))
	await _wait(0.2)
	_check(not game.monster.can_see_player(game.read_monster_observation()), "crouched under-bed player is occluded at the actual camera height")
	game.monster.target = game.player
	game.monster.has_last_seen = true
	game.monster.last_seen_position = Vector3(5, 0.05, 6.9)
	game.monster._change_state(MonsterController.State.PURSUING)
	await _wait(1.5)
	_check(game.monster.hidden_still_time > 1 and game.monster.target != null, "house concealment accumulates the monster's three-second timer once")
	_key(KEY_W, true)
	await _wait(0.1)
	_check(game.monster.hidden_still_time < 0.2, "real movement input interrupts combined concealment")
	_key(KEY_W, false)
	# Re-enter cover after the Environment's movement-triggered exit finishes.
	await _until(func() -> bool: return not game.player.is_transitioning(), 4)
	game.environment._try_interact()
	await _until(func() -> bool: return game.environment.is_hidden, 5)
	game.monster.knows_hiding_place = false
	game.monster._was_hidden = true
	game.monster.hidden_still_time = 0
	game.monster.target = game.player
	game.monster.has_last_seen = true
	game.monster.last_seen_position = Vector3(5, 0.05, 6.9)
	game.monster._change_state(MonsterController.State.PURSUING)
	await _wait(2.5)
	_check(game.monster.target != null, "combined hidden target is retained before the full interval")
	await _wait(0.7)
	_check(game.monster.target == null and game.monster.monster_state == MonsterController.State.LOST_TARGET, "combined house hiding loses target after three seconds, not six")
	await _reset()
	game.monster.global_position = Vector3(0, 0.05, 5.5)
	game.monster.look_at(Vector3(0, 0.05, 7))
	game.monster.target = game.player
	game.monster._change_state(MonsterController.State.PURSUING)
	game.observation.set_test_suspicion(100)
	# Exercise the same close-encounter signal MainGame connects during play,
	# without relying on navigation timing in this compact integration fixture.
	game.monster._try_close_encounter()
	var qte_open := await _until(func() -> bool: return game.game_ui.get("qte_active"), 3)
	_check(qte_open and not game.capture_started and not game.capture_camera.current, "physical close encounter opens the five-second QTE before the capture presentation")
	if qte_open:
		game.game_ui.call("_finish_survival_qte", false)
	var captured := await _until(func() -> bool: return game.capture_started, 1)
	_check(captured and game.capture_camera.current and int(game.audio.events.get("capture_sting", 0)) == 1, "failed live QTE enters the capture close-up and plays one capture sting")
	await _wait(1.1)
	_check(game.environment.escape_progress == 4 and game.environment._overlay.visible, "capture presentation ends in Environment-owned captured screen")
	await _reset()
	_check(not game.capture_started and game.player.is_physics_processing() and not game.capture_camera.current and game.familiar.current_action != "staring", "capture restart restores player camera, routine and controls")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://design/monster_behavior/combined_game.png")
	Engine.time_scale = 1
	print("COMBINED GAME CHECKS: passed ", checks - failures, " / failed ", failures, " / total ", checks)
	get_tree().quit(1 if failures > 0 else 0)
