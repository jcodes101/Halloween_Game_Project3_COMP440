extends Node3D
## Scene-local integration. Each system remains the writer of its own state.
signal startup_overlay_ready
signal gameplay_started
var environment: Node3D
var player: CharacterBody3D
var monster: MonsterController
var familiar: FamiliarController
var visual_adapter: MotherVisualAdapter
var observation: Node
var audio: MonsterLabAudio
var region: NavigationRegion3D
var door_link: NavigationLink3D
var door_requested := false
var navigation_is_ready := false
var _witnessed_hide := false
var _routine_active := true
var caption: Label
var debug_label: Label
var battery_label: Control
var game_ui: CanvasLayer
@export var debug_enabled := false
@export_range(0.05, 0.5, 0.05) var perception_update_interval := 0.2
@export_group("Dynamic Horror Music")
@export var exploration_music_track: AudioStream
@export var investigation_music_track: AudioStream
@export var chase_music_track: AudioStream
@export var show_story_intro := true
@export var embedded_in_menu := false
var vhs_effect: Node
var music_manager: Node
var shadow: MeshInstance3D
var capture_camera: Camera3D
var capture_started := false
var _running_noise_timer := 0.0
var _perception_scan_timer := 0.0
var _simulation_test_mode := false
var _opening_sequence_active := false
var _door_scan_timer := 0.0
var _startup_overlay_emitted := false
@export var environment_scene: PackedScene = preload("res://game/environment/escape_environment.tscn")
var house_mode := false

func _exit_tree() -> void:
	if is_instance_valid(music_manager) and music_manager.has_method("cleanup"):
		music_manager.call("cleanup")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_simulation_test_mode = "--verify-game" in args or "--verify-house" in args or "--verify-monster" in args
	_opening_sequence_active = not _simulation_test_mode
	debug_enabled = debug_enabled or "--debug-gameplay" in args or "--verify-game" in args or "--verify-house" in args
	if OS.has_feature("web"):
		debug_enabled = false
	environment = environment_scene.instantiate()
	environment.interception_gate = self
	add_child(environment)
	player = environment._player
	player.collision_layer = 2
	player.collision_mask = 13
	house_mode = environment.has_method("climb_ladder")
	_opening_sequence_active = house_mode and not _simulation_test_mode
	_configure_navigation()
	_build_actors()
	_connect_game()
	_build_hud()
	player.set_qte_locked(_opening_sequence_active)
	await get_tree().physics_frame
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Let the NavigationServer synchronize the baked region and its links before
	# exposing the scene as ready to agents or gameplay systems.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var navigation_goal := Vector3(0,0.25,-1.3)
	if house_mode:
		navigation_goal = environment.builder.room_points["Reading Nook"]
	var navigation_probe := NavigationServer3D.map_get_path(monster.agent.get_navigation_map(),monster.global_position,navigation_goal,true)
	var navigation_sync_frames := 0
	while navigation_probe.is_empty() and navigation_sync_frames < 120:
		await get_tree().physics_frame
		navigation_sync_frames += 1
		navigation_probe = NavigationServer3D.map_get_path(monster.agent.get_navigation_map(),monster.global_position,navigation_goal,true)
	navigation_is_ready = region.navigation_mesh.get_polygon_count() > 0 and monster.navigation_ready() and not navigation_probe.is_empty()
	assert(navigation_is_ready, "House navigation failed to bake")
	if _simulation_test_mode:
		familiar.set_physics_process(true)
		familiar.force_next_station()
	if debug_enabled:
		_caption("Development debug: 1 / 2 / 3 change alertness. Clues control recognition.")
	if embedded_in_menu:
		game_ui.visible = true
		var vhs_layer := vhs_effect.get_node_or_null("VHSOverlayLayer")
		if vhs_layer is CanvasLayer:
			vhs_layer.visible = true
	if not _simulation_test_mode:
		game_ui.connect("wake_up_requested", _begin_wake_up)
		game_ui.connect("wake_up_finished", _finish_wake_up)
		game_ui.connect("restart_requested", _handle_restart_requested)
		game_ui.connect("main_menu_requested", _handle_main_menu_requested)
		if show_story_intro:
			if not bool(game_ui.call("show_intro_if_new", true)):
				_begin_wake_up()
		else:
			_begin_wake_up()
		startup_overlay_ready.emit()
		_startup_overlay_emitted = true
	if "--verify-game" in OS.get_cmdline_user_args() and not get_tree().root.has_node("GameVerification"):
		var suite := preload("res://tests/integration/verify_game.gd").new()
		suite.name = "GameVerification"
		get_tree().root.add_child(suite)
		await suite.run(self)
	if "--verify-house" in OS.get_cmdline_user_args() and not get_tree().root.has_node("HouseVerification"):
		var suite := preload("res://tests/house/verify_house.gd").new()
		suite.name = "HouseVerification"
		get_tree().root.add_child(suite)
		await suite.run(self)

func _configure_navigation() -> void:
	# A physical side passage lets her reach the closed basement from the house.
	if not house_mode:
		var partition := environment.get_node("LivingPartitionEast") as MeshInstance3D
		partition.position.x = 4.25
		(partition.mesh as BoxMesh).size.x = 4.5
		(partition.get_node("CollisionBody").get_child(0).shape as BoxShape3D).size.x = 4.5
		var mattress := environment.get_node("BedMattress") as MeshInstance3D
		var bed_body := StaticBody3D.new()
		var bed_shape := CollisionShape3D.new()
		var bed_box := BoxShape3D.new()
		bed_box.size = Vector3(3, 0.2, 2.2)
		bed_shape.shape = bed_box
		bed_body.add_child(bed_shape)
		mattress.add_child(bed_body)
		var slab: MeshInstance3D = environment._basement_door_mesh.get_meta("slab")
		(slab.get_node("CollisionBody") as StaticBody3D).collision_layer = 8
	region = NavigationRegion3D.new()
	region.navigation_mesh = NavigationMesh.new()
	region.navigation_mesh.agent_height = 1.75
	region.navigation_mesh.agent_radius = 0.5
	if house_mode:
		# Resolve the actual narrow door openings with the mother's capsule size.
		NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map,0.125)
		NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map,0.125)
		region.navigation_mesh.cell_size = 0.125
		region.navigation_mesh.cell_height = 0.125
		region.navigation_mesh.agent_radius = 0.375
		# Include the connected rear wing on every navigable house level.
		region.navigation_mesh.filter_baking_aabb = AABB(Vector3(-13,-4.2,-24),Vector3(26,18,42))
	region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh.geometry_collision_mask = 9
	region.navigation_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	region.navigation_mesh.geometry_source_group_name = &"house_navigation"
	environment.add_to_group("house_navigation")
	add_child(region)
	door_link = NavigationLink3D.new()
	door_link.start_position = Vector3(0,-3.35,10.9) if house_mode else Vector3(0, 0.25, 1)
	door_link.end_position = Vector3(0,-3.35,13.0) if house_mode else Vector3(0, 0.25, -1.3)
	door_link.enabled = false
	add_child(door_link)
	if house_mode:
		for route in [[Vector3(-7,0.25,1.8),Vector3(-7,-3.35,-6.8)],[Vector3(4.5,0.25,10.7),Vector3(4.5,3.85,2.4)]]:
			var stair_link := NavigationLink3D.new()
			stair_link.start_position = route[0]
			stair_link.end_position = route[1]
			add_child(stair_link)
		for id in environment.builder.doors:
			if id in ["false_exit","front_door"]: continue
			var info: Dictionary = environment.builder.doors[id]
			var link := NavigationLink3D.new()
			var direction := Vector3(0,0,1.3).rotated(Vector3.UP,info.yaw)
			link.start_position = info.position-Vector3.UP*0.75-direction
			link.end_position = info.position-Vector3.UP*0.75+direction
			link.enabled = info.open
			add_child(link)
			info.link = link

func _build_actors() -> void:
	observation = preload("res://game/integration/test_observation.gd").new()
	add_child(observation)
	audio = MonsterLabAudio.new()
	add_child(audio)
	monster = preload("res://systems/monster/Monster.tscn").instantiate()
	monster.position = Vector3(2,0.05,9) if house_mode else Vector3(2, 0.05, 3)
	monster.observation_provider = self
	monster.player_actor = player
	monster.interception_anchor = _marker(Vector3(0,-3.55,13.2) if house_mode else Vector3(0, 0.05, -1.6))
	if house_mode: monster.interception_anchor.rotation.y = PI
	monster.retreat_anchor = _marker(monster.position)
	add_child(monster)
	if house_mode:
		monster.collision_mask |= 4 # Stair side barriers are on the actor-only layer.
		monster.floor_block_on_wall = true
		monster.floor_snap_length = 0.35
		monster.safe_margin = 0.001
	monster.set_physics_process(false)
	familiar = preload("res://game/integration/routine_bridge.gd").new()
	familiar.actor = monster
	familiar.collision_layer = 0
	familiar.collision_mask = 0
	familiar.player_target = player
	visual_adapter = preload("res://game/integration/shared_mother_adapter.gd").new()
	visual_adapter.actor = monster
	familiar.visual_adapter = visual_adapter
	familiar.add_child(visual_adapter)
	if house_mode:
		for station_name in environment.builder.room_points:
			var station := _marker(environment.builder.room_points[station_name])
			station.name = str(station_name)
			familiar.routine_stations.append(station)
	else:
		for point in [Vector3(-1, 0.05, 8), Vector3(2, 0.05, 8), Vector3(2, 0.05, 3), Vector3(-1, 0.05, 3)]:
			familiar.routine_stations.append(_marker(point))
	monster.add_child(familiar)
	familiar.set_physics_process(false)

func _connect_game() -> void:
	observation.suspicion_changed.connect(familiar.set_suspicion_level)
	familiar.cue_emitted.connect(_caption)
	monster.cue_requested.connect(_caption)
	if house_mode:
		for point in environment.builder.room_points.values():
			monster.search_locations.append(point)
		for spot in environment.builder.hide_spots:
			monster.search_locations.append(spot.hide_config.entry)
		for info in environment.builder.doors.values():
			monster.search_locations.append(info.position)

	monster.capture_requested.connect(_capture)
	monster.close_encounter_requested.connect(_start_survival_qte)
	monster.interception_ready.connect(_arrived)
	monster.hiding_place_checked.connect(_check_hide)
	environment.interaction_feedback.connect(_on_interaction_feedback)
	environment.basement_reveal_requested.connect(func() -> void: door_link.enabled = true; shadow.visible = false)
	environment.escape_completed.connect(_stop_actors)
	environment.escape_completed.connect(func() -> void: music_manager.play_ending_cue(true))
	environment.player_captured.connect(func() -> void: music_manager.play_ending_cue(false))
	environment.hiding_attempted.connect(func(_point: Vector3) -> void: _witnessed_hide = monster.can_see_player(read_monster_observation()))
	player.hiding_transition_finished.connect(_hide_finished)

func _marker(point: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.position = point
	add_child(marker)
	return marker

func _build_hud() -> void:
	vhs_effect = preload("res://game/integration/vhs_proximity_effect.gd").new()
	vhs_effect.set("player", player)
	vhs_effect.set("monster", monster)
	vhs_effect.name = "VHSProximityEffect"
	add_child(vhs_effect)
	game_ui = preload("res://game/ui/game_ui.gd").new()
	game_ui.name = "GameUI"
	game_ui.set("debug_enabled", debug_enabled)
	add_child(game_ui)
	game_ui.call("setup", self)
	game_ui.set("qte_sequence_length", monster.tuning.qte_sequence_length)
	game_ui.set("qte_key_pool", monster.tuning.qte_key_pool.duplicate())
	game_ui.set("qte_random_seed", monster.tuning.qte_random_seed)
	game_ui.call("_initialize_qte_rng")
	game_ui.connect("survival_qte_finished", _on_survival_qte_finished)
	music_manager = preload("res://game/integration/dynamic_horror_music.gd").new()
	music_manager.name = "DynamicHorrorMusic"
	add_child(music_manager)
	music_manager.call("setup", monster, exploration_music_track, investigation_music_track, chase_music_track, not embedded_in_menu)
	game_ui.connect("survival_qte_started", music_manager.play_qte_sting)
	if embedded_in_menu:
		game_ui.visible = false
		var vhs_layer := vhs_effect.get_node_or_null("VHSOverlayLayer")
		if vhs_layer is CanvasLayer:
			vhs_layer.visible = false
	battery_label = game_ui.get_node_or_null("SharedGameUI")
	debug_label = game_ui.get("debug_label")
	shadow = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.01, 0.5)
	shadow.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.03, 0.03, 0.03)
	shadow.material_override = material
	shadow.position = Vector3(0,-3.59,11.4) if house_mode else Vector3(0, 0.01, 0.35)
	shadow.visible = false
	add_child(shadow)
	capture_camera = Camera3D.new()
	capture_camera.fov = 55
	capture_camera.near = 0.04
	add_child(capture_camera)

func _on_battery_level_changed(_percent: float) -> void:
	if game_ui != null: game_ui.call("_refresh_battery")

func _refresh_battery_hud() -> void:
	if game_ui != null: game_ui.call("_refresh_battery")

func _physics_process(delta: float) -> void:
	if not navigation_is_ready or _opening_sequence_active:
		return
	if music_manager != null:
		var threat_states := [MonsterController.State.SEARCHING, MonsterController.State.LOST_TARGET, MonsterController.State.INTERCEPTING, MonsterController.State.PURSUING, MonsterController.State.RETREATING, MonsterController.State.RECOVERING, MonsterController.State.STUNNED]
		var threat_nearby: bool = monster.monster_state in threat_states and monster.global_position.distance_to(player.global_position) <= music_manager.hiding_threat_distance
		music_manager.set_hiding_context(environment.is_hidden, threat_nearby)
	var terminal: bool = environment.escape_progress in [environment.EscapeProgress.ESCAPED, environment.EscapeProgress.CAPTURED]
	if terminal:
		return
	_update_player_perception(delta)
	_update_monster_doors(delta)
	var threat_is_owned := monster.monster_state not in [MonsterController.State.DISGUISED, MonsterController.State.LOST_TARGET] or (monster.monster_state == MonsterController.State.LOST_TARGET and monster.has_last_seen)
	var progression := threat_progression_score()
	var routine_score: float = observation.suspicion_level if progression < 0.0 else progression
	if progression >= 0.0:
		# Sight/noise cannot end the normal phase. A reveal or active encounter
		# still owns the shared body until its recovery has finished.
		threat_is_owned = monster.basement_reveal_done or monster.encounter_pending or monster.monster_state in [MonsterController.State.STUNNED, MonsterController.State.RETREATING, MonsterController.State.RECOVERING, MonsterController.State.CAPTURED]
	var should_routine: bool = routine_score < monster.tuning.stalk_threshold and environment.escape_progress == environment.EscapeProgress.FIND_KEY and not threat_is_owned and monster.encounter_cooldown <= 0.0
	if should_routine != _routine_active:
		_routine_active = should_routine
		if should_routine:
			monster.target = null
			monster.has_last_seen = false
			monster._change_state(MonsterController.State.DISGUISED)
			monster._set_appearance("Ordinary")
			visual_adapter.bind_actor_visual()
			familiar.reclaim_from_monster()
			familiar.force_next_station()
		else:
			familiar.hand_off_to_monster()
		monster.set_physics_process(not should_routine)
		familiar.set_physics_process(should_routine)
	audio.footstep(player, "player_step", not environment.is_hidden and not player.is_transitioning())
	audio.footstep(monster, "mother_step", true)
	if debug_enabled and debug_label != null:
		debug_label.text = "Suspicion %.0f | Familiar: %s | AI: %s\nVisible: %s | confidence %.2f | Last known: %s\nNav target: %s | Capture: %s | %s\n1 normal / 2 doubtful / 3 certain" % [observation.suspicion_level, familiar.current_action, "Household routine" if _routine_active else monster.state_name(), str(monster.sees_player), monster._visual_contact_seconds, str(monster.last_seen_position if monster.has_last_seen else Vector3.ZERO), str(monster.destination), str(monster.encounter_cooldown <= 0.0 and monster.monster_state not in [MonsterController.State.STUNNED, MonsterController.State.RETREATING, MonsterController.State.RECOVERING]), monster.pursuit_debug_reason]

func _update_monster_doors(delta: float) -> void:
	if not house_mode or monster.monster_state not in [MonsterController.State.PURSUING, MonsterController.State.SEARCHING, MonsterController.State.LOST_TARGET, MonsterController.State.INTERCEPTING, MonsterController.State.REVEALING, MonsterController.State.RETREATING]:
		return
	_door_scan_timer -= delta
	if _door_scan_timer > 0.0:
		return
	_door_scan_timer = 0.2
	for id in environment.builder.doors:
		if id in ["front_door", "false_exit"]:
			continue
		var info: Dictionary = environment.builder.doors[id]
		if not bool(info.open) and Vector2(monster.global_position.x - info.position.x, monster.global_position.z - info.position.z).length() <= 1.7:
			if environment.open_door_for_monster(id):
				audio.effect("door_open", info.position)
			return

func _begin_wake_up() -> void:
	if not _opening_sequence_active:
		return
	if not house_mode:
		_opening_sequence_active = false
		player.set_qte_locked(false)
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		familiar.set_physics_process(true)
		familiar.force_next_station()
		if music_manager != null:
			music_manager.call("set_gameplay_enabled", true)
		return
	get_tree().paused = true
	player.set_qte_locked(true)
	player.call("set_opening_camera_height", 0.48)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.call("set_opening_camera_pose", Vector3(0.0, 0.48, 0.04), Vector3(deg_to_rad(-4.0), deg_to_rad(3.0), 0.0))
	game_ui.call("begin_wake_up_sequence", player)

func _finish_wake_up() -> void:
	if not _opening_sequence_active:
		return
	_opening_sequence_active = false
	player.call("reset_opening_camera_pose")
	player.set_qte_locked(false)
	player.velocity = Vector3.ZERO
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	familiar.set_physics_process(true)
	familiar.force_next_station()
	if music_manager != null:
		music_manager.call("set_gameplay_enabled", true)
	gameplay_started.emit()

func _handle_restart_requested() -> void:
	if embedded_in_menu and get_parent().has_method("restart_embedded_game"):
		get_parent().call("restart_embedded_game")
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()

func _handle_main_menu_requested() -> void:
	if embedded_in_menu and get_parent().has_method("return_to_menu"):
		get_parent().call("return_to_menu")
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://game/ui/main_menu.tscn")

func _update_player_perception(delta: float) -> void:
	if _simulation_test_mode or player.is_transitioning() or capture_started:
		return
	if threat_progression_score() == 0.0 and not monster.basement_reveal_done:
		_running_noise_timer = 0.0
		_perception_scan_timer = 0.0
		return
	var is_hidden: bool = environment.is_hidden
	if not is_hidden and player.is_moving():
		_running_noise_timer += delta
		if _running_noise_timer >= 0.8:
			_running_noise_timer = 0.0
			var sprinting := Input.is_action_pressed("sprint")
			var alert := monster.hear_sound(player.global_position, 42.0 if sprinting else 28.0)
			if alert > 0.0:
				observation.set_test_suspicion(maxf(observation.suspicion_level, minf(62.0, 30.0 + alert)))
	else:
		_running_noise_timer = 0.0
	_perception_scan_timer += delta
	if _perception_scan_timer < perception_update_interval:
		return
	var sense_delta := _perception_scan_timer
	_perception_scan_timer = 0.0
	var snapshot := read_monster_observation()
	if _register_visible_player(snapshot):
		var gain := 2.5
		if player.is_moving(): gain += 4.0
		var flashlight: Node = player.flashlight
		if flashlight != null and bool(flashlight.get("flashlight_is_on")):
			gain += 9.0 if _flashlight_aimed_at_monster() else 1.0
		observation.set_test_suspicion(observation.suspicion_level + gain * sense_delta)
	elif observation.suspicion_level > 0.0:
		var decay_rate := 8.0 if environment.is_hidden or monster.monster_state == MonsterController.State.LOST_TARGET else 2.2
		observation.set_test_suspicion(maxf(0.0, observation.suspicion_level - decay_rate * sense_delta))

func _register_visible_player(snapshot: MonsterObservation) -> bool:
	if environment.is_hidden or not monster.can_see_player(snapshot):
		return false
	if threat_progression_score() == 0.0 and not monster.basement_reveal_done:
		return false
	# Once progression permits threat behavior, sight confirms the player
	# without requiring noise. It never awards evidence or advances recognition.
	observation.set_test_suspicion(maxf(observation.suspicion_level, monster.tuning.stalk_threshold + 0.01))
	return true

func _flashlight_aimed_at_monster() -> bool:
	var camera := player.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		return false
	var target := monster.global_position + Vector3.UP * 0.9 - camera.global_position
	return target.length() > 0.01 and (-camera.global_basis.z).dot(target.normalized()) >= cos(deg_to_rad(30.0))

func _on_interaction_feedback(kind: String, at: Vector3) -> void:
	audio.effect(kind, at)
	if kind not in ["door_open", "door_close", "locked_door", "item_pickup"]:
		return
	if threat_progression_score() == 0.0 and not monster.basement_reveal_done:
		return
	var loudness := 48.0 if kind != "item_pickup" else 36.0
	var alert := monster.hear_sound(at, loudness)
	if alert > 0.0 and not _simulation_test_mode:
		observation.set_test_suspicion(maxf(observation.suspicion_level, minf(62.0, 30.0 + alert)))

func _start_survival_qte(_actor: Node3D, duration: float) -> void:
	if capture_started or environment.escape_progress in [environment.EscapeProgress.ESCAPED, environment.EscapeProgress.CAPTURED]:
		monster.resolve_close_encounter(false)
		return
	player.set_qte_locked(true)
	game_ui.call("start_survival_qte", duration)

func _on_survival_qte_finished(escaped: bool) -> void:
	if escaped:
		player.call("play_qte_shove_reaction")
	player.set_qte_locked(false)
	monster.resolve_close_encounter(escaped)

func threat_progression_score() -> float:
	# Legacy lab scenes deliberately retain their independent alertness controls.
	return -1.0

func read_monster_observation() -> MonsterObservation:
	var snapshot := MonsterObservation.new()
	snapshot.suspicion_level = observation.suspicion_level
	snapshot.recognition_score = threat_progression_score()
	snapshot.player_location = player.global_position
	snapshot.is_hidden = environment.is_hidden
	snapshot.player_is_still = environment.is_player_motionless()
	snapshot.hiding_check_position = environment.active_hide_check_position
	snapshot.door_state = MonsterObservation.DoorState.OPEN if environment.door_state["basement_door"] == "open" else MonsterObservation.DoorState.CLOSED
	snapshot.escape_progress = MonsterObservation.EscapePhase.EXPLORING
	if environment.escape_progress in [environment.EscapeProgress.BASEMENT_READY, environment.EscapeProgress.BASEMENT_ENTERED]:
		snapshot.escape_progress = MonsterObservation.EscapePhase.BASEMENT_READY
	elif environment.escape_progress in [environment.EscapeProgress.ESCAPED, environment.EscapeProgress.CAPTURED]:
		snapshot.escape_progress = MonsterObservation.EscapePhase.ESCAPED
	return snapshot

func request_door_open() -> bool:
	door_requested = true
	return monster.arrived_for_interception

func _arrived() -> void:
	shadow.visible = true
	if door_requested:
		environment.open_basement_route()

func _hide_finished(entered: bool, succeeded: bool) -> void:
	if entered and succeeded and _witnessed_hide:
		monster.knows_hiding_place = true
		monster._known_hide_position = environment.active_hide_check_position
		monster._was_hidden = true
		monster._hiding_checked = false
	_witnessed_hide = false

func _check_hide(_point: Vector3) -> void:
	if environment.is_hidden:
		environment._escape_from_hide()
		_caption("She saw you enter. [Footsteps stop at your hiding place]")

func _caption(text: String) -> void:
	if game_ui != null:
		game_ui.call("show_caption", text)

func _stop_actors() -> void:
	monster.set_physics_process(false)
	monster.velocity = Vector3.ZERO
	monster.target = null
	if not familiar.is_monster_controlled:
		familiar.hand_off_to_monster()
	familiar.set_physics_process(false)
	monster._set_visual_motion(false)
	if not capture_started:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _capture(_actor: Node3D) -> void:
	if capture_started:
		return
	capture_started = true
	_stop_actors()
	player.cancel_hiding_transition()
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var forward := -monster.global_basis.z
	capture_camera.global_position = monster.global_position + forward * 0.6 + Vector3.UP * 1.05
	capture_camera.look_at(monster.global_position + forward * 0.17 + Vector3.UP * 1.46)
	capture_camera.current = true
	audio.effect("capture_sting", capture_camera.global_position)
	_caption("She was never your mother.")
	await get_tree().create_timer(1.0).timeout
	environment.mark_player_captured()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_key_input(event: InputEvent) -> void:
	if debug_enabled and event is InputEventKey and event.pressed and not event.echo and not capture_started:
		match event.keycode:
			KEY_1: observation.set_test_suspicion(0)
			KEY_2: observation.set_test_suspicion(50)
			KEY_3: observation.set_test_suspicion(100)
