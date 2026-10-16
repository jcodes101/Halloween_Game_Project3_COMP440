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

func _confirm_test_evidence(count: int) -> void:
	for index in count:
		game.observation_coordinator.manager.confirm_clue("house_test_%d" % index)

func _interactable(kind: String) -> Dictionary:
	for entry in game.environment._interactables:
		if entry.kind==kind: return entry
	return {}

func _battery_interactable(floor_name: String, excluded_id: int = -1) -> Dictionary:
	for entry in game.environment._interactables:
		if entry.kind != "battery" or str(entry.get("floor", "")) != floor_name:
			continue
		if int(entry.get("pickup_id", -1)) == excluded_id or not is_instance_valid(entry.get("pickup_node")):
			continue
		return entry
	return {}

func _battery_roll_signature(spawns: Array) -> Array[String]:
	var signature: Array[String] = []
	for spawn in spawns:
		signature.append("%s:%s" % [str(spawn.floor), str(spawn.position)])
	return signature

func _verify_batteries() -> void:
	var environment: Node = game.environment
	var battery_nodes: Array = environment.get("battery_pickups")
	var floor_counts: Dictionary = environment.get("battery_spawn_floor_counts")
	_check(battery_nodes.size() in [6,7,8], "6–8 randomized battery pickups spawn each run")
	_check(["Basement", "Ground Floor", "Second Floor", "Attic"].all(func(floor_name: String) -> bool: return int(floor_counts.get(floor_name, 0)) >= 1), "battery spawn selection guarantees at least one reachable pickup per floor")
	var seeded_a: Array = environment.call("_roll_battery_spawn_points", 73421)
	var seeded_b: Array = environment.call("_roll_battery_spawn_points", 73421)
	var seeded_c: Array = environment.call("_roll_battery_spawn_points", 91827)
	var signature_a := _battery_roll_signature(seeded_a)
	_check(signature_a == _battery_roll_signature(seeded_b), "battery spawn seed reproduces the same curated selection")
	_check(signature_a != _battery_roll_signature(seeded_c), "different battery seeds produce a different curated selection")
	var unique_positions: Dictionary = {}
	var positions_valid := true
	for spawn in seeded_a:
		var point: Vector3 = spawn.position
		var location_key := "%s" % point
		positions_valid = positions_valid and not unique_positions.has(location_key)
		unique_positions[location_key] = true
		var valid_floor := absf(point.y + 3.6) < 0.01 or absf(point.y) < 0.01 or absf(point.y - 3.6) < 0.01 or absf(point.y - 7.2) < 0.01
		positions_valid = positions_valid and absf(point.x) <= 10.0 and point.z >= -21.0 and point.z <= 10.0 and valid_floor
	_check(positions_valid and unique_positions.size() == seeded_a.size(), "battery positions are unique and lie within curated floor bounds")
	var first := _battery_interactable("Ground Floor")
	var first_pickup := first.get("pickup_node") as Node3D
	_check(not first.is_empty() and is_instance_valid(first_pickup), "a ground-floor battery has a live pickup node and existing interaction prompt")
	if not first.is_empty() and is_instance_valid(first_pickup):
		var first_id := int(first.get("pickup_id", -1))
		await _fixture(first_pickup.global_position + Vector3(0,0,1.0), 0.0)
		game.player.flashlight.call("_set_flashlight_enabled", false)
		game.player.flashlight.call("_set_battery", 30.0)
		game.environment.call("_try_interact")
		_check(is_equal_approx(float(game.player.flashlight.get("battery_percent")), 65.0), "collectible battery restores 35 percentage points through the real environment interaction")
		_check(int(game.audio.events.get("item_pickup", 0)) > 0, "battery collection reuses the existing pickup sound")
		_check(is_equal_approx(float(game.game_ui.get("_battery_bar").value), 65.0), "existing flashlight HUD updates immediately after pickup")
		_check(first_pickup.is_queued_for_deletion() and environment.get("_collected_battery_ids").has(first_id), "collected battery is removed and cannot be collected twice")
		game.player.flashlight.call("_set_battery", 0.0)
		game.player.flashlight.call("_set_flashlight_enabled", false)
		var depleted_toggle_rejected: bool = not bool(game.player.flashlight.call("toggle_flashlight"))
		game.player.flashlight.call("recharge_battery", 35.0)
		_check(depleted_toggle_rejected and is_equal_approx(float(game.player.flashlight.get("battery_percent")), 35.0) and bool(game.player.flashlight.call("toggle_flashlight")), "recharge from zero restores 35 percent and allows the beam to turn back on")
		game.player.flashlight.call("_set_flashlight_enabled", false)
		game.player.flashlight.call("_set_battery", 90.0)
		game.player.flashlight.call("recharge_battery", 35.0)
		_check(is_equal_approx(float(game.player.flashlight.get("battery_percent")), 100.0), "battery recharge clamps at the flashlight maximum")
	await _reset()
	_check(game.environment.battery_pickups.size() in [6,7,8] and is_equal_approx(float(game.player.flashlight.get("battery_percent")),100.0) and game.environment.get("_collected_battery_ids").is_empty(), "restarting restores full flashlight charge and spawns a fresh battery set")

func _verify_dynamic_music() -> void:
	var manager: Node = game.music_manager
	_check(manager != null and manager.get("current_mood") == "exploration" and manager.call("has_track_for_state", MonsterController.State.PURSUING) == manager.has_asset("chase"), "music manager starts in exploration mode and safely reflects optional discovered soundtrack files")
	_check(manager.detected_assets.size() == 7 and manager.missing_assets.is_empty(), "all seven matching MP3/WAV/OGG music assets are discovered")
	_check(manager.process_mode == Node.PROCESS_MODE_PAUSABLE and manager.get("_players").chase.process_mode == Node.PROCESS_MODE_PAUSABLE, "music processing and playback pause with the game tree")
	var players: Dictionary = manager.get("_players")
	var streams_assigned := true
	for mood in ["exploration", "investigation", "chase", "hiding"]:
		var player := players[mood] as AudioStreamPlayer
		streams_assigned = streams_assigned and player.stream != null and player.bus == "Music"
	_check(streams_assigned and manager.qte_sting_track != null and manager.escape_ending_track != null and manager.capture_ending_track != null, "all seven real gameplay music assets are assigned to the manager")
	var loops_valid: bool = manager.exploration_track is AudioStreamMP3 and manager.exploration_track.loop and manager.investigation_track is AudioStreamMP3 and manager.investigation_track.loop and manager.chase_track is AudioStreamMP3 and manager.chase_track.loop and manager.hiding_track is AudioStreamMP3 and manager.hiding_track.loop
	_check(loops_valid and manager.qte_sting_track is AudioStreamWAV and manager.qte_sting_track.loop_mode == AudioStreamWAV.LOOP_DISABLED and manager.escape_ending_track.loop_mode == AudioStreamWAV.LOOP_DISABLED and manager.capture_ending_track.loop_mode == AudioStreamWAV.LOOP_DISABLED, "loop tracks loop and all three WAV cues remain one-shot")
	var exploration_player: AudioStreamPlayer = players.exploration
	manager.call("_process", 1.0)
	_check(manager.active_track_name == "exploration" and exploration_player.playing and exploration_player.volume_db > -60.0, "normal Familiar routine starts looping exploration music and fades it in")
	var exploration_volume_before: float = exploration_player.volume_db
	game.monster._change_state(MonsterController.State.STALKING)
	var investigation_player: AudioStreamPlayer = players.investigation
	var investigation_volume_before: float = investigation_player.volume_db
	manager.call("_process", 0.5)
	_check(manager.get("current_mood") == "investigation" and investigation_player.playing and investigation_player.volume_db > investigation_volume_before and exploration_player.volume_db < exploration_volume_before, "actual monster suspicion state selects investigation music and crossfades both active tracks")
	game.monster._change_state(MonsterController.State.PURSUING)
	manager.call("_process", 0.8)
	var chase_player: AudioStreamPlayer = players.chase
	_check(manager.get("current_mood") == "chase" and chase_player.playing and chase_player.volume_db > investigation_player.volume_db, "actual pursuit state selects and crossfades to chase music")
	game.monster._change_state(MonsterController.State.DISGUISED)
	var hide_spot: Dictionary = game.environment.builder.hide_spots.filter(func(entry: Dictionary) -> bool: return str(entry.title) == "Hide behind sofa")[0]
	var hide_position: Vector3 = hide_spot.hide_config.entry
	await _fixture(hide_position + Vector3.UP * 0.05)
	game.observation.set_test_suspicion(50.0)
	game._physics_process(1.0 / 60.0)
	game.monster.set_physics_process(false)
	game.familiar.set_physics_process(false)
	game.monster.global_position = hide_position + Vector3(0, 0, -6)
	game.monster.rotation.y = 0.0
	game.monster._change_state(MonsterController.State.SEARCHING)
	game.environment.interact(hide_spot)
	var entered := await _until(func() -> bool: return game.environment.is_hidden, 3.0)
	await _wait(0.1)
	_check(entered and manager.active_track_name == "hiding" and players.hiding.playing, "real hiding transition under nearby Familiar search selects the looping hiding track")
	game.environment._escape_from_hide()
	var left_hiding := await _until(func() -> bool: return not game.environment.is_hidden and not game.player.is_transitioning(), 3.0)
	await _wait(0.1)
	if not left_hiding:
		print("HIDING MUSIC DIAGNOSTIC: hidden=", game.environment.is_hidden, " transitioning=", game.player.is_transitioning(), " cue=", manager.active_track_name)
	_check(left_hiding and manager.active_track_name != "hiding", "leaving the hiding spot returns to the current Familiar-state music")
	_check(manager.get_child_count() == 5, "music manager uses four loop players and one shared one-shot player without duplicates")
	var patrol_script := preload("res://systems/familiar/familiar_controller.gd")
	var patrol_a: Node = patrol_script.new()
	var patrol_b: Node = patrol_script.new()
	patrol_a.set("routine_random_seed", 73421)
	patrol_b.set("routine_random_seed", 73421)
	add_child(patrol_a)
	add_child(patrol_b)
	var route_a: Array[int] = []
	var route_b: Array[int] = []
	for _visit in 10:
		route_a.append(int(patrol_a.call("_next_station_index", 5)))
		route_b.append(int(patrol_b.call("_next_station_index", 5)))
	var first_cycle: Dictionary = {}
	var second_cycle: Dictionary = {}
	for index in 5:
		first_cycle[route_a[index]] = true
		second_cycle[route_a[index + 5]] = true
	_check(route_a == route_b and first_cycle.size() == 5 and second_cycle.size() == 5 and route_a[4] != route_a[5], "seeded household patrols visit shuffled stations once per cycle without immediate repetition")
	patrol_a.queue_free()
	patrol_b.queue_free()
	await _reset()
	_freeze()

func _trigger_live_capture_qte(charge: float, flashlight_enabled: bool) -> void:
	if game.game_ui.get("menu_open"):
		game.game_ui.call("close_menu")
	if get_tree().paused:
		get_tree().paused = false
	await _fixture(Vector3(0,0.1,10.5), 0.0)
	game.player.set_qte_locked(false)
	game.player.flashlight.call("_set_flashlight_enabled", false)
	game.player.flashlight.call("_set_battery", charge)
	if flashlight_enabled:
		game.player.flashlight.call("_set_flashlight_enabled", true)
	game.observation.set_test_suspicion(100.0)
	_confirm_test_evidence(3)
	var close_position: Vector3 = game.player.global_position + Vector3(0.55,0.0,0.0)
	game.monster.reset_controller(close_position)
	game.monster.look_at(game.player.global_position)
	# Run the real controller's perception/pursuit tick. Its normal collision
	# decision emits close_encounter_requested into main_game and the live HUD.
	game.monster._physics_process(1.0 / 60.0)

func _send_ui_key(ui: Node, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	ui.call("_input", event)

func _verify_live_capture_qte() -> void:
	var ui: Node = game.game_ui
	ui.set("qte_random_seed", 73421)
	ui.call("_initialize_qte_rng")
	ui.set("_previous_qte_sequence", [])
	var generated_a: Array = ui.call("_generate_qte_sequence")
	ui.set("_previous_qte_sequence", generated_a.duplicate())
	var generated_b: Array = ui.call("_generate_qte_sequence")
	var valid_keys := generated_a.size() == 3 and generated_a.all(func(code: int) -> bool: return code in [KEY_Q, KEY_E, KEY_R, KEY_F])
	_check(valid_keys and generated_a != generated_b, "QTE generation uses three allowed keys and avoids immediate exact repeats")
	ui.set("qte_random_seed", 0)
	ui.call("_initialize_qte_rng")
	ui.set("_previous_qte_sequence", [])
	await _trigger_live_capture_qte(100.0, true)
	_check(game.monster.encounter_pending and ui.get("qte_active") and bool(game.player.get("_qte_locked")) and is_equal_approx(float(ui.get("_qte_duration")),5.0), "live Familiar capture at full battery opens the five-second QTE and locks movement")
	var active_sequence: Array = ui.get("_qte_sequence").duplicate()
	var music: Node = game.music_manager
	_check(music.cue_play_counts.qte_sting == 1 and music._cue_player.stream == music.qte_sting_track and music._cue_player.playing, "real Familiar capture/QTE event starts the QTE sting once")
	game.monster._physics_process(1.0 / 60.0)
	_check(bool(ui.get("qte_active")) and int(ui.get("_qte_index")) == 0, "repeated close-range physics ticks do not create a duplicate encounter or advance the QTE")
	var remaining := float(ui.get("_qte_remaining"))
	_send_ui_key(ui, KEY_TAB)
	ui.call("_process", 1.0)
	_check(bool(ui.get("qte_active")) and bool(ui.get("menu_open")) and get_tree().paused and is_equal_approx(float(ui.get("_qte_remaining")),remaining) and ui.get("_qte_sequence") == active_sequence, "pause menu freezes the QTE countdown and preserves its generated sequence")
	_send_ui_key(ui, KEY_R)
	var flashlight_was_on := bool(game.player.flashlight.get("flashlight_is_on"))
	var qte_charge := float(game.player.flashlight.get("battery_percent"))
	_send_ui_key(ui, KEY_F)
	_send_ui_key(ui, KEY_E)
	_check(not bool(ui.get("confirmation_active")) and bool(game.player.flashlight.get("flashlight_is_on")) == flashlight_was_on and is_equal_approx(float(game.player.flashlight.get("battery_percent")), qte_charge), "paused QTE consumes R/F/E without restart, flashlight, or interaction side effects")
	_send_ui_key(ui, KEY_ESCAPE)
	_check(not bool(ui.get("menu_open")) and not get_tree().paused, "Escape resumes a paused capture QTE")
	for code in active_sequence:
		_send_ui_key(ui, code)
	_check(not bool(ui.get("qte_active")) and not bool(game.monster.encounter_pending) and float(game.monster.encounter_cooldown)>0.0 and float(game.monster.stun_remaining)>0.0 and not bool(game.player.get("_qte_locked")) and bool(game.monster.get("stun_visual_active")), "randomized QTE success triggers visible recoil, restores control and enables recapture protection")
	var before_recoil: float = game.monster.global_position.distance_to(game.player.global_position)
	var stun_position: Vector3 = game.monster.global_position
	game.monster._physics_process(0.25)
	_check(game.monster.global_position.distance_to(game.player.global_position)>before_recoil and float(game.monster.stun_remaining)<1.0 and absf(game.monster.visual.rotation.x) > 0.01 and game.player.get("_qte_shove_tween") != null, "successful QTE physically staggers and tilts the Familiar while the player's camera reacts")
	var began_retreat := await _until(func() -> bool: return game.monster.monster_state == MonsterController.State.RETREATING, 3.0)
	var entered_recovery := await _until(func() -> bool: return game.monster.monster_state == MonsterController.State.RECOVERING, 6.0)
	_check(began_retreat and entered_recovery and game.monster.global_position.distance_to(stun_position) > 1.0 and game.monster.encounter_cooldown > 0.0, "live QTE success makes the Familiar run along a reachable route before a protected recovery phase")
	var resumed_after_retreat := await _until(func() -> bool: return game.monster.monster_state not in [MonsterController.State.STUNNED, MonsterController.State.RETREATING, MonsterController.State.RECOVERING], 4.0)
	_check(resumed_after_retreat and game.monster.encounter_cooldown > 0.0 and not game.capture_started, "retreat recovery returns to search without immediate recapture")

	await _trigger_live_capture_qte(50.0, false)
	_check(game.monster.encounter_pending and bool(ui.get("qte_active")) and not bool(game.player.flashlight.get("flashlight_is_on")), "live capture at 50 percent with the flashlight off still opens QTE")
	_check(music.cue_play_counts.qte_sting == 2 and music._cue_player.stream == music.qte_sting_track and music._cue_player.playing, "a second physical capture starts one new QTE sting for its own encounter")
	_send_ui_key(ui, KEY_W)
	_check(int(ui.get("_qte_index")) == 0, "incorrect QTE input does not satisfy or skip the required sequence")
	ui.call("_process", 5.1)
	await _wait(1.1)
	_check(not bool(ui.get("qte_active")) and bool(game.capture_started) and game.environment.escape_progress==game.environment.EscapeProgress.CAPTURED and bool(ui.get("ending_active")), "QTE timeout routes through the existing capture cutscene and ending")
	_check(game.music_manager.cue_play_counts.capture_ending == 1 and game.music_manager._cue_player.stream == game.music_manager.capture_ending_track, "QTE failure reaches the capture ending cue through the live capture signal")
	await _reset()
	ui = game.game_ui
	await _trigger_live_capture_qte(0.0, false)
	_check(game.monster.encounter_pending and bool(ui.get("qte_active")) and is_equal_approx(float(ui.get("_qte_duration")),5.0), "live capture at zero charge with the flashlight off still opens the QTE")
	var zero_charge_sequence: Array = ui.get("_qte_sequence").duplicate()
	for code in zero_charge_sequence:
		_send_ui_key(ui, code)
	_check(not bool(ui.get("qte_active")) and not bool(game.capture_started) and game.monster.encounter_cooldown>0.0, "zero-charge successful QTE escapes without triggering the capture ending")
	await _reset()

func _verify_flashlight() -> void:
	var flashlight: Node = game.player.flashlight
	_check(flashlight != null and game.player.get_node_or_null("PlayerCamera/FlashlightBeam") != null, "flashlight spotlight is attached to the player camera")
	_check(not flashlight.get("flashlight_is_on") and is_equal_approx(float(flashlight.get("battery_percent")),100.0), "flashlight starts off with a full battery")
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F
	toggle.physical_keycode = KEY_F
	toggle.pressed = true
	game.player._unhandled_input(toggle)
	_check(bool(flashlight.get("flashlight_is_on")), "F toggles the flashlight on")
	flashlight.call("_process",30.0)
	var after_drain := float(flashlight.get("battery_percent"))
	_check(after_drain >= 74.0 and after_drain <= 76.0, "continuous use drains approximately 25 percent in 30 seconds")
	game.player._unhandled_input(toggle)
	var while_off := float(flashlight.get("battery_percent"))
	flashlight.call("_process",20.0)
	_check(not bool(flashlight.get("flashlight_is_on")) and is_equal_approx(float(flashlight.get("battery_percent")),while_off), "switching the flashlight off conserves battery")
	flashlight.set("battery_percent",25.0)
	flashlight.call("_refresh_battery_state")
	_check(bool(flashlight.get("flicker_active")), "low-battery flicker activates at 25 percent")
	var severity_at_25: float = flashlight.call("_flicker_severity")
	flashlight.set("battery_percent",10.0)
	flashlight.call("_refresh_battery_state")
	var severity_at_10: float = flashlight.call("_flicker_severity")
	_check(severity_at_10 > severity_at_25, "flicker severity increases at critical battery")
	flashlight.call("_set_flashlight_enabled",true)
	flashlight.set("_flicker_wait",0.0)
	flashlight.call("_process",0.01)
	_check(bool(flashlight.get("_flicker_dark")) and not bool(flashlight.get_node("../PlayerCamera/FlashlightBeam").visible), "low-battery flicker briefly cuts the beam")
	flashlight.call("_process",0.2)
	_check(bool(flashlight.get_node("../PlayerCamera/FlashlightBeam").visible), "flashlight beam returns after the brief flicker")
	var depleted_events: Array[int] = []
	flashlight.connect("battery_depleted",func() -> void: depleted_events.append(1))
	flashlight.set("battery_percent",0.0)
	flashlight.call("_process",0.01)
	_check(not bool(flashlight.get("flashlight_is_on")) and depleted_events.size()==1, "empty battery shuts off the beam and emits depletion")
	_check(not bool(flashlight.call("toggle_flashlight")), "depleted flashlight cannot be switched back on")
	flashlight.call("_set_battery",100.0)
	flashlight.call("_set_flashlight_enabled",false)

func _verify_vhs_effect() -> void:
	var effect: Node = game.vhs_effect
	var overlay := effect.get_node("VHSOverlayLayer/VHSOverlay") as ColorRect
	_check(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.focus_mode == Control.FOCUS_NONE, "VHS overlay does not capture input or keyboard focus")
	_check(game.battery_label.visible and float(effect.get("baseline_intensity")) > 0.0, "flashlight HUD remains separate from a subtle baseline VHS layer")
	var baseline := float(effect.call("intensity_for_distance",30.0))
	var at_far_threshold := float(effect.call("intensity_for_distance",18.0))
	var at_mid_range := float(effect.call("intensity_for_distance",14.0))
	var at_mid_threshold := float(effect.call("intensity_for_distance",10.0))
	var near_range := float(effect.call("intensity_for_distance",7.0))
	var at_close_threshold := float(effect.call("intensity_for_distance",4.0))
	_check(is_equal_approx(baseline,at_far_threshold) and at_mid_range > baseline and at_mid_range < at_mid_threshold, "VHS target intensity rises smoothly from 18 to 10 meters")
	_check(near_range > at_mid_threshold and absf(at_close_threshold-float(effect.get("maximum_intensity")))<0.001, "VHS intensity increases through 10 to 4 meters and caps nearby")
	var original_monster_position: Vector3 = game.monster.global_position
	effect.set("current_intensity",baseline)
	game.monster.global_position = game.player.global_position + Vector3(12.0,0.0,0.0)
	var live_target: float = effect.call("_target_intensity")
	effect.call("_process",0.1)
	var approaching_intensity := float(effect.get("current_intensity"))
	_check(approaching_intensity > baseline and approaching_intensity < live_target, "live player-monster distance drives a smoothed intensity increase")
	game.monster.global_position = game.player.global_position + Vector3(2.0,0.0,0.0)
	effect.call("_process",0.1)
	var close_intensity := float(effect.get("current_intensity"))
	_check(close_intensity > approaching_intensity and close_intensity < float(effect.get("maximum_intensity")), "approaching monster raises effect without an abrupt jump")
	game.monster.global_position = game.player.global_position + Vector3(30.0,0.0,0.0)
	effect.call("_process",2.0)
	_check(absf(float(effect.get("current_intensity"))-baseline)<0.01, "VHS intensity smoothly returns to baseline as the monster leaves")
	game.monster.set("monster_state",MonsterController.State.CAPTURED)
	_check(is_equal_approx(float(effect.call("_target_intensity")),baseline), "captured/inactive monster leaves VHS at baseline")
	game.monster.set("monster_state",MonsterController.State.DISGUISED)
	game.monster.global_position = original_monster_position

func _verify_house_atmosphere() -> void:
	var builder: Node = game.environment.builder
	var atmosphere: Node = builder.atmosphere
	var world_nodes := builder.find_children("*", "WorldEnvironment", true, false)
	var world_darkened := false
	if not world_nodes.is_empty():
		var world := world_nodes[0] as WorldEnvironment
		world_darkened = world.environment.ambient_light_energy <= 0.25 and world.environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC
	for light in builder.find_children("*", "DirectionalLight3D", true, false):
		world_darkened = world_darkened and (light as DirectionalLight3D).light_energy <= 0.25
	_check(world_darkened and float(builder.get("practical_light_scale"))<1.0, "house night ambience and moonlight are reduced while practical lamps remain separately tunable")
	var screens: Array = atmosphere.get("television_screens")
	_check(screens.size()==2, "CRT effect attaches to both existing television screen surfaces")
	var all_screen_shaders := screens.size()==2
	for screen in screens:
		var found_crt_surface := false
		for surface in screen.mesh.get_surface_count():
			if screen.mesh.surface_get_name(surface).to_lower()=="metaldark":
				var material := screen.get_surface_override_material(surface) as ShaderMaterial
				found_crt_surface = material!=null and material.shader.resource_path.ends_with("crt_screen.gdshader")
		all_screen_shaders = all_screen_shaders and found_crt_surface
	_check(all_screen_shaders, "animated CRT material is bound specifically to the metalDark display surface")
	var steam: GPUParticles3D = atmosphere.get("steam_emitter")
	_check(steam != null and steam.emitting and steam.amount<=20 and steam.global_position.distance_to(Vector3(-4.0,1.04,-6.05))<0.05, "low-count steam particles rise from the existing kitchen stove surface")
	var tv_audio: Array = atmosphere.get("television_players")
	var audio_ok := tv_audio.size()==2
	for speaker in tv_audio:
		audio_ok = audio_ok and speaker.stream is AudioStreamWAV and speaker.max_distance<=7.0
		if DisplayServer.get_name()=="headless":
			audio_ok = audio_ok and not speaker.playing
		else:
			audio_ok = audio_ok and speaker.playing
	_check(audio_ok, "quiet spatial static is configured at both televisions and starts when audio is available")
	var lights: Array = atmosphere.get("flickering_lights")
	var states: Array = atmosphere.get("_flicker_states")
	var light: OmniLight3D = lights[0]
	var base_energy := float(states[0].base_energy)
	states[0].wait = 0.0
	atmosphere.call("_process",0.1)
	var dipped_energy := light.light_energy
	_check(lights.size()==2 and dipped_energy<base_energy and dipped_energy>base_energy*0.75, "selected hallway light dips gently without going dark")
	atmosphere.call("_process",0.5)
	_check(light.light_energy>dipped_energy and light.light_energy<=base_energy+0.01, "hallway light recovers smoothly after a brief dip")

func _verify_hud_menu_and_input() -> void:
	var ui: Node = game.game_ui
	_check(ui != null and ui.get_node_or_null("SharedGameUI") != null, "single shared HUD is created by the main game integration")
	_check(game.environment.get_node_or_null("LegacyHudStateLayer") != null and not game.environment.get_node("LegacyHudStateLayer").visible, "environment legacy state labels remain hidden beneath the single visible HUD")
	_check(ui.get("_battery_bar") != null and ui.get("_location_label") != null and ui.get("_interaction_label") != null, "location, contextual prompt and flashlight indicators are present")
	_check(game.environment.objective_text() != "" and ui.get("_hide_bar") != null, "objective data and hiding progress presentation are connected")
	_check(InputMap.has_action("move_forward") and InputMap.has_action("move_backward") and InputMap.has_action("move_left") and InputMap.has_action("move_right"), "movement uses explicit directional InputMap actions")
	for entry in [["move_forward",KEY_W],["move_forward",KEY_UP],["move_backward",KEY_S],["move_backward",KEY_DOWN],["move_left",KEY_A],["move_left",KEY_LEFT],["move_right",KEY_D],["move_right",KEY_RIGHT]]:
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		_check(InputMap.event_is_action(event,entry[0]), "WASD and arrow key are equivalent for %s" % entry[0])
	var original_sensitivity := float(game.player.get("mouse_sensitivity"))
	ui.call("_apply_setting","sensitivity",1.5)
	_check(is_equal_approx(float(game.player.get("mouse_sensitivity")),0.0033), "mouse sensitivity setting applies to the existing camera controller")
	ui.call("_apply_setting","sensitivity",original_sensitivity/0.0022)
	var original_vhs := float(game.vhs_effect.get("user_intensity_scale"))
	ui.call("_apply_setting","vhs",0.6)
	_check(is_equal_approx(float(game.vhs_effect.get("user_intensity_scale")),0.6), "VHS setting scales the existing proximity effect")
	ui.call("_apply_setting","vhs",original_vhs)
	ui.call("_apply_setting","camera_motion",0.0)
	_check(is_equal_approx(float(game.player.get("camera_motion_intensity")),0.0), "camera motion setting fully disables bob and sway")
	ui.call("_apply_setting","camera_motion",100.0)
	_check(is_equal_approx(float(game.player.get("camera_motion_intensity")),1.0), "camera motion setting restores full subtle movement")
	var original_sfx := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	ui.call("_apply_setting","bus_SFX",50.0)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")),linear_to_db(0.5)), "audio slider controls the actual SFX bus")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),original_sfx)
	ui.call("_save_settings")
	ui.set("settings_path","res://.godot/hud_verification_settings.cfg")
	var original_music := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	ui.call("_apply_setting","bus_Music",40.0)
	ui.call("_save_settings")
	var persisted := ConfigFile.new()
	var loaded_settings := persisted.load("res://.godot/hud_verification_settings.cfg") == OK and is_equal_approx(float(persisted.get_value("gameplay","sensitivity",0.0)),original_sensitivity/0.0022) and is_equal_approx(float(persisted.get_value("gameplay","camera_motion",-1.0)),1.0) and is_equal_approx(float(persisted.get_value("audio","Music",-1.0)),40.0)
	_check(loaded_settings, "player and Music bus settings persist through ConfigFile and reload")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),original_music)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/hud_verification_settings.cfg"))
	ui.call("show_notification","Verification notification")
	_check(bool(ui.get("_notification").visible) and ui.get("_notification_label").text=="Verification notification", "temporary notification uses a dedicated HUD panel")
	ui.call("open_menu","OBJECTIVE")
	await _ui_preview("pause_menu")
	_check(get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and ui.get("_menu").visible, "Tab menu pauses gameplay and releases the mouse")
	_check(not ui.get("_gameplay_hud").visible, "pause menu hides gameplay HUD and debug text to keep menu content unobstructed")
	_check(ui.get("_menu_title").text=="GAME PAUSED" and ui.get("_menu_footer").get_child_count()==4, "cinematic pause menu retains Resume, Restart, Main Menu and Quit actions")
	_check(ui.get("selected_tab")=="OBJECTIVE", "pause menu opens on the live Objective tab by default")
	_check(not game.player.can_process() and not game.environment.can_process() and not game.monster.can_process() and ui.get("_menu").can_process(), "paused player, house and monster stop while pause menu remains interactive")
	for tab in ["CONTROLS","SETTINGS","AUDIO"]:
		ui.call("_select_tab",tab)
		_check(ui.get("selected_tab")==tab and ui.get_node_or_null("SharedGameUI/PauseMenu")!=null, "%s menu tab is selectable" % tab)
	var previous_viewport_size: Vector2i = get_viewport().size
	ui.call("_select_tab","CONTROLS")
	for viewport_size in [Vector2i(960,720),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_viewport().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		var panel_rect: Rect2 = ui.get("_menu_panel").get_global_rect()
		var tabs: HBoxContainer = ui.get("_menu_tabs")
		var scroll_rect: Rect2 = ui.get("_menu_scroll").get_global_rect()
		var footer_rect: Rect2 = ui.get("_menu_footer").get_global_rect()
		var within_viewport: bool = panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0 and panel_rect.end.x <= viewport_size.x and panel_rect.end.y <= viewport_size.y
		var tabs_fit: bool = tabs.get_child_count() == 4
		for i in range(tabs.get_child_count()):
			var tab_rect: Rect2 = (tabs.get_child(i) as Control).get_global_rect()
			tabs_fit = tabs_fit and tab_rect.position.x >= panel_rect.position.x and tab_rect.end.x <= panel_rect.end.x
			if i > 0:
				var previous_tab_rect: Rect2 = (tabs.get_child(i - 1) as Control).get_global_rect()
				tabs_fit = tabs_fit and previous_tab_rect.end.x <= tab_rect.position.x
		var footer_separate: bool = scroll_rect.end.y <= footer_rect.position.y and footer_rect.end.y <= panel_rect.end.y
		_check(within_viewport and tabs_fit and footer_separate, "pause menu panel, tabs and footer fit %dx%d viewport" % [viewport_size.x, viewport_size.y])
	get_viewport().size = previous_viewport_size
	await get_tree().process_frame
	var paused_charge := float(game.player.flashlight.get("battery_percent"))
	await get_tree().create_timer(0.15,true).timeout
	_check(is_equal_approx(paused_charge,float(game.player.flashlight.get("battery_percent"))), "flashlight charge does not drain while the tree is paused")
	var controls_shortcut := InputEventKey.new()
	controls_shortcut.keycode = KEY_H
	controls_shortcut.pressed = true
	ui.call("_select_tab", "OBJECTIVE")
	ui.call("_input",controls_shortcut)
	_check(ui.get("selected_tab")=="CONTROLS", "H selects Controls while the menu is open")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	ui.call("_input",escape)
	var menu_closed := await _until(func() -> bool: return not ui.get("_menu").visible, 0.5)
	_check(not get_tree().paused and menu_closed, "Escape fades the pause menu out and resumes gameplay")
	_check(ui.get("_gameplay_hud").visible, "resuming gameplay restores the normal HUD")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED, "closing the menu requests captured gameplay mouse")
	else:
		print("SKIP: headless display cannot validate the captured mouse cursor; inspect in a normal game window")
	ui.call("_save_settings")
	var start := Vector3(0.0, 0.1, 9.0)
	await _fixture(start,0.0)
	var wasd_move := await _measure_move(KEY_W)
	await _fixture(start,0.0)
	var arrow_move := await _measure_move(KEY_UP)
	_check(wasd_move.length()>0.15 and arrow_move.length()>0.15 and wasd_move.distance_to(arrow_move)<0.35, "W and Up Arrow produce equivalent first-person movement")
	await _fixture(start,0.0)
	var wasd_sprint := await _measure_move(KEY_W,true)
	await _fixture(start,0.0)
	var arrow_sprint := await _measure_move(KEY_UP,true)
	_check(wasd_sprint.length()>wasd_move.length() and arrow_sprint.length()>arrow_move.length() and wasd_sprint.distance_to(arrow_sprint)<0.45, "sprint works with equivalent WASD and arrow movement")
	var old_settings_path: String = str(ui.get("settings_path"))
	ui.set("settings_path","res://.godot/story_verification.cfg")
	ui.get("_settings").set_value("story","intro_seen",false)
	ui.call("show_intro_if_new")
	_check(bool(ui.get("intro_active")) and get_tree().paused and bool(ui.get("_intro_layer").visible), "fresh-game introduction pauses player, monster and world timers")
	for _page in range(2):
		var advance := InputEventKey.new()
		advance.keycode = KEY_ENTER
		advance.pressed = true
		ui.call("_input",advance)
	_check(int(ui.get("_intro_page"))==2 and bool(ui.get("intro_active")), "story introduction presents its setting, Familiar and escape-goal pages in order")
	ui.wake_up_requested.connect(func(): get_tree().paused = false)
	ui.call("_finish_intro")
	_check(not bool(ui.get("intro_active")) and not get_tree().paused, "continuing the story requests the wake-up sequence before gameplay resumes")
	ui.get("_settings").set_value("story","intro_seen",false)
	ui.call("show_intro_if_new")
	var skip_intro := InputEventKey.new()
	skip_intro.keycode = KEY_ESCAPE
	skip_intro.pressed = true
	ui.call("_input",skip_intro)
	_check(not bool(ui.get("intro_active")) and not get_tree().paused, "Escape skips story pages and enters the wake-up handoff")
	ui.set("settings_path",old_settings_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/story_verification.cfg"))
	await _verify_live_capture_qte()

func _measure_move(key: int, sprinting: bool = false) -> Vector3:
	var origin: Vector3 = game.player.global_position
	_key(key,true)
	if sprinting: _key(KEY_SHIFT,true)
	await _wait(0.25)
	_key(key,false)
	if sprinting: _key(KEY_SHIFT,false)
	return game.player.global_position - origin

func _shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://design/house/"+name+".png")

func _ui_preview(name: String) -> void:
	await get_tree().create_timer(0.35, true, false, true).timeout
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/ui_"+name+"_preview.png")

func run(root: Node) -> void:
	game = root
	Engine.time_scale = 2
	_freeze()
	_check(game.house_mode and game.environment.builder.asset_instances>600,"F5 builds furnished Kenney house with surrounding neighborhood")
	_check(game.navigation_is_ready,"multi-level navigation bakes successfully")
	var living_bounds: Rect2 = game.environment.builder.LIVING_ROOM_BOUNDS
	var old_living_area := 9.8 * 4.0
	var new_living_area := living_bounds.size.x * living_bounds.size.y
	var sofa_hide: Dictionary = game.environment.builder.hide_spots.filter(func(entry: Dictionary) -> bool: return str(entry.title) == "Hide behind sofa")[0]
	_check(is_equal_approx(new_living_area / old_living_area, 1.25) and living_bounds.position.y == 3.0 and living_bounds.end.y == 8.0, "living room expands 25 percent by moving the internal foyer partition only")
	_check(sofa_hide.hide_config.entry.x >= living_bounds.position.x and sofa_hide.hide_config.entry.x <= living_bounds.end.x and sofa_hide.hide_config.entry.z >= living_bounds.position.y and sofa_hide.hide_config.entry.z <= living_bounds.end.y, "existing sofa hiding entry remains inside the expanded living room")
	var living_route := NavigationServer3D.map_get_path(game.monster.agent.get_navigation_map(), Vector3(-7,0.05,4), Vector3(-5,0.05,8.7), true)
	_check(living_route.size() > 1, "expanded living room remains connected through its existing doorway opening")
	await _verify_batteries()
	await _verify_visual_handoff()
	await _verify_house_atmosphere()
	await _verify_dynamic_music()
	await _verify_hud_menu_and_input()
	await _verify_flashlight()
	await _verify_vhs_effect()
	var wing_route := NavigationServer3D.map_get_path(game.monster.agent.get_navigation_map(),Vector3(-2.4,0.05,-14.5),Vector3(2.4,0.05,-14.5),true)
	_check(wing_route.size()>2,"monster navigation connects both sides of the new rear wing")
	var nav_map: RID = game.monster.agent.get_navigation_map()
	var ground_rear_route := NavigationServer3D.map_get_path(nav_map,Vector3(-7,0.05,-19),Vector3(6,0.05,-19),true)
	var second_rear_route := NavigationServer3D.map_get_path(nav_map,Vector3(-7,3.65,-19),Vector3(6,3.65,-19),true)
	var basement_rear_route := NavigationServer3D.map_get_path(nav_map,Vector3(-7,-3.55,-19),Vector3(6,-3.55,-19),true)
	_check(ground_rear_route.size()>2,"ground-floor family room connects through the rear opening to breakfast and sunroom")
	_check(second_rear_route.size()>2,"combined upstairs guest and study wing stays traversable across the central opening")
	_check(basement_rear_route.size()>2,"basement archive and laundry connect through the rear service passage")
	await _shot("foyer")
	await _fixture(Vector3(5,0.05,-11.4))
	_key(KEY_W,true)
	await _wait(0.8)
	_key(KEY_W,false)
	_check(game.player.global_position.z< -12.0 and game.player.global_position.y<0.3,"player passes through the widened pantry-to-wing doorway")
	await _fixture(Vector3(4.5,0.05,10.8))
	_key(KEY_W,true)
	await _wait(3.8)
	_key(KEY_W,false)
	_check(game.player.global_position.y>3.4,"player physically walks main staircase to second floor")
	await _shot("second_floor")
	await _fixture(Vector3(4.5,3.65,2.4),PI)
	_key(KEY_W,true)
	await _wait(3.8)
	_key(KEY_W,false)
	_check(game.player.global_position.y<0.3 and game.player.global_position.z>9.5,"player physically walks down the main staircase from the second floor")
	await _fixture(Vector3(2.4,0.05,8.5))
	_key(KEY_D,true)
	await _wait(0.8)
	_key(KEY_D,false)
	_check(game.player.global_position.x<3.0 and game.player.global_position.y<0.3,"stair side collider prevents entering the flight from underneath")
	await _fixture(Vector3(-7,0.05,1.8))
	_key(KEY_W,true)
	await _wait(3.8)
	_key(KEY_W,false)
	_check(game.player.global_position.y< -3.3,"kitchen stairs physically descend into basement")
	await _fixture(Vector3(-7,-3.55,-7.0),PI)
	_key(KEY_W,true)
	await _wait(4.5)
	_key(KEY_W,false)
	_check(game.player.global_position.y> -0.2 and game.player.global_position.z>1.0,"player physically climbs kitchen stairs from basement to ground floor")
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
	_check(game.music_manager.cue_play_counts.escape_ending == 1 and game.music_manager._cue_player.stream == game.music_manager.escape_ending_track and game.music_manager._ending_locked, "real exterior landing triggers the escape ending cue once and locks gameplay music")
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
	_confirm_test_evidence(3)
	var qte_open := await _until(func() -> bool: return game.game_ui.get("qte_active"),8)
	_check(qte_open and not game.capture_started and game.environment.escape_progress!=game.environment.EscapeProgress.CAPTURED,"real house pursuit opens the QTE before any capture ending begins")
	if qte_open: game.game_ui.call("_process",5.1)
	var captured := await _until(func() -> bool: return game.capture_started,3)
	_check(captured and game.capture_camera.current and int(game.audio.events.get("capture_sting",0))==1,"failed house-pursuit QTE enters capture close-up and plays one jump-scare sting")
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
	game.environment.builder.atmosphere.call("stop_ambience")
	print("HOUSE CHECKS: ",checks," / failures: ",failures)
	get_tree().quit(0 if failures==0 else 1)

func _verify_visual_handoff() -> void:
	await _reset()
	_freeze()
	# Use an open, connected center-hall sightline in the actual generated house.
	await _fixture(Vector3(0, 0.05, -1.0))
	game.monster.reset_controller(Vector3(0, 0.05, 2.5))
	game.monster.look_at(game.player.global_position)
	game.monster.set_physics_process(false)
	game.familiar.set_physics_process(false)
	game.observation.set_test_suspicion(0.0)
	await _wait(0.1)
	var snapshot: MonsterObservation = game.read_monster_observation()
	var visible: bool = game.monster.can_see_player(snapshot)
	var registered: bool = game._register_visible_player(snapshot) if visible else false
	_check(visible and not registered and game.observation.suspicion_level == 0.0, "ordinary sight before evidence does not trigger threat handoff")
	game._simulation_test_mode = false
	game._on_interaction_feedback("door_open", game.player.global_position)
	game._update_player_perception(1.0)
	_check(game.observation.suspicion_level == 0.0, "normal-phase door noise and sight do not create aggression")
	game._simulation_test_mode = true
	game.observation.set_test_suspicion(100.0)
	game._physics_process(1.0 / 60.0)
	_check(game._routine_active and not game.familiar.is_monster_controlled and not game.monster.encounter_pending, "even high temporary alertness cannot skip the normal evidence phase")
	_confirm_test_evidence(1)
	game._physics_process(1.0 / 60.0)
	for _tick in 8:
		game.monster._physics_process(0.2)
	_check(not game._routine_active and game.familiar.is_monster_controlled and game.monster.disguise_state == "Doubtful" and game.monster.monster_state != MonsterController.State.PURSUING and not game.monster.encounter_pending, "first clue enables doubtful behavior without pursuit despite confirmed sight and high alertness")
	_confirm_test_evidence(2)
	_check(game.threat_progression_score() == 50.0, "second unique clue retains doubtful progression")
	_confirm_test_evidence(3)
	game.monster.reset_controller(Vector3(0, 0.05, 2.5))
	game.monster.look_at(game.player.global_position)
	game.observation.set_test_suspicion(0.0)
	game._physics_process(1.0 / 60.0)
	game.monster._physics_process(0.2)
	_check(not game.get("_routine_active") and game.familiar.is_monster_controlled and game.monster.monster_state == MonsterController.State.PURSUING and game.monster.target == game.player, "third clue allows visible-player pursuit even when temporary alertness decays")
	await _reset()
	_check(game.threat_progression_score() == 0.0 and game.monster.target == null and game.monster.disguise_state == "Ordinary", "restart restores normal recognition appearance and targeting")
	_freeze()
