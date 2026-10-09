class_name MonsterController
extends CharacterBody3D
## Threat decisions only. Does not write suspicion, clues, doors, or hiding state.
enum State { DISGUISED, STALKING, PURSUING, SEARCHING, LOST_TARGET, INTERCEPTING, REVEALING, CAPTURED }

signal state_changed(previous: State, current: State)
signal capture_requested(monster: Node3D)
signal interception_ready
signal reveal_started
signal hiding_place_checked(position: Vector3)
signal cue_requested(text: String)

@export var tuning: MonsterTuning
@export var observation_provider: Node
@export var player_actor: CharacterBody3D
@export var interception_anchor: Node3D
@export var retreat_anchor: Node3D

var monster_state: State = State.DISGUISED
var monster_location := Vector3.ZERO
var disguise_state := "Ordinary"
var target: Node3D
var last_seen_position := Vector3.ZERO
var has_last_seen := false
var hidden_still_time := 0.0
var knows_hiding_place := false
var arrived_for_interception := false
var basement_reveal_done := false
var reveal_elapsed := 0.0
var sees_player := false
var player_reachable := false
var destination := Vector3.ZERO
var agent: NavigationAgent3D
var visual: Node3D
var _search_points: Array[Vector3] = []
var _search_index := 0
var _was_visible := false
var _was_hidden := false
var _hiding_checked := false
var _known_hide_position := Vector3.ZERO
var _appearance := ""
var _step_distance := 0.0
var _last_step_position := Vector3.ZERO

func _ready() -> void:
	if tuning == null:
		tuning = MonsterTuning.new()
	collision_layer = 4
	collision_mask = 11 # World (1), player (2), doors (8).
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)
	agent = NavigationAgent3D.new()
	# Paths sit above the collider floor after voxel baking; allow the first
	# waypoint to advance even though the character origin is at its feet.
	agent.path_desired_distance = 0.65
	agent.target_desired_distance = tuning.arrival_distance
	add_child(agent)
	monster_location = global_position
	_last_step_position = global_position
	_set_appearance("Ordinary")

func state_name() -> String:
	return State.keys()[monster_state].capitalize().replace("_", " ")

func navigation_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0

func point_reachable(point: Vector3) -> bool:
	if not navigation_ready():
		return false
	var route := NavigationServer3D.map_get_path(agent.get_navigation_map(), global_position, point, true)
	return not route.is_empty() and route[-1].distance_to(point) < 0.65

func can_see_player(observation: MonsterObservation) -> bool:
	if not is_instance_valid(player_actor):
		return false
	var eye := global_position + Vector3.UP * 1.45
	var aim := observation.player_location + Vector3.UP * 1.55
	var direction := aim - eye
	if direction.length() > tuning.sight_range:
		return false
	var horizontal := Vector3(direction.x, 0, direction.z)
	if horizontal.length() > 0.01:
		if (-global_basis.z).dot(horizontal.normalized()) < cos(deg_to_rad(tuning.sight_angle_degrees * 0.5)):
			return false
	var query := PhysicsRayQueryParameters3D.create(eye, aim, 11, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player_actor

func _physics_process(delta: float) -> void:
	if observation_provider == null or not observation_provider.has_method("read_monster_observation"):
		return
	var observation: MonsterObservation = observation_provider.read_monster_observation()
	if observation.escape_progress == MonsterObservation.EscapePhase.ESCAPED:
		target = null
		velocity = Vector3.ZERO
		_set_visual_motion(false)
		return
	if monster_state == State.CAPTURED:
		return
	sees_player = can_see_player(observation)
	player_reachable = sees_player and point_reachable(observation.player_location)
	if observation.is_hidden and not _was_hidden and (_was_visible or sees_player):
		knows_hiding_place = true
		_known_hide_position = observation.hiding_check_position
		_hiding_checked = false
	if not observation.is_hidden:
		knows_hiding_place = false
		_hiding_checked = false

	if observation.escape_progress >= MonsterObservation.EscapePhase.BASEMENT_READY and not basement_reveal_done:
		_handle_interception(observation, delta)
	else:
		_handle_threat(observation, delta)
	_was_visible = sees_player
	_was_hidden = observation.is_hidden
	monster_location = global_position
	_step_distance += global_position.distance_to(_last_step_position)
	_last_step_position = global_position
	if _step_distance >= 1.0:
		_step_distance = 0.0
		cue_requested.emit("[Footsteps approaching]" if monster_state in [State.PURSUING, State.INTERCEPTING] else "[Measured footsteps]")

func _handle_threat(observation: MonsterObservation, delta: float) -> void:
	var recognition := 2 if basement_reveal_done else 1 if observation.suspicion_level >= tuning.stalk_threshold else 0
	if observation.suspicion_level >= tuning.pursue_threshold:
		recognition = 2
	if recognition == 0:
		_change_state(State.DISGUISED)
		target = null
		has_last_seen = false
		hidden_still_time = 0.0
		_set_appearance("Ordinary")
		_stop(delta)
		return
	_set_appearance("Revealed" if basement_reveal_done else "Uncanny" if recognition == 2 else "Doubtful")
	if knows_hiding_place and observation.is_hidden:
		target = player_actor
		_change_state(State.SEARCHING)
		hidden_still_time = 0.0
		_walk_to(_known_hide_position, tuning.stalk_speed, delta)
		if _flat_distance(global_position, _known_hide_position) < 1.5 and not _hiding_checked:
			_hiding_checked = true
			hiding_place_checked.emit(_known_hide_position)
		return
	if sees_player:
		target = player_actor
		last_seen_position = observation.player_location
		has_last_seen = true
		hidden_still_time = 0.0
		if player_reachable:
			if recognition == 2:
				_change_state(State.PURSUING)
				if _flat_distance(global_position, observation.player_location) <= tuning.capture_distance:
					_capture()
					return
				_walk_to(observation.player_location, tuning.chase_speed, delta)
			else:
				_change_state(State.STALKING)
				var distance := _flat_distance(global_position, observation.player_location)
				if distance > tuning.stalk_distance + 0.25:
					_walk_to(observation.player_location, tuning.stalk_speed, delta)
				elif distance < tuning.stalk_distance * 0.65:
					var away := (global_position - observation.player_location).normalized()
					_walk_to(global_position + away * 1.5, tuning.stalk_speed, delta)
				else:
					_face(observation.player_location, delta)
					_stop(delta)
			return
	if has_last_seen:
		if monster_state != State.SEARCHING or _search_points.is_empty():
			_begin_search()
		if observation.is_hidden and observation.player_is_still and not sees_player:
			hidden_still_time += delta
		else:
			hidden_still_time = 0.0
		if hidden_still_time >= tuning.hidden_still_seconds:
			_lose_target()
			_stop(delta)
			return
		_search(delta)
	else:
		_change_state(State.LOST_TARGET)
		if retreat_anchor != null:
			_walk_to(retreat_anchor.global_position, tuning.stalk_speed, delta)
		else:
			_stop(delta)

func _handle_interception(observation: MonsterObservation, delta: float) -> void:
	hidden_still_time = 0.0
	if interception_anchor == null:
		_stop(delta)
		return
	if monster_state != State.REVEALING:
		_change_state(State.INTERCEPTING)
		target = null
		if not arrived_for_interception:
			_walk_to(interception_anchor.global_position, tuning.stalk_speed, delta)
			if _flat_distance(global_position, interception_anchor.global_position) <= tuning.arrival_distance and point_reachable(interception_anchor.global_position):
				arrived_for_interception = true
				interception_ready.emit()
				cue_requested.emit("[Footsteps stop just beyond the basement door]")
		if arrived_for_interception:
			_stop(delta)
			_face(interception_anchor.global_position + interception_anchor.global_basis.z * 3, delta)
			if observation.door_state == MonsterObservation.DoorState.OPEN:
				_change_state(State.REVEALING)
				reveal_elapsed = 0.0
				_set_appearance("Revealed")
				reveal_started.emit()
		return
	_stop(delta)
	if sees_player:
		last_seen_position = observation.player_location
		has_last_seen = true
		target = player_actor
	reveal_elapsed += delta
	if reveal_elapsed >= tuning.reveal_pause_seconds:
		basement_reveal_done = true
		_handle_threat(observation, delta)

func _begin_search() -> void:
	_change_state(State.SEARCHING)
	_search_points.clear()
	_search_index = 0
	var map := agent.get_navigation_map()
	for offset in [Vector3.ZERO, Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK]:
		var point := NavigationServer3D.map_get_closest_point(map, last_seen_position + offset * tuning.search_radius)
		if point_reachable(point):
			_search_points.append(point)
	cue_requested.emit("[Footsteps slow; she is searching the last place she saw you]")

func _search(delta: float) -> void:
	if _search_index >= _search_points.size():
		_lose_target()
		_stop(delta)
		return
	var point := _search_points[_search_index]
	if _flat_distance(global_position, point) <= tuning.arrival_distance:
		_search_index += 1
		_stop(delta)
	else:
		_walk_to(point, tuning.stalk_speed * 0.8, delta)

func _lose_target() -> void:
	target = null
	has_last_seen = false
	knows_hiding_place = false
	hidden_still_time = 0.0
	_search_points.clear()
	_search_index = 0
	_change_state(State.LOST_TARGET)
	cue_requested.emit("[Footsteps recede; she has lost you]")

func _walk_to(point: Vector3, speed: float, delta: float) -> void:
	destination = point
	if not navigation_ready() or not point_reachable(point):
		_stop(delta)
		return
	if agent.target_position.distance_to(point) > 0.15:
		agent.target_position = point
	var next := agent.get_next_path_position()
	var direction := next - global_position
	direction.y = 0
	if direction.length() <= 0.05:
		_stop(delta)
		return
	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	_face(global_position + direction, delta)
	move_and_slide()
	_set_visual_motion(Vector2(velocity.x, velocity.z).length() > 0.1)

func _face(point: Vector3, delta: float) -> void:
	var direction := point - global_position
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), min(1.0, delta * 8.0))

func _stop(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_set_visual_motion(false)

func _capture() -> void:
	_change_state(State.CAPTURED)
	_set_appearance("Revealed")
	velocity = Vector3.ZERO
	_set_visual_motion(false)
	capture_requested.emit(self)

func _change_state(next: State) -> void:
	if next == monster_state:
		return
	var previous := monster_state
	monster_state = next
	state_changed.emit(previous, next)

func _set_appearance(appearance: String) -> void:
	disguise_state = appearance
	if _appearance == appearance:
		return
	_appearance = appearance
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	visual = preload("res://assets/monster/MotherVisual.tscn").instantiate()
	visual.set("appearance", appearance)
	visual.rotation.y = PI # Asset faces +Z; CharacterBody faces -Z.
	add_child(visual)

func _set_visual_motion(moving: bool) -> void:
	if not is_instance_valid(visual):
		return
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var animation := players[0] as AnimationPlayer
	if moving:
		animation.speed_scale = max(0.5, Vector2(velocity.x, velocity.z).length() / 2.0)
		if not animation.is_playing():
			animation.play()
	else:
		animation.pause()

func reset_controller(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	target = null
	has_last_seen = false
	last_seen_position = Vector3.ZERO
	hidden_still_time = 0.0
	knows_hiding_place = false
	arrived_for_interception = false
	basement_reveal_done = false
	reveal_elapsed = 0.0
	sees_player = false
	player_reachable = false
	_was_visible = false
	_was_hidden = false
	_hiding_checked = false
	_search_points.clear()
	_search_index = 0
	destination = position
	agent.target_position = position
	_last_step_position = position
	_step_distance = 0.0
	_change_state(State.DISGUISED)
	_set_appearance("Ordinary")
	monster_location = position

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

