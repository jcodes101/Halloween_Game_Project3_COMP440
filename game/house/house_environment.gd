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
@export_group("Flashlight Battery Pickups")
@export_range(6, 8, 1) var battery_pickup_min_count := 6
@export_range(6, 8, 1) var battery_pickup_max_count := 8
@export_range(1.0, 100.0, 1.0) var battery_recharge_amount := 35.0
@export var battery_spawn_seed := 0
var battery_pickups: Array[Node3D] = []
var battery_spawn_floor_counts: Dictionary = {}
var _battery_rng := RandomNumberGenerator.new()
var _collected_battery_ids: Dictionary = {}
var bedroom_departure_pending := true
var start_in_bedroom := true

const BATTERY_SPAWN_POINTS := {
	"Basement": [Vector3(-3.0,-3.6,2.0), Vector3(4.0,-3.6,-5.0), Vector3(0.0,-3.6,-10.0), Vector3(-3.0,-3.6,-16.0), Vector3(4.0,-3.6,-19.0)],
	"Ground Floor": [Vector3(-3.5,0.0,9.0), Vector3(-7.0,0.0,-3.0), Vector3(5.0,0.0,-5.0), Vector3(4.0,0.0,-10.0), Vector3(-4.0,0.0,-18.0), Vector3(2.5,0.0,-14.5), Vector3(4.0,0.0,-20.0)],
	"Second Floor": [Vector3(-3.5,3.6,6.0), Vector3(6.0,3.6,7.0), Vector3(-3.0,3.6,-2.0), Vector3(4.0,3.6,-2.0), Vector3(-9.0,3.6,-19.0), Vector3(9.5,3.6,-19.0), Vector3(-4.0,3.6,-9.0)],
	"Attic": [Vector3(-3.0,7.2,-8.0), Vector3(3.0,7.2,0.0), Vector3(0.0,7.2,7.0)]
}

func _build_world() -> void:
	builder = preload("res://game/house/house_builder.gd").new()
	add_child(builder)
	builder.build()
	_interactables = builder.hide_spots.duplicate(true)
	_spawn_battery_pickups()
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
	var args := OS.get_cmdline_user_args()
	if "--verify-house" in args or "--verify-game" in args or "--verify-monster" in args:
		start_in_bedroom = false
	if start_in_bedroom:
		_player.position = Vector3(-8.0,3.6,-4.4)
		_player.rotation.y = -PI * 0.5
	else:
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
		if entry.kind == "battery" and (not is_instance_valid(entry.get("pickup_node")) or _collected_battery_ids.has(int(entry.get("pickup_id", -1)))):
			continue
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
		"battery":
			_collect_battery(target)
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
				var opening := not bool(builder.doors[id].open)
				if not opening and _doorway_occupied(id):
					_show_message("Step clear of the door before closing it.")
				else:
					_set_room_door(id,opening)
		"hide":
			var config: Dictionary = target.hide_config
			_active_closet = bool(config.get("closet",false))
			if _active_closet: _set_room_door("closet",true)
			active_hide_check_position = config.entry
			hiding_attempted.emit(active_hide_check_position)
			_player.begin_hiding(config)
	environment_state_changed.emit()

func _spawn_battery_pickups() -> void:
	battery_pickups.clear()
	battery_spawn_floor_counts.clear()
	_collected_battery_ids.clear()
	var selected := _roll_battery_spawn_points(battery_spawn_seed)
	for index in range(selected.size()):
		var spawn: Dictionary = selected[index]
		var floor_name: String = spawn.floor
		var floor_counts: int = int(battery_spawn_floor_counts.get(floor_name, 0)) + 1
		battery_spawn_floor_counts[floor_name] = floor_counts
		var pickup := _make_battery_pickup(index)
		pickup.position = spawn.position
		builder.add_child(pickup)
		battery_pickups.append(pickup)
		_interactables.append({
			"title":"Flashlight battery", "kind":"battery",
			"position":spawn.position + Vector3.UP * 0.2,
			"prompt":"[E] Collect battery", "pickup_node":pickup,
			"pickup_id":index, "floor":floor_name
		})

func _roll_battery_spawn_points(seed_value: int = 0) -> Array[Dictionary]:
	if seed_value == 0:
		_battery_rng.randomize()
	else:
		_battery_rng.seed = seed_value
	var selected: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for floor_name in BATTERY_SPAWN_POINTS.keys():
		var points: Array = BATTERY_SPAWN_POINTS[floor_name].duplicate()
		_shuffle_battery_array(points)
		var guaranteed_point: Vector3 = points.pop_back()
		selected.append({"floor":str(floor_name), "position":guaranteed_point})
		for point in points:
			remaining.append({"floor":str(floor_name), "position":point})
	_shuffle_battery_array(remaining)
	var min_count := mini(battery_pickup_min_count, battery_pickup_max_count)
	var max_count := maxi(battery_pickup_min_count, battery_pickup_max_count)
	var desired_count := clampi(_battery_rng.randi_range(min_count, max_count), 4, remaining.size() + 4)
	for index in range(desired_count - selected.size()):
		selected.append(remaining[index])
	return selected

func _shuffle_battery_array(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := _battery_rng.randi_range(0, index)
		var item: Variant = values[index]
		values[index] = values[other]
		values[other] = item

func _make_battery_pickup(index: int) -> Node3D:
	var pickup := Node3D.new()
	pickup.name = "BatteryPickup_%02d" % (index + 1)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("bc9957")
	body_material.metallic = 0.42
	body_material.roughness = 0.38
	body_material.emission_enabled = true
	body_material.emission = Color("46371f")
	var body := MeshInstance3D.new()
	var battery_mesh := CylinderMesh.new()
	battery_mesh.top_radius = 0.075
	battery_mesh.bottom_radius = 0.075
	battery_mesh.height = 0.24
	body.mesh = battery_mesh
	body.material_override = body_material
	body.position.y = 0.15
	pickup.add_child(body)
	var terminal := MeshInstance3D.new()
	var terminal_mesh := CylinderMesh.new()
	terminal_mesh.top_radius = 0.042
	terminal_mesh.bottom_radius = 0.052
	terminal_mesh.height = 0.035
	terminal.mesh = terminal_mesh
	terminal.material_override = _material(Color("d8cfba"))
	terminal.position.y = 0.287
	pickup.add_child(terminal)
	return pickup

func _collect_battery(target: Dictionary) -> void:
	var pickup := target.get("pickup_node") as Node3D
	if not is_instance_valid(pickup):
		return
	var flashlight := _player.get_node_or_null("FlashlightController")
	if flashlight == null or not flashlight.has_method("recharge_battery"):
		return
	var restored := float(flashlight.call("recharge_battery", battery_recharge_amount))
	var pickup_id := int(target.get("pickup_id", -1))
	_collected_battery_ids[pickup_id] = true
	pickup.queue_free()
	interaction_feedback.emit("item_pickup", pickup.global_position)
	_show_message("Battery collected. Charge restored by %d%% (%d%% total)." % [roundi(restored), roundi(float(flashlight.get("battery_percent")))])
	environment_state_changed.emit()

func _set_room_door(id: String, opened: bool) -> void:
	if builder.doors[id].open == opened:
		return
	builder.set_door(id,opened)
	door_state[id] = "open" if opened else "closed"
	interaction_feedback.emit("door_open" if opened else "door_close",builder.doors[id].position)

func open_door_for_monster(id: String) -> bool:
	if not builder.doors.has(id) or builder.doors[id].open or id in ["front_door", "false_exit"]:
		return false
	builder.set_door(id, true)
	door_state[id] = "open"
	return true

func _doorway_occupied(id: String) -> bool:
	if not builder.doors.has(id):
		return false
	var info: Dictionary = builder.doors[id]
	var floor_height: float = info.position.y - 1.0
	var player_flat := Vector2(_player.global_position.x - info.position.x, _player.global_position.z - info.position.z)
	if absf(_player.global_position.y - floor_height) < 1.5 and player_flat.length() < 0.85:
		return true
	var monster := interception_gate.get("monster") as CharacterBody3D if interception_gate != null else null
	if monster != null:
		var monster_flat := Vector2(monster.global_position.x - info.position.x, monster.global_position.z - info.position.z)
		if absf(monster.global_position.y - floor_height) < 1.5 and monster_flat.length() < 0.85:
			return true
	return false

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
		if at.z < -12:
			player_location = "guest_room" if at.x<0 else "upstairs_study"
		else:
			player_location = "second_floor_hall"
			if at.z<0 and at.z> -7 and at.x>1.2: player_location = "mothers_room"
			elif at.z<0 and at.z> -7 and at.x< -1.2: player_location = "your_room"
			elif at.z< -7: player_location = "upstairs_bathroom" if at.x<0 else "upstairs_study"
	elif at.y< -1:
		if at.z < -12:
			player_location = "basement_utility" if at.x > 1.5 else "basement_archive"
		else:
			player_location = "basement_utility" if at.z < -2 else "basement_storage"
	elif absf(at.x)>11 or at.z>12 or at.z< -22:
		player_location = "evening_neighborhood"
	elif at.z < -12:
		if at.x < 0:
			player_location = "family_room"
		else:
			player_location = "breakfast_room" if at.z > -17 else "sunroom"
	elif at.x< -1.2:
		player_location = "kitchen" if at.z>= -7 and at.z<3 else "living_room" if at.z>=3 and at.z<8 else "downstairs_bathroom" if at.z< -7 else "foyer"
	elif at.x>1.2:
		player_location = "pantry" if at.z< -7 else "dining_room" if at.z<0 else "foyer"
	elif at.z>7:
		player_location = "foyer"
	if bedroom_departure_pending and player_location != "your_room":
		bedroom_departure_pending = false
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

func objective_text() -> String:
	if bedroom_departure_pending:
		return "Leave your bedroom."
	if escape_progress == EscapeProgress.ESCAPED: return "Escaped into the evening neighborhood"
	if escape_progress == EscapeProgress.CAPTURED: return "Captured"
	if window_open: return "Jump through the attic window and land outside"
	if attic_open: return "Unlock the attic window with Mother's key"
	if has_crowbar: return "Pry open the second-floor attic hatch"
	if has_window_key: return "Find the crowbar in the basement"
	return "Find the crowbar in the basement and Mother's window key"

func mark_player_captured() -> void:
	climb_in_progress = false
	super()
