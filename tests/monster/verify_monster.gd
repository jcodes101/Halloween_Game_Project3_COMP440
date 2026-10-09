extends Node
## Integration checks use the actual physics bodies, navigation, doors and inputs.
var lab: Node
var failures := 0
var assertions := 0
var injected_observation: MonsterObservation

func run(world: Node) -> void:
	lab = world
	Engine.time_scale = 3.0
	await _wait(0.2)
	_check(lab.navigation_is_ready, "navigation baked and synchronized")
	await _player_controls()
	await _audio_events()
	await _recognition_and_capture()
	await _concealment_rules()
	await _search_completion()
	await _basement_interception()
	await _escape_and_reset()
	Engine.time_scale = 1.0
	print("MONSTER CHECKS: ", assertions, " assertions / ", failures, " failures")
	if failures == 0:
		print("ALL MONSTER BEHAVIOR TESTS PASSED")
	get_tree().quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

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

func _reset(player_position: Vector3 = Vector3(0, 0.05, 5), monster_position: Vector3 = Vector3(5, 0.05, 2)) -> void:
	lab.reset_lab(player_position, monster_position)
	lab.monster.set_physics_process(true)
	lab.player.set_physics_process(true)
	await _wait(0.15)

func _capture_image(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://design/monster_behavior")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://design/monster_behavior/" + name + ".png")

func _player_controls() -> void:
	await _reset()
	var origin: Vector3 = lab.player.global_position
	Input.action_press("monster_test_forward")
	await _wait(0.3)
	Input.action_release("monster_test_forward")
	var walked: float = origin.distance_to(lab.player.global_position)
	_check(walked > 0.7, "WASD moves the physical first-person character")
	origin = lab.player.global_position
	Input.action_press("monster_test_forward")
	Input.action_press("monster_test_sprint")
	await _wait(0.3)
	Input.action_release("monster_test_forward")
	Input.action_release("monster_test_sprint")
	_check(origin.distance_to(lab.player.global_position) > walked * 1.15, "sprint increases physical movement")
	_check(lab.player.camera.current, "first-person camera is active")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(40, 20)
		Input.parse_input_event(mouse)
		Input.flush_buffered_events()
		await _wait(0.1)
		_check(abs(lab.player.rotation.y) > 0.05 and abs(lab.player.camera.rotation.x) > 0.02, "mouse input controls yaw and pitch")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _capture_image("first_person_lab")

func _recognition_and_capture() -> void:
	await _reset()
	_check(lab.monster.monster_state == MonsterController.State.DISGUISED and lab.monster.target == null, "unaware maintains disguise without a target")
	var before: float = lab.monster.global_position.distance_to(lab.player.global_position)
	lab.suspicion_level = 50
	await _wait(0.6)
	_check(lab.monster.monster_state == MonsterController.State.STALKING, "doubtful recognition starts stalking")
	_check(int(lab.audio.events.get("mother_step", 0)) > 0, "physical monster movement emits spatial footsteps")
	_check(lab.monster.global_position.distance_to(lab.player.global_position) < before, "stalking follows a real navigation path")
	before = lab.monster.global_position.distance_to(lab.player.global_position)
	lab.suspicion_level = 100
	await _wait(0.25)
	_check(lab.monster.monster_state == MonsterController.State.PURSUING, "certain recognition pursues a visible reachable player")
	_check(lab.monster.global_position.distance_to(lab.player.global_position) < before, "pursuit moves toward the player")
	await _capture_image("pursuit")
	# A close player on the other side of a thin wall must not be captured.
	await _reset(Vector3(0, 0.05, 1.45), Vector3(0, 0.05, 0.55))
	var wall: StaticBody3D = lab._box("OcclusionFixture", Vector3(0, 1.2, 1), Vector3(2, 2.4, 0.18), Color.GRAY)
	lab.suspicion_level = 100
	await _wait(0.25)
	_check(not lab.monster.sees_player and lab.outcome.is_empty(), "wall occlusion prevents close-range capture")
	wall.queue_free()
	await _wait(0.1)
	# Check a shared snapshot is read without mutation by the threat controller.
	await _reset()
	lab.monster.tuning.chase_speed = 0
	injected_observation = lab.read_monster_observation()
	injected_observation.suspicion_level = 100
	var saved_position: Vector3 = injected_observation.player_location
	lab.monster.observation_provider = self
	await _wait(0.15)
	_check(injected_observation.suspicion_level == 100 and injected_observation.player_location == saved_position and not injected_observation.is_hidden and injected_observation.door_state == MonsterObservation.DoorState.CLOSED and injected_observation.escape_progress == MonsterObservation.EscapePhase.EXPLORING, "monster does not mutate other systems' input snapshot")
	lab.monster.observation_provider = lab
	# A real pursuit can capture and show the scare, then restart cleanly.
	await _reset(Vector3(0, 0.05, 5), Vector3(0, 0.05, 3.5))
	lab.suspicion_level = 100
	var captured := await _until(func() -> bool: return lab.outcome == "captured", 2.0)
	_check(captured and lab.monster.monster_state == MonsterController.State.CAPTURED, "reachable close pursuit captures once")
	_check(lab.capture_count == 1 and not lab.player.movement_enabled and lab.scare_camera.current, "capture freezes movement and activates the close-up")
	_check(int(lab.audio.events.get("capture_sting", 0)) == 1 and abs(MonsterLabAudio.EFFECTS["capture_sting"].get_length() - 1.0) < 0.01, "capture triggers one short jump-scare sting with the close-up")
	await _capture_image("capture_closeup")
	await _wait(1.1)
	_check(lab.end_panel.visible, "close-up ends on captured/restart screen")
	await _capture_image("captured_screen")
	await _reset()
	_check(lab.outcome.is_empty() and lab.player.movement_enabled and lab.player.camera.current and lab.monster.target == null and not lab.monster.has_last_seen and lab.monster.hidden_still_time == 0 and not lab.monster.basement_reveal_done, "capture restart resets target, memory, timers, camera and controls")

func read_monster_observation() -> MonsterObservation:
	return injected_observation

func _audio_events() -> void:
	await _reset()
	Input.action_press("monster_test_forward")
	await _wait(0.5)
	Input.action_release("monster_test_forward")
	_check(int(lab.audio.events.get("player_step", 0)) > 0, "actual player movement triggers footsteps")
	await _wait(0.15)
	var steps: int = lab.audio.events.get("player_step", 0)
	await _wait(0.5)
	_check(int(lab.audio.events.get("player_step", 0)) == steps, "stationary player emits no footsteps")
	lab.request_basement_door()
	_check(int(lab.audio.events.get("locked_door", 0)) == 1 and lab.door_state == MonsterObservation.DoorState.CLOSED, "locked-door attempt plays handle jiggle without opening")
	lab.open_basement_door()
	lab.open_basement_door()
	_check(int(lab.audio.events.get("door_open", 0)) == 1, "door opening sound occurs once per actual transition")
	lab.enter_closet()
	_check(int(lab.audio.events.get("door_close", 0)) == 1, "closet closing triggers wooden door audio")
	lab.pickup_test_item()
	lab.pickup_test_item()
	_check(int(lab.audio.events.get("item_pickup", 0)) == 1 and not lab.pickup_visual.visible, "sample pickup plays once and removes the sample")
	var playing := false
	for speaker in lab.audio.get_children():
		playing = playing or (speaker is AudioStreamPlayer3D and speaker.playing and speaker.stream.get_length() > 0)
	_check(playing, "approved audio streams decode and start spatial playback")
	await _reset()
	_check(lab.audio.events.is_empty() and lab.audio.get_child_count() == 0 and lab.pickup_visual.visible, "restart stops audio and restores sample item")

func _concealment_rules() -> void:
	# This stationary fixture isolates memory/stillness from locomotion.
	await _reset(Vector3(0, 0.05, 1), Vector3(0, 0.05, 5))
	lab.monster.tuning.chase_speed = 0
	lab.monster.tuning.stalk_speed = 0
	lab.suspicion_level = 100
	await _wait(0.15)
	lab.is_hidden = true
	lab.hiding_check_position = lab.player.global_position
	lab.player.hide_locked = true
	await _wait(3.2)
	_check(lab.monster.knows_hiding_place and lab.monster.target != null, "hiding in direct view does not erase player knowledge")
	await _reset(Vector3(0, 0.05, 1), Vector3(0, 0.05, 5))
	lab.monster.tuning.chase_speed = 0
	lab.monster.tuning.stalk_speed = 0
	lab.suspicion_level = 100
	await _wait(0.15)
	var remembered: Vector3 = lab.monster.last_seen_position
	var wall: StaticBody3D = lab._box("HideOccluder", Vector3(0, 1.2, 3), Vector3(2, 2.4, 0.3), Color.GRAY)
	await _wait(0.2)
	_check(lab.monster.monster_state == MonsterController.State.SEARCHING and not lab.monster.sees_player, "lost sight transitions pursuit to search")
	lab.is_hidden = true
	lab.player.hide_locked = true
	await _wait(1.5)
	_check(lab.monster.target != null and lab.monster.hidden_still_time > 1, "concealment requires the full stillness interval")
	Input.action_press("monster_test_forward")
	await _wait(0.2)
	_check(lab.monster.hidden_still_time < 0.1, "movement intent interrupts hidden stillness")
	Input.action_release("monster_test_forward")
	await _wait(2.6)
	_check(lab.monster.target != null, "target is retained before three seconds of uninterrupted stillness")
	await _wait(0.6)
	_check(lab.monster.monster_state == MonsterController.State.LOST_TARGET and lab.monster.target == null and not lab.monster.has_last_seen, "hidden out of sight and still for three seconds clears target")
	_check(lab.monster.last_seen_position == remembered, "search does not secretly update the hidden player's location")
	wall.queue_free()
	lab.is_hidden = false
	lab.player.hide_locked = false
	await _wait(0.2)
	_check(lab.monster.monster_state == MonsterController.State.PURSUING and lab.monster.target == lab.player, "visible player is reacquired after losing target")
	# The actual closet responds to the monster's check signal; the monster does
	# not overwrite Environment's hiding flag or open its door itself.
	await _reset(Vector3(-7, 0.05, 1.9), Vector3(-7, 0.05, 4.4))
	lab.suspicion_level = 100
	await _wait(0.1)
	lab.enter_closet()
	await _wait(0.1)
	_check(lab.monster.knows_hiding_place, "visible entry remembers the actual closet")
	var caught := await _until(func() -> bool: return lab.outcome == "captured", 4.0)
	_check(lab.checked_closet_count > 0 and caught, "monster checks a known closet, Environment exposes it, then physical pursuit captures")

func _search_completion() -> void:
	await _reset(Vector3(1, 0.05, 5), Vector3(1, 0.05, 1))
	lab.monster.tuning.chase_speed = 0
	lab.suspicion_level = 100
	await _wait(0.15)
	lab.player.set_physics_process(false)
	lab.player.global_position = Vector3(30, 0, 30)
	var start: Vector3 = lab.monster.global_position
	var lost := await _until(func() -> bool: return lab.monster.monster_state == MonsterController.State.LOST_TARGET, 24.0)
	_check(lost and lab.monster.target == null, "finite search route exhausts and clears an unseen non-hidden target")
	_check(lab.monster.global_position.distance_to(start) > 1 and lab.monster.destination.distance_to(lab.player.global_position) > 10, "search moves through remembered reachable points, not the unseen player position")

func _basement_interception() -> void:
	await _reset(Vector3(0, 0.05, -1), Vector3(5, 0.05, 2))
	lab.prepare_basement_route()
	var positioned := await _until(func() -> bool: return lab.monster.arrived_for_interception, 18.0)
	_check(positioned and lab.door_state == MonsterObservation.DoorState.CLOSED and lab.door_shadow.visible and lab.reveal_count == 0, "monster walks around the closed door and waits with a visible warning shadow")
	lab.request_basement_door()
	await _wait(0.15)
	_check(lab.monster.monster_state == MonsterController.State.REVEALING and lab.reveal_count == 1, "opening the prepared door reveals the waiting monster")
	_check((-lab.monster.global_basis.z).dot(lab.interception_marker.global_basis.z) > 0.99, "reveal faces the doorway after approaching around the house")
	await _capture_image("basement_reveal")
	await _reset(Vector3(-2, 0.05, -1), Vector3(5, 0.05, 2))
	lab.prepare_basement_route()
	lab.request_basement_door()
	await _wait(0.2)
	_check(lab.monster.monster_state == MonsterController.State.INTERCEPTING and not lab.monster.arrived_for_interception and lab.reveal_count == 0 and lab.door_state == MonsterObservation.DoorState.CLOSED, "early door request waits while interception moves into position")
	# Production must also tolerate an Environment owner opening the door early.
	lab.open_basement_door()
	var previous: Vector3 = lab.monster.global_position
	var continuous := true
	var elapsed := 0.0
	while elapsed < 14 and lab.monster.monster_state != MonsterController.State.REVEALING:
		await get_tree().physics_frame
		var moved: float = lab.monster.global_position.distance_to(previous)
		continuous = continuous and moved <= lab.monster.tuning.stalk_speed * get_physics_process_delta_time() + 0.12
		previous = lab.monster.global_position
		elapsed += get_physics_process_delta_time()
	_check(continuous, "interception follows continuous physical movement without teleportation")
	_check(lab.monster.monster_state == MonsterController.State.REVEALING and lab.monster.arrived_for_interception and lab.monster.global_position.distance_to(lab.interception_marker.global_position) < 0.65 and lab.reveal_count == 1, "reveal waits for actual arrival even when the door opens early")
	await _wait(0.35)
	_check(lab.monster.monster_state == MonsterController.State.REVEALING, "reveal holds for the readable one-second pause")
	await _wait(0.8)
	_check(lab.monster.basement_reveal_done and lab.monster.monster_state in [MonsterController.State.PURSUING, MonsterController.State.SEARCHING], "reveal leads to pursuit or last-seen search without changing suspicion")
	_check(lab.suspicion_level == 0, "basement aggression does not rewrite Observation suspicion")
	await _reset()
	var original_anchor: Vector3 = lab.interception_marker.global_position
	lab.interception_marker.global_position = Vector3(30, 0, 30)
	lab.prepare_basement_route()
	lab.open_basement_door()
	await _wait(0.4)
	_check(not lab.monster.arrived_for_interception and lab.reveal_count == 0, "unreachable interception position cannot falsely complete or reveal")
	lab.interception_marker.global_position = original_anchor

func _escape_and_reset() -> void:
	await _reset(Vector3(-7, 0.05, 7.5), Vector3(5, 0.05, 2))
	lab.suspicion_level = 100
	await _wait(0.1)
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.pressed = true
	Input.parse_input_event(interact)
	Input.flush_buffered_events()
	await _wait(0.15)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	_check(lab.outcome == "escaped" and lab.end_panel.visible and lab.escape_progress == MonsterObservation.EscapePhase.ESCAPED, "first-person E interaction completes the safe test escape")
	_check(lab.monster.target == null and Vector2(lab.monster.velocity.x, lab.monster.velocity.z).length() == 0, "escape stops targeting and movement")
	await _capture_image("test_escape")
	await _reset()
	_check(lab.door_state == MonsterObservation.DoorState.CLOSED and lab.escape_progress == MonsterObservation.EscapePhase.EXPLORING and not lab.is_hidden and lab.suspicion_level == 0 and lab.outcome.is_empty() and not lab.monster.arrived_for_interception and lab.monster.reveal_elapsed == 0, "escape restart resets all simulated owners and interception state")
