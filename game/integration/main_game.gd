extends Node3D
## Scene-local integration. Each system remains the writer of its own state.
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
var shadow: MeshInstance3D
var capture_camera: Camera3D
var capture_started := false
@export var environment_scene: PackedScene = preload("res://game/environment/escape_environment.tscn")
var house_mode := false

func _ready() -> void:
	environment = environment_scene.instantiate()
	environment.interception_gate = self
	add_child(environment)
	player = environment._player
	player.collision_layer = 2
	player.collision_mask = 13
	house_mode = environment.has_method("climb_ladder")
	_configure_navigation()
	_build_actors()
	_connect_game()
	_build_hud()
	await get_tree().physics_frame
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation_is_ready = region.navigation_mesh.get_polygon_count() > 0 and monster.navigation_ready()
	assert(navigation_is_ready, "House navigation failed to bake")
	familiar.set_physics_process(true)
	familiar.force_next_station()
	_caption("Explore the house. 1 / 2 / 3 are temporary suspicion controls.")
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
		region.navigation_mesh.filter_baking_aabb = AABB(Vector3(-13,-4.2,-14),Vector3(26,18,30))
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
	var points: Array = environment.builder.room_points.values() if house_mode else [Vector3(-1, 0.05, 8), Vector3(2, 0.05, 8), Vector3(2, 0.05, 3), Vector3(-1, 0.05, 3)]
	for point in points:
		familiar.routine_stations.append(_marker(point))
	monster.add_child(familiar)
	familiar.set_physics_process(false)

func _connect_game() -> void:
	observation.suspicion_changed.connect(familiar.set_suspicion_level)
	familiar.cue_emitted.connect(_caption)
	monster.cue_requested.connect(_caption)
	monster.capture_requested.connect(_capture)
	monster.interception_ready.connect(_arrived)
	monster.hiding_place_checked.connect(_check_hide)
	environment.interaction_feedback.connect(audio.effect)
	environment.basement_reveal_requested.connect(func() -> void: door_link.enabled = true; shadow.visible = false)
	environment.escape_completed.connect(_stop_actors)
	environment.hiding_attempted.connect(func(_point: Vector3) -> void: _witnessed_hide = monster.can_see_player(read_monster_observation()))
	player.hiding_transition_finished.connect(_hide_finished)

func _marker(point: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.position = point
	add_child(marker)
	return marker

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(18, 680)
	caption.add_theme_font_size_override("font_size", 18)
	canvas.add_child(caption)
	debug_label = Label.new()
	debug_label.position = Vector2(18, 110)
	canvas.add_child(debug_label)
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

func _physics_process(_delta: float) -> void:
	if not navigation_is_ready:
		return
	var terminal: bool = environment.escape_progress in [environment.EscapeProgress.ESCAPED, environment.EscapeProgress.CAPTURED]
	if terminal:
		return
	var should_routine: bool = observation.suspicion_level < monster.tuning.stalk_threshold and environment.escape_progress == environment.EscapeProgress.FIND_KEY
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
	debug_label.text = "Temporary suspicion: %.0f | Familiar: %s | Mother: %s\n1 normal / 2 doubtful / 3 certain" % [observation.suspicion_level, familiar.current_action, "Household routine" if _routine_active else monster.state_name()]

func read_monster_observation() -> MonsterObservation:
	var snapshot := MonsterObservation.new()
	snapshot.suspicion_level = observation.suspicion_level
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
	if caption != null:
		caption.text = text

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
	if event is InputEventKey and event.pressed and not event.echo and not capture_started:
		match event.keycode:
			KEY_1: observation.set_test_suspicion(0)
			KEY_2: observation.set_test_suspicion(50)
			KEY_3: observation.set_test_suspicion(100)
