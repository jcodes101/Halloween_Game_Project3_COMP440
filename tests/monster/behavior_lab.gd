class_name MonsterBehaviorLab
extends Node3D
## Self-contained test adapter. Owns simulated Observation/Environment inputs.
## This is a behavior lab, not the partner's house or final escape system.
const PLAYER_SPAWN := Vector3(0, 0.05, 5)
const MONSTER_SPAWN := Vector3(5, 0.05, 2)
const CLOSET_INSIDE := Vector3(-7, 0.05, -0.3)
const CLOSET_CHECK := Vector3(-7, 0.05, 1.8)
const LATCH_POSITION := Vector3(4, 0.75, 0)
const EXIT_POSITION := Vector3(-7, 0.75, 6)

var suspicion_level := 0.0
var escape_progress: MonsterObservation.EscapePhase = MonsterObservation.EscapePhase.EXPLORING
var door_state: MonsterObservation.DoorState = MonsterObservation.DoorState.CLOSED
var is_hidden := false
var hiding_check_position := CLOSET_CHECK
var outcome := ""
var door_requested := false
var navigation_is_ready := false
var checked_closet_count := 0
var reveal_count := 0
var capture_count := 0
var cue := "Explore, then press 2 to test stalking or 3 to test pursuit."
var player: MonsterTestPlayer
var monster: MonsterController
var region: NavigationRegion3D
var basement_door: StaticBody3D
var closet_door: StaticBody3D
var basement_link: NavigationLink3D
var closet_link: NavigationLink3D
var door_shadow: MeshInstance3D
var interception_marker: Marker3D
var retreat_marker: Marker3D
var scare_camera: Camera3D
var state_label: Label
var prompt_label: Label
var cue_label: Label
var end_panel: PanelContainer
var end_label: Label
var _capture_elapsed := 0.0

func _ready() -> void:
	_install_test_controls()
	_build_world()
	_build_actors()
	_build_interface()
	# Let newly created collider shapes reach the physics server before parsing.
	await get_tree().physics_frame
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation_is_ready = region.navigation_mesh.get_polygon_count() > 0 and monster.navigation_ready()
	if not navigation_is_ready:
		push_error("Monster lab navigation did not bake.")
		get_tree().quit(1)
		return
	_set_door_open(closet_door, closet_link, true)
	if "--verify-monster" in OS.get_cmdline_user_args():
		var suite := preload("res://tests/monster/verify_monster.gd").new()
		add_child(suite)
		await suite.run(self)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _install_test_controls() -> void:
	var bindings := {
		"monster_test_forward": KEY_W, "monster_test_back": KEY_S,
		"monster_test_left": KEY_A, "monster_test_right": KEY_D,
		"monster_test_sprint": KEY_SHIFT, "monster_test_interact": KEY_E,
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = bindings[action]
			InputMap.action_add_event(action, key)

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("252a2c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d7c9a8")
	environment.environment.ambient_light_energy = 0.55
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 0.9
	light.shadow_enabled = true
	add_child(light)
	region = NavigationRegion3D.new()
	region.name = "LabNavigation"
	region.navigation_mesh = NavigationMesh.new()
	region.navigation_mesh.agent_radius = 0.4
	region.navigation_mesh.agent_height = 1.8
	region.navigation_mesh.agent_max_climb = 0.25
	region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	region.navigation_mesh.geometry_collision_mask = 9
	add_child(region)
	_box("Floor", Vector3(0, -0.15, 0), Vector3(20, 0.3, 18), Color("735744"))
	_box("WestWall", Vector3(-10, 1.35, 0), Vector3(0.3, 2.7, 18), Color("d7c9a8"))
	_box("EastWall", Vector3(10, 1.35, 0), Vector3(0.3, 2.7, 18), Color("d7c9a8"))
	_box("BackWall", Vector3(0, 1.35, -9), Vector3(20, 2.7, 0.3), Color("6e7b65"))
	_box("FrontWall", Vector3(0, 1.35, 9), Vector3(20, 2.7, 0.3), Color("d7c9a8"))
	# Closed basement has an alternate access loop for real pre-positioning.
	_box("BasementPartitionLeft", Vector3(-5.5, 1.35, -3), Vector3(9, 2.7, 0.3), Color("6e7b65"))
	_box("BasementPartitionRight", Vector3(3.5, 1.35, -3), Vector3(5, 2.7, 0.3), Color("6e7b65"))
	_box("SightBlockingPartition", Vector3(-2, 1.35, 0), Vector3(2, 2.7, 3), Color("735744"))
	_box("ClosetLeft", Vector3(-8.2, 1.25, -0.2), Vector3(0.2, 2.5, 2.4), Color("735744"))
	_box("ClosetRight", Vector3(-5.8, 1.25, -0.2), Vector3(0.2, 2.5, 2.4), Color("735744"))
	_box("ClosetBack", Vector3(-7, 1.25, -1.4), Vector3(2.6, 2.5, 0.2), Color("735744"))
	basement_door = _box("BasementDoor", Vector3(0, 1.2, -3), Vector3(2, 2.4, 0.2), Color("252a2c"), 8)
	closet_door = _box("ClosetDoor", Vector3(-7, 1.2, 0.9), Vector3(2.2, 2.4, 0.2), Color("735744"), 8)
	basement_link = _link(Vector3(0, 0.25, -2), Vector3(0, 0.25, -4))
	closet_link = _link(Vector3(-7, 0.25, 1.9), Vector3(-7, 0.25, -0.3))
	_box("RouteLatch", LATCH_POSITION, Vector3(0.7, 1.5, 0.5), Color("6e7b65"))
	_box("SafeTestExit", EXIT_POSITION, Vector3(0.8, 1.5, 0.5), Color("6e7b65"))
	_world_label("BASEMENT TEST DOOR", Vector3(0, 2.6, -2.8))
	_world_label("HIDING CLOSET", Vector3(-7, 2.65, 1.0))
	_world_label("PREPARE BASEMENT ROUTE\nE to activate", LATCH_POSITION + Vector3.UP * 1.15)
	_world_label("SAFE TEST EXIT\nE to finish", EXIT_POSITION + Vector3.UP * 1.15)
	_world_label("ACCESS LOOP", Vector3(8, 2.4, -3))
	interception_marker = Marker3D.new()
	interception_marker.position = Vector3(0, 0.05, -4.2)
	add_child(interception_marker)
	retreat_marker = Marker3D.new()
	retreat_marker.position = MONSTER_SPAWN
	add_child(retreat_marker)
	door_shadow = MeshInstance3D.new()
	var shadow_mesh := BoxMesh.new()
	shadow_mesh.size = Vector3(0.85, 0.01, 0.6)
	door_shadow.mesh = shadow_mesh
	door_shadow.material_override = _material(Color("111313"))
	door_shadow.position = Vector3(0, 0.01, -2.55)
	door_shadow.visible = false
	add_child(door_shadow)

func _box(label: String, position_value: Vector3, size: Vector3, color: Color, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position_value
	body.collision_layer = layer
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(color)
	body.add_child(instance)
	region.add_child(body)
	return body

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _link(start: Vector3, finish: Vector3) -> NavigationLink3D:
	var link := NavigationLink3D.new()
	link.start_position = start
	link.end_position = finish
	link.bidirectional = true
	link.enabled = false
	add_child(link)
	return link

func _world_label(text: String, position_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.009
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _build_actors() -> void:
	player = MonsterTestPlayer.new()
	player.name = "FirstPersonPlayer"
	player.position = PLAYER_SPAWN
	add_child(player)
	player.interact_requested.connect(_interact)
	monster = preload("res://systems/monster/Monster.tscn").instantiate() as MonsterController
	monster.position = MONSTER_SPAWN
	monster.tuning = monster.tuning.duplicate() as MonsterTuning
	monster.observation_provider = self
	monster.player_actor = player
	monster.interception_anchor = interception_marker
	monster.retreat_anchor = retreat_marker
	add_child(monster)
	monster.look_at(Vector3(player.global_position.x, monster.global_position.y, player.global_position.z))
	monster.capture_requested.connect(_on_capture)
	monster.interception_ready.connect(_on_interception_ready)
	monster.reveal_started.connect(_on_reveal)
	monster.hiding_place_checked.connect(_on_hiding_checked)
	monster.cue_requested.connect(func(text: String) -> void: cue = text)
	scare_camera = Camera3D.new()
	scare_camera.fov = 55
	scare_camera.near = 0.04
	add_child(scare_camera)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var title := Label.new()
	title.text = "MONSTER BEHAVIOR LAB — isolated prototype"
	stack.add_child(title)
	var instructions := Label.new()
	instructions.text = "WASD move · Mouse look · Shift sprint · E interact\n1 unaware · 2 doubtful · 3 certain · R restart · Esc release mouse"
	stack.add_child(instructions)
	state_label = Label.new()
	stack.add_child(state_label)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(473, 346)
	layer.add_child(crosshair)
	prompt_label = Label.new()
	prompt_label.position = Vector2(20, 570)
	layer.add_child(prompt_label)
	cue_label = Label.new()
	cue_label.position = Vector2(20, 620)
	label_wrap(cue_label, 880)
	layer.add_child(cue_label)
	end_panel = PanelContainer.new()
	end_panel.position = Vector2(190, 250)
	end_panel.custom_minimum_size = Vector2(580, 150)
	end_panel.visible = false
	layer.add_child(end_panel)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_panel.add_child(end_label)

func label_wrap(label: Label, width: float) -> void:
	label.custom_minimum_size.x = width
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func read_monster_observation() -> MonsterObservation:
	var snapshot := MonsterObservation.new()
	snapshot.suspicion_level = suspicion_level
	snapshot.player_location = player.global_position
	snapshot.is_hidden = is_hidden
	snapshot.player_is_still = player.is_still()
	snapshot.hiding_check_position = hiding_check_position
	snapshot.door_state = door_state
	snapshot.escape_progress = escape_progress
	return snapshot

func _process(delta: float) -> void:
	if player == null or state_label == null:
		return
	state_label.text = "Mother: %s | Suspicion: %.0f | Hidden: %s | Still: %s | Concealed: %.1f / 3 s" % [monster.state_name(), suspicion_level, is_hidden, player.is_still(), monster.hidden_still_time]
	prompt_label.text = _interaction_prompt() if outcome.is_empty() else ""
	cue_label.text = cue
	if outcome == "captured" and not end_panel.visible:
		_capture_elapsed += delta
		if _capture_elapsed >= 1.0:
			_show_end("CAPTURED\nThe disguise is gone.\nPress R to restart the test.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: suspicion_level = 0
			KEY_2: suspicion_level = 50
			KEY_3: suspicion_level = 100
			KEY_R: reset_lab()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and outcome.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _facing(point: Vector3) -> bool:
	var difference := point - player.camera.global_position
	return difference.length() < 0.01 or (-player.camera.global_basis.z).dot(difference.normalized()) > 0.55

func _near(point: Vector3) -> bool:
	return Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length() <= 2.0

func _interaction_prompt() -> String:
	if is_hidden:
		return "E — leave closet. Movement keys interrupt stillness; looking does not."
	if _near(CLOSET_CHECK) and _facing(Vector3(-7, 1.2, 0.9)):
		return "E — hide in closet. Get out of her sight first."
	if _near(LATCH_POSITION) and _facing(LATCH_POSITION):
		return "E — prepare basement route (test input)."
	if _near(Vector3(0, 0, -3)) and _facing(Vector3(0, 1.2, -3)):
		return "E — open basement door." if escape_progress > 0 else "Basement locked: activate the route latch first."
	if _near(EXIT_POSITION) and _facing(EXIT_POSITION):
		return "E — reach the safe TEST exit (not the game's final exit)."
	return "Use the walls to break sight, then hide and stay still."

func _interact() -> void:
	if not outcome.is_empty():
		return
	if is_hidden:
		leave_closet()
	elif _near(CLOSET_CHECK) and _facing(Vector3(-7, 1.2, 0.9)):
		enter_closet()
	elif _near(LATCH_POSITION) and _facing(LATCH_POSITION):
		prepare_basement_route()
	elif _near(Vector3(0, 0, -3)) and _facing(Vector3(0, 1.2, -3)):
		request_basement_door()
	elif _near(EXIT_POSITION) and _facing(EXIT_POSITION):
		finish_test_escape()

func prepare_basement_route() -> void:
	escape_progress = MonsterObservation.EscapePhase.BASEMENT_READY
	cue = "The basement route is ready. [Footsteps move toward the door]"

func request_basement_door() -> void:
	if escape_progress == MonsterObservation.EscapePhase.EXPLORING:
		cue = "The test latch is still locked. Activate the route pedestal first."
		return
	door_requested = true
	if monster.arrived_for_interception:
		open_basement_door()
	else:
		cue = "The latch is shifting. [Footsteps approaching beyond the door]"

func open_basement_door() -> void:
	door_state = MonsterObservation.DoorState.OPEN
	_set_door_open(basement_door, basement_link, true)
	door_shadow.visible = false

func _on_interception_ready() -> void:
	door_shadow.visible = true
	if door_requested:
		open_basement_door()

func _on_reveal() -> void:
	reveal_count += 1
	cue = "She is motionless, smiling. Move now — the nearby closet remains available."

func enter_closet() -> void:
	is_hidden = true
	hiding_check_position = CLOSET_CHECK
	player.hide_locked = true
	player.global_position = CLOSET_INSIDE
	player.velocity = Vector3.ZERO
	_set_door_open(closet_door, closet_link, false)
	cue = "[Closet shuts] Stay still. If she saw you enter, she still knows where you are."

func leave_closet() -> void:
	is_hidden = false
	player.hide_locked = false
	_set_door_open(closet_door, closet_link, true)
	player.global_position = CLOSET_CHECK
	player.velocity = Vector3.ZERO

func _on_hiding_checked(point: Vector3) -> void:
	if is_hidden and point.distance_to(CLOSET_CHECK) < 0.5:
		checked_closet_count += 1
		_set_door_open(closet_door, closet_link, true)
		is_hidden = false
		player.hide_locked = false
		cue = "[Closet opens] She saw you enter. Run!"

func _set_door_open(door: StaticBody3D, link: NavigationLink3D, opened: bool) -> void:
	(door.get_child(0) as CollisionShape3D).set_deferred("disabled", opened)
	(door.get_child(1) as MeshInstance3D).visible = not opened
	link.enabled = opened

func _on_capture(actor: Node3D) -> void:
	if not outcome.is_empty():
		return
	capture_count += 1
	outcome = "captured"
	player.movement_enabled = false
	player.velocity = Vector3.ZERO
	var forward := -actor.global_basis.z
	scare_camera.global_position = actor.global_position + forward * 0.47 + Vector3.UP * 1.46
	scare_camera.look_at(actor.global_position + forward * 0.17 + Vector3.UP * 1.46)
	scare_camera.current = true
	_capture_elapsed = 0.0
	cue = "She was never your mother."
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func finish_test_escape() -> void:
	if not outcome.is_empty():
		return
	escape_progress = MonsterObservation.EscapePhase.ESCAPED
	outcome = "escaped"
	player.movement_enabled = false
	player.velocity = Vector3.ZERO
	_show_end("SAFE TEST EXIT REACHED\nYou escaped the behavior lab.\nPress R to restart. The final game escape belongs to the house system.")
	cue = "Test escape complete."

func _show_end(text: String) -> void:
	end_panel.visible = true
	end_label.text = text
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func reset_lab(player_position: Vector3 = PLAYER_SPAWN, monster_position: Vector3 = MONSTER_SPAWN) -> void:
	for action in ["monster_test_forward", "monster_test_back", "monster_test_left", "monster_test_right", "monster_test_sprint"]:
		Input.action_release(action)
	suspicion_level = 0.0
	escape_progress = MonsterObservation.EscapePhase.EXPLORING
	door_state = MonsterObservation.DoorState.CLOSED
	is_hidden = false
	hiding_check_position = CLOSET_CHECK
	outcome = ""
	door_requested = false
	checked_closet_count = 0
	reveal_count = 0
	capture_count = 0
	_capture_elapsed = 0
	end_panel.visible = false
	door_shadow.visible = false
	player.reset_player(player_position)
	monster.tuning = preload("res://systems/monster/prototype_tuning.tres").duplicate() as MonsterTuning
	monster.reset_controller(monster_position)
	monster.look_at(Vector3(player_position.x, monster_position.y, player_position.z))
	_set_door_open(basement_door, basement_link, false)
	_set_door_open(closet_door, closet_link, true)
	cue = "New test. 1 unaware · 2 doubtful · 3 certain."
	if DisplayServer.get_name() != "headless" and not "--verify-monster" in OS.get_cmdline_user_args():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

