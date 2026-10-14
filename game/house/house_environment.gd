extends "res://game/environment/escape_environment.gd"
## Owns the crowbar, bedroom key, attic access, doors, hiding and landing outcome.
var builder: Node3D
var has_crowbar := false
var has_window_key := false
var attic_open := false
var window_open := false
var crossed_window := false
var climb_in_progress := false
var false_exit_attempted := false
var _window_jump_count := 0
var _active_closet := false

func _build_world() -> void:
	builder = preload("res://game/house/house_builder.gd").new()
	add_child(builder)
	builder.build()
	_interactables = builder.hide_spots.duplicate(true)
	_interactables.append({"title":"Basement crowbar","kind":"crowbar","position":Vector3(5,-2.55,-8),"prompt":"E — pick up crowbar"})
	_interactables.append({"title":"Mother's window key","kind":"window_key","position":Vector3(3.5,4.325,-5.5),"prompt":"E — pick up attic window key"})
	_interactables.append({"title":"Boarded attic hatch","kind":"hatch","position":Vector3(0,4.9,-3),"prompt":"E — pry boards / pull down attic ladder"})
	_interactables.append({"title":"Attic ladder","kind":"ladder_down","position":Vector3(0,8.2,-4.5),"prompt":"E — climb down to second floor"})
	_interactables.append({"title":"Attic window","kind":"window","position":Vector3(0,8.3,11.75),"prompt":"E — unlock window; Space + move forward to jump out"})
	for id in builder.doors:
		_interactables.append({"title":id.replace("_"," ").capitalize(),"kind":"door","door_id":id,"position":builder.doors[id].position,"prompt":"E — open / close door"})
	# Existing core state name maps to the false-exit door only, not a victory route.
	door_state["basement_door"] = "locked"
	for id in builder.doors:
		door_state[id] = "open" if builder.doors[id].open else "closed"

func _ready() -> void:
	super()
	_player.position = Vector3(0,0.1,10.5)
	_player.allow_jump = true
	_player.floor_constant_speed = true
	_player.floor_max_angle = deg_to_rad(55)
	_player.floor_block_on_wall = false
	_player.floor_snap_length = 0.4
	_player.safe_margin = 0.05
	_on_player_moved()
	_refresh_state()

func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var distance := INTERACTION_RANGE
	var eye: Vector3 = _player.monster_sight_position()
	var forward: Vector3 = -_player._camera.global_basis.z
	for entry in _interactables:
		if (entry.kind == "crowbar" and has_crowbar) or (entry.kind == "window_key" and has_window_key):
			continue
		if entry.kind == "ladder_down" and not attic_open:
			continue
		var at: Vector3 = entry.position
		var offset := at-eye
		var near := _player.global_position.distance_to(at)
		if near >= distance or (offset.length()>0.1 and forward.dot(offset.normalized())<0.45):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye,at,9,[_player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.distance_to(at)>0.35:
			continue
		best = entry
		distance = near
	return best

func _try_interact() -> void:
	if is_hidden or climb_in_progress or escape_progress in [EscapeProgress.ESCAPED,EscapeProgress.CAPTURED]:
		return
	var target := _nearest_interactable()
	if target.is_empty():
		return
	interact(target)

func interact(target: Dictionary) -> void:
	match str(target.kind):
		"crowbar":
			if has_crowbar: return
			has_crowbar = true
			builder.crowbar.visible = false
			interaction_feedback.emit("item_pickup",target.position)
			_show_message("Crowbar collected. Pry the boarded ceiling hatch upstairs.")
		"window_key":
			if has_window_key: return
			has_window_key = true
			builder.key.visible = false
			interaction_feedback.emit("item_pickup",target.position)
			_show_message("The key from Mother's room fits the attic window.")
		"hatch":
			if not has_crowbar:
				interaction_feedback.emit("locked_door",target.position)
				_show_message("Boarded shut. Find a crowbar in the basement.")
				return
			if not attic_open:
				attic_open = true
				builder.boards.visible = false
				builder.get_node("HatchBlocker").queue_free()
				builder.ladder.visible = true
				interaction_feedback.emit("door_open",target.position)
				_show_message("Boards removed. The pull-down ladder is ready. E to climb.")
			else:
				climb_ladder(true)
		"ladder_down":
			climb_ladder(false)
		"window":
			if not has_window_key:
				interaction_feedback.emit("locked_door",target.position)
				_show_message("Locked. The key is in Mother's room.")
				return
			if not window_open:
				window_open = true
				builder.window_barrier.collision_layer = 0
				builder.window_glass.visible = false
				builder.window_sign.text = "ATTIC WINDOW — OPEN"
				_window_jump_count = _player.jump_count
				interaction_feedback.emit("door_open",target.position)
			_show_message("The window is open. Jump through it and land outside.")
		"door":
			var id: String = target.door_id
			if id == "false_exit":
				false_exit_attempted = true
				escape_progress = EscapeProgress.BASEMENT_READY
				open_basement_route()
			elif id == "front_door":
				interaction_feedback.emit("locked_door",target.position)
				_show_message("The front door is jammed. Find another way outside.")
			else:
				_set_room_door(id,not builder.doors[id].open)
		"hide":
			var config: Dictionary = target.hide_config
			_active_closet = bool(config.get("closet",false))
			if _active_closet: _set_room_door("closet",true)
			active_hide_check_position = config.entry
			hiding_attempted.emit(active_hide_check_position)
			_player.begin_hiding(config)
	environment_state_changed.emit()

func _set_room_door(id: String, opened: bool) -> void:
	if builder.doors[id].open == opened:
		return
	builder.set_door(id,opened)
	door_state[id] = "open" if opened else "closed"
	interaction_feedback.emit("door_open" if opened else "door_close",builder.doors[id].position)

func open_basement_route() -> void:
	if not false_exit_attempted or door_state["basement_door"] == "open":
		return
	if interception_gate != null and not interception_gate.request_door_open():
		_show_message("[Footsteps approaching behind the false exit] The handle resists.")
		return
	_set_room_door("false_exit",true)
	door_state["basement_door"] = "open"
	escape_progress = EscapeProgress.BASEMENT_ENTERED
	basement_reveal_requested.emit()
	_show_message("A wall beyond the door. This is not an exit. Run!")
	environment_state_changed.emit()

func climb_ladder(upward: bool) -> void:
	if climb_in_progress or not attic_open:
		return
	climb_in_progress = true
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.velocity = Vector3.ZERO
	var route: Array = [Vector3(0,3.62,-3),Vector3(0,7.35,-3),Vector3(0,7.22,-4.7)] if upward else [Vector3(0,7.35,-3),Vector3(0,3.62,-3),Vector3(0,3.62,-1.6)]
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for point in route:
		tween.tween_property(_player,"global_position",point,0.9)
	await tween.finished
	if escape_progress == EscapeProgress.CAPTURED:
		return
	climb_in_progress = false
	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)
	_player.rotation.y = PI if upward else 0.0
	_on_player_moved()

func _process(delta: float) -> void:
	super(delta)
	if crossed_window and escape_progress != EscapeProgress.ESCAPED and escape_progress != EscapeProgress.CAPTURED:
		if _player.is_on_floor() and _player.global_position.y < 0.5:
			interaction_feedback.emit("item_pickup",_player.global_position)
			_complete_escape()
	elif window_open and _player.global_position.z>12.3 and absf(_player.global_position.x)<1.5 and _player.global_position.y>7.4 and _player.jump_count>_window_jump_count:
		crossed_window = true
		_show_message("You are outside — brace for the landing.")

func _on_player_moved() -> void:
	if is_hidden:
		super()
		return
	var at: Vector3 = _player.global_position
	player_location = "ground_floor_hall"
	if at.y>6:
		player_location = "attic"
	elif at.y>2:
		player_location = "second_floor_hall"
		if at.z<0 and at.z> -7 and at.x>1.2: player_location = "mothers_room"
		elif at.z<0 and at.z> -7 and at.x< -1.2: player_location = "your_room"
		elif at.z< -7: player_location = "upstairs_bathroom" if at.x<0 else "upstairs_study"
	elif at.y< -1:
		player_location = "basement_utility" if at.z< -2 else "basement_storage"
	elif absf(at.x)>11 or at.z>12 or at.z< -12:
		player_location = "evening_neighborhood"
	elif at.x< -1.2:
		player_location = "kitchen" if at.z>= -7 and at.z<3 else "living_room" if at.z>=3 and at.z<7 else "downstairs_bathroom" if at.z< -7 else "foyer"
	elif at.x>1.2:
		player_location = "pantry" if at.z< -7 else "dining_room" if at.z<0 else "foyer"
	elif at.z>7:
		player_location = "foyer"
	_refresh_state()

func _on_hiding_transition_finished(entered: bool, succeeded: bool) -> void:
	super(entered,succeeded)
	if entered and succeeded and _active_closet:
		_set_room_door("closet",false)

func _escape_from_hide() -> void:
	if _active_closet:
		_set_room_door("closet",true)
	super()

func _refresh_state() -> void:
	if _status == null:
		return
	var objective := "Find the crowbar in basement / key in Mother's room"
	if has_crowbar: objective = "Pry the second-floor ceiling hatch with the crowbar"
	if attic_open: objective = "Unlock attic window with Mother's room key"
	if window_open: objective = "Space + forward: jump out and land in the neighborhood"
	if escape_progress == EscapeProgress.ESCAPED: objective = "Escaped into the evening neighborhood"
	if escape_progress == EscapeProgress.CAPTURED: objective = "Captured"
	_status.text = "THE FAMILIAR\n%s | Crowbar: %s | Window key: %s\n%s" % [player_location.replace("_"," ").capitalize(),has_crowbar,has_window_key,objective]

func mark_player_captured() -> void:
	climb_in_progress = false
	super()
