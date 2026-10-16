class_name MonsterController
extends CharacterBody3D
## Threat decisions only. Does not write suspicion, clues, doors, or hiding state.
enum State { DISGUISED, STALKING, PURSUING, SEARCHING, LOST_TARGET, INTERCEPTING, REVEALING, STUNNED, RETREATING, RECOVERING, CAPTURED }

signal state_changed(previous: State, current: State)
signal capture_requested(monster: Node3D)
signal close_encounter_requested(monster: Node3D, duration: float)
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
var search_locations: Array[Vector3] = [] # Static room centers and public hide entrances; never the hidden player.
var hunt_waypoints: Array[Vector3] = []
var _hunt_index := 0
## Authored stair landings supplied by the house; movement stays collision-based.
var stair_flights: Array[Dictionary] = []
var _crossing_stair := false
var _stair_exit := Vector3.ZERO
var _search_travel_seconds := 0.0
var _search_needs_refresh := false
var _search_origin := Vector3.ZERO
var _search_index := 0
var _search_pause_remaining := 0.0
var _was_visible := false
var _was_hidden := false
var _hiding_checked := false
var _known_hide_position := Vector3.ZERO
var _appearance := ""
var _step_distance := 0.0
var _last_step_position := Vector3.ZERO
var encounter_pending := false
var encounter_cooldown := 0.0
var stun_remaining := 0.0
var last_heard_position := Vector3.ZERO
var _path_refresh_timer := 0.0
var _reachability_refresh_timer := 0.0
var _visual_contact_seconds := 0.0
var _player_navigation_position := Vector3.ZERO
var _retreat_elapsed := 0.0
var _retreat_distance := 0.0
var _retreat_origin := Vector3.ZERO
var _retreat_destination := Vector3.ZERO
var _retreat_has_navigation_target := false
var _retreat_fallback_direction := Vector3.ZERO
var _recovery_remaining := 0.0
var _search_rng := RandomNumberGenerator.new()
var _stun_pose_elapsed := 0.0
var _stun_visual_base_position := Vector3.ZERO
var _stun_visual_base_rotation := Vector3.ZERO
var stun_visual_active := false
var pursuit_debug_reason := "Routine"

func _ready() -> void:
	if tuning == null:
		tuning = MonsterTuning.new()
	if tuning.search_random_seed == 0:
		_search_rng.randomize()
	else:
		_search_rng.seed = tuning.search_random_seed
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

## Returns a bounded alert amount for a sound that physically occurred nearby.
## The caller owns suspicion; this controller only records the heard location.
func hear_sound(location: Vector3, loudness: float) -> float:
	if monster_state == State.CAPTURED or encounter_pending:
		return 0.0
	var distance := global_position.distance_to(location)
	if distance > tuning.hearing_distance:
		return 0.0
	var alert := heard_alert(location, loudness)
	if alert <= 0.0:
		return 0.0
	if monster_state == State.SEARCHING and location.distance_to(_search_origin) > tuning.arrival_distance * 2.0:
		_search_needs_refresh = true
	last_heard_position = location
	last_seen_position = location
	has_last_seen = true
	return alert

## Geometry affects AI hearing, not the audio mix. Exclude each whole collider
## after a hit so both faces of one wall do not count twice.
func heard_alert(location: Vector3, loudness: float) -> float:
	var distance := global_position.distance_to(location)
	if distance > tuning.hearing_distance:
		return 0.0
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(player_actor):
		excluded.append(player_actor.get_rid())
	var attenuation := 0.0
	for barrier in range(3):
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, location + Vector3.UP * 1.0, 9, excluded)
		ray.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			break
		var body := hit.get("collider") as CollisionObject3D
		if body == null:
			break
		attenuation += tuning.closed_door_sound_loss if body.collision_layer & 8 else tuning.wall_sound_loss
		excluded.append(body.get_rid())
	return clampf(loudness - distance * tuning.sound_falloff_per_meter - attenuation, 0.0, 60.0)

func can_see_player(observation: MonsterObservation) -> bool:
	if not is_instance_valid(player_actor):
		return false
	# A completed hiding transition conceals the player. Entry visibility is
	# sampled by the Environment before the transition starts; known hiding spots
	# are investigated through the separate hiding_place_checked path.
	if observation.is_hidden:
		return false
	var eye := global_position + Vector3.UP * 1.45
	var aim := observation.player_location + Vector3.UP * 1.55
	if player_actor.has_method("monster_sight_position"):
		aim = player_actor.monster_sight_position()
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
	encounter_cooldown = maxf(0.0, encounter_cooldown - delta)
	_path_refresh_timer = maxf(0.0, _path_refresh_timer - delta)
	_reachability_refresh_timer = maxf(0.0, _reachability_refresh_timer - delta)
	if encounter_pending:
		pursuit_debug_reason = "Capture QTE active"
		_stop(delta)
		return
	if monster_state == State.STUNNED:
		_update_stun_visual(delta)
		_stagger_away_from_player(delta)
		if stun_remaining <= 0.0:
			_begin_retreat()
		return
	if monster_state == State.RETREATING:
		_process_retreat(delta)
		return
	if monster_state == State.RECOVERING:
		_process_recovery(delta)
		return
	if stun_visual_active:
		_restore_stun_visual()
	sees_player = can_see_player(observation)
	if sees_player:
		_visual_contact_seconds += delta
		if _reachability_refresh_timer <= 0.0:
			_player_navigation_position = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), observation.player_location) if navigation_ready() else observation.player_location
			player_reachable = navigation_ready() and point_reachable(_player_navigation_position)
			_reachability_refresh_timer = tuning.reachability_refresh_seconds
	else:
		_visual_contact_seconds = 0.0
		player_reachable = false
		_reachability_refresh_timer = 0.0
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
	var sight_threshold := tuning.close_sight_confirm_seconds if _flat_distance(global_position, observation.player_location) <= tuning.close_sight_pursuit_distance else tuning.distant_sight_confirm_seconds
	var confirmed_visual_contact := sees_player and _visual_contact_seconds >= sight_threshold
	var evidence_paced := observation.recognition_score >= 0.0
	var recognition_score := observation.recognition_score if evidence_paced else observation.suspicion_level
	var recognition := 2 if basement_reveal_done or (confirmed_visual_contact and not evidence_paced) else 1 if recognition_score >= tuning.stalk_threshold else 0
	if recognition_score >= tuning.pursue_threshold:
		recognition = 2
	if recognition == 0:
		_change_state(State.DISGUISED)
		target = null
		has_last_seen = false
		hidden_still_time = 0.0
		_set_appearance("Ordinary")
		pursuit_debug_reason = "Normal recognition; maintaining disguise" if evidence_paced else "No current suspicion or confirmed sight"
		_stop(delta)
		return
	_set_appearance("Revealed" if basement_reveal_done else "Uncanny" if recognition == 2 else "Doubtful")
	if knows_hiding_place and observation.is_hidden:
		target = player_actor
		_change_state(State.SEARCHING)
		hidden_still_time = 0.0
		_walk_to(_known_hide_position, tuning.stalk_speed, delta)
		if global_position.distance_to(_known_hide_position) < 1.5 and not _hiding_checked:
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
				pursuit_debug_reason = "Visible player confirmed" if confirmed_visual_contact else "Awareness reached pursuit threshold"
				_change_state(State.PURSUING)
				if global_position.distance_to(observation.player_location) <= tuning.capture_distance:
					if encounter_cooldown <= 0.0:
						_try_close_encounter()
					else:
						_stop(delta)
					return
				_walk_to(_player_navigation_position, tuning.enraged_chase_speed if basement_reveal_done else tuning.chase_speed, delta)
			else:
				pursuit_debug_reason = "Doubtful; watching without attacking" if evidence_paced else "Visible; confirming sight"
				_change_state(State.STALKING)
				var distance := _flat_distance(global_position, observation.player_location)
				if distance > tuning.stalk_distance + 0.25:
					_walk_to(_player_navigation_position, tuning.stalk_speed, delta)
				elif distance < tuning.stalk_distance * 0.65:
					var away := (global_position - observation.player_location).normalized()
					_walk_to(global_position + away * 1.5, tuning.stalk_speed, delta)
				else:
					_face(observation.player_location, delta)
					_stop(delta)
			return
		pursuit_debug_reason = "Player visible but no connected navigation route"
	if has_last_seen:
		if not sees_player:
			pursuit_debug_reason = "Searching last confirmed position"
		if monster_state != State.SEARCHING or _search_points.is_empty() or _search_needs_refresh:
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
		pursuit_debug_reason = "No player sighting or credible clue"
		_change_state(State.LOST_TARGET)
		if basement_reveal_done and not hunt_waypoints.is_empty():
			var waypoint := hunt_waypoints[_hunt_index % hunt_waypoints.size()]
			if global_position.distance_to(waypoint) < 0.8:
				_hunt_index += 1
			_walk_to(waypoint, tuning.enraged_search_speed, delta)
		elif retreat_anchor != null:
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
			if global_position.distance_to(interception_anchor.global_position) <= tuning.arrival_distance and point_reachable(interception_anchor.global_position):
				arrived_for_interception = true
				var doorway_direction := interception_anchor.global_basis.z
				rotation.y = atan2(-doorway_direction.x, -doorway_direction.z)
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
	_search_needs_refresh = false
	_search_origin = last_seen_position
	_change_state(State.SEARCHING)
	_search_points.clear()
	_search_index = 0
	_search_pause_remaining = 0.0
	var map := agent.get_navigation_map()
	_search_travel_seconds = 0.0
	# Always investigate the actual last contact first, on its original floor.
	_append_search_point(last_seen_position)
	var nearby: Array[Vector3] = []
	for location in search_locations:
		if absf(location.y - last_seen_position.y) < 1.5 and _flat_distance(location, last_seen_position) <= tuning.room_search_radius:
			nearby.append(location)
	nearby.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(last_seen_position) < b.distance_squared_to(last_seen_position))
	for location in nearby.slice(0, 4):
		_append_search_point(location)
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK]
	for index in range(offsets.size() - 1, 0, -1):
		var other := _search_rng.randi_range(0, index)
		var swap := offsets[index]
		offsets[index] = offsets[other]
		offsets[other] = swap
	for offset in offsets:
		var point := NavigationServer3D.map_get_closest_point(map, last_seen_position + offset * tuning.search_radius)
		if absf(point.y - last_seen_position.y) < 1.5:
			_append_search_point(point)
	cue_requested.emit("[Footsteps slow; she is searching the last place she saw you]")

func _append_search_point(requested: Vector3) -> void:
	var point := NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), requested)
	if absf(point.y - last_seen_position.y) >= 1.5 or point.distance_to(requested) > 1.5 or not point_reachable(point):
		return
	# Nearby probes across a wall must not require a tour of the whole house.
	if not _search_points.is_empty():
		var route := NavigationServer3D.map_get_path(agent.get_navigation_map(), _search_points[0], point, true)
		var length := 0.0
		for index in range(1, route.size()):
			length += route[index - 1].distance_to(route[index])
		if route.is_empty() or length > tuning.room_search_radius * 2.0:
			return
	for existing in _search_points:
		if existing.distance_to(point) < 0.8:
			return
	_search_points.append(point)

func _search(delta: float) -> void:
	if _search_index >= _search_points.size():
		_lose_target()
		_stop(delta)
		return
	var point := _search_points[_search_index]
	_search_travel_seconds += delta
	# Furniture or a newly closed door must not trap the entire search forever.
	if _search_travel_seconds > tuning.search_point_timeout:
		_search_index += 1
		_search_travel_seconds = 0.0
		_search_pause_remaining = 0.0
		return
	if _flat_distance(global_position, point) <= tuning.arrival_distance and absf(global_position.y - point.y) < 1.5:
		if _search_pause_remaining <= 0.0:
			_search_pause_remaining = tuning.search_pause_seconds
		else:
			_search_pause_remaining = maxf(0.0, _search_pause_remaining - delta)
			var look_point := _search_points[(_search_index + 1) % _search_points.size()]
			_face(look_point, delta)
			if _search_pause_remaining <= 0.0:
				_search_index += 1
				_search_travel_seconds = 0.0
		_stop(delta)
	else:
		_walk_to(point, tuning.enraged_search_speed if basement_reveal_done else tuning.stalk_speed * 0.8, delta)

func _lose_target() -> void:
	_search_needs_refresh = false
	target = null
	has_last_seen = false
	knows_hiding_place = false
	hidden_still_time = 0.0
	_search_points.clear()
	_search_index = 0
	_search_pause_remaining = 0.0
	_search_travel_seconds = 0.0
	_change_state(State.LOST_TARGET)
	cue_requested.emit("[Footsteps recede; she has lost you]")

func _walk_to(point: Vector3, speed: float, delta: float) -> void:
	destination = point
	if not navigation_ready():
		_stop(delta)
		return
	if _crossing_stair:
		if global_position.distance_to(_stair_exit) < 0.5:
			_crossing_stair = false
			_path_refresh_timer = 0.0
		else:
			_move_toward_position(_stair_exit,speed,delta)
			return
	# Reach the near landing first instead of cutting diagonally into the side
	# of an off-mesh stair link. Traverse the actual ramp using move_and_slide.
	var entry := Vector3.ZERO
	var exit := Vector3.ZERO
	var nearest_height := INF
	for flight in stair_flights:
		var low: Vector3 = flight.low
		var high: Vector3 = flight.high
		var middle := (low.y + high.y) * 0.5
		if (global_position.y < middle and point.y > middle) or (global_position.y > middle and point.y < middle):
			var candidate: Vector3 = low if global_position.y < middle else high
			var height := absf(global_position.y-candidate.y)
			if height < nearest_height:
				nearest_height = height
				entry = candidate
				exit = high if global_position.y < middle else low
	if nearest_height < INF:
		if global_position.distance_to(entry) < 0.45:
			_crossing_stair = true
			_stair_exit = exit
			_move_toward_position(exit,speed,delta)
			return
		point = entry
	if agent.target_position.distance_to(point) > 0.5 and _path_refresh_timer <= 0.0:
		if not point_reachable(point):
			_stop(delta)
			_path_refresh_timer = tuning.path_refresh_seconds
			return
		agent.target_position = point
		_path_refresh_timer = tuning.path_refresh_seconds
	var next := agent.get_next_path_position()
	_move_toward_position(next,speed,delta)

func _move_toward_position(next: Vector3, speed: float, delta: float) -> void:
	var direction := next - global_position
	direction.y = 0
	if direction.length() <= 0.05:
		_stop(delta)
		return
	direction = direction.normalized()
	var horizontal_target := direction * speed
	velocity.x = move_toward(velocity.x, horizontal_target.x, tuning.acceleration * delta)
	velocity.z = move_toward(velocity.z, horizontal_target.z, tuning.acceleration * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	_face(global_position + direction, delta)
	move_and_slide()
	_set_visual_motion(Vector2(velocity.x, velocity.z).length() > 0.1)

func _face(point: Vector3, delta: float) -> void:
	var direction := point - global_position
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), min(1.0, delta * 8.0))

func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, tuning.deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, tuning.deceleration * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_set_visual_motion(false)

func _capture() -> void:
	if monster_state in [State.STUNNED, State.RETREATING, State.RECOVERING, State.CAPTURED] or encounter_cooldown > 0.0:
		pursuit_debug_reason = "Capture blocked by QTE recovery protection"
		return
	encounter_pending = false
	stun_remaining = 0.0
	_change_state(State.CAPTURED)
	_set_appearance("Revealed")
	velocity = Vector3.ZERO
	_set_visual_motion(false)
	capture_requested.emit(self)

func _try_close_encounter() -> void:
	if encounter_cooldown > 0.0 or encounter_pending or monster_state in [State.STUNNED, State.RETREATING, State.RECOVERING, State.CAPTURED]:
		pursuit_debug_reason = "Capture blocked by encounter cooldown or recovery"
		return
	# Every physical close encounter uses the same QTE path, regardless of the
	# player's flashlight charge or whether its beam is currently on.
	encounter_pending = true
	velocity = Vector3.ZERO
	_set_visual_motion(false)
	close_encounter_requested.emit(self, tuning.qte_window_seconds)

func resolve_close_encounter(escaped: bool) -> void:
	if not encounter_pending:
		return
	encounter_pending = false
	if not escaped:
		_capture()
		return
	encounter_cooldown = maxf(tuning.qte_success_cooldown, tuning.qte_stun_seconds + tuning.qte_retreat_seconds + tuning.qte_recovery_seconds)
	stun_remaining = tuning.qte_stun_seconds
	_begin_stun_reaction()
	last_seen_position = player_actor.global_position if is_instance_valid(player_actor) else global_position
	has_last_seen = true
	target = null
	_visual_contact_seconds = 0.0
	_reachability_refresh_timer = 0.0
	pursuit_debug_reason = "Successful QTE; stunned before retreat"
	_change_state(State.STUNNED)
	cue_requested.emit("[She reels backward. She is stunned]")

func _stagger_away_from_player(delta: float) -> void:
	var away := Vector3.FORWARD
	if is_instance_valid(player_actor):
		away = global_position - player_actor.global_position
		away.y = 0.0
		if away.length_squared() < 0.001:
			away = global_basis.z
		away = away.normalized()
	velocity.x = away.x * tuning.qte_recoil_speed
	velocity.z = away.z * tuning.qte_recoil_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_face(global_position + away, delta)
	_set_visual_motion(Vector2(velocity.x, velocity.z).length() > 0.1)
	stun_remaining = maxf(0.0, stun_remaining - delta)

func _begin_retreat() -> void:
	_restore_stun_visual()
	_retreat_elapsed = 0.0
	_retreat_distance = tuning.qte_retreat_distance
	_retreat_origin = global_position
	_retreat_destination = _choose_retreat_destination()
	_retreat_has_navigation_target = not _retreat_destination.is_equal_approx(global_position)
	_retreat_fallback_direction = _away_from_player()
	_path_refresh_timer = 0.0
	if _retreat_has_navigation_target:
		pursuit_debug_reason = "Retreating along reachable navigation path"
	else:
		pursuit_debug_reason = "No retreat route; collision-safe fallback movement"
	_change_state(State.RETREATING)
	cue_requested.emit("[She turns and runs down the hall]")

func _choose_retreat_destination() -> Vector3:
	if not navigation_ready():
		return global_position
	var away := _away_from_player()
	var angles: Array[float] = [0.0, deg_to_rad(35.0), -deg_to_rad(35.0), deg_to_rad(70.0), -deg_to_rad(70.0), PI]
	var best := global_position
	var best_score := -INF
	var map := agent.get_navigation_map()
	for angle in angles:
		var direction := away.rotated(Vector3.UP, angle).normalized()
		var requested := global_position + direction * tuning.qte_retreat_distance
		var candidate := NavigationServer3D.map_get_closest_point(map, requested)
		var flat_distance := _flat_distance(global_position, candidate)
		if flat_distance < minf(2.0, tuning.qte_retreat_distance * 0.35):
			continue
		var route := NavigationServer3D.map_get_path(map, global_position, candidate, true)
		if route.is_empty() or route[-1].distance_to(candidate) > 0.8:
			continue
		var alignment := Vector2(candidate.x - global_position.x, candidate.z - global_position.z).normalized().dot(Vector2(away.x, away.z).normalized())
		if alignment < -0.1:
			continue
		var score := flat_distance + alignment * tuning.qte_retreat_distance * 0.5
		if score > best_score:
			best_score = score
			best = candidate
	return best

func _away_from_player() -> Vector3:
	var away := Vector3.FORWARD
	if is_instance_valid(player_actor):
		away = global_position - player_actor.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = global_basis.z
	return away.normalized()

func _process_retreat(delta: float) -> void:
	_retreat_elapsed += delta
	if _retreat_has_navigation_target:
		_walk_to(_retreat_destination, tuning.qte_retreat_speed, delta)
	else:
		velocity.x = move_toward(velocity.x, _retreat_fallback_direction.x * tuning.qte_retreat_speed, tuning.acceleration * delta)
		velocity.z = move_toward(velocity.z, _retreat_fallback_direction.z * tuning.qte_retreat_speed, tuning.acceleration * delta)
		velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
		_face(global_position + _retreat_fallback_direction, delta)
		move_and_slide()
		_set_visual_motion(Vector2(velocity.x, velocity.z).length() > 0.1)
	var traveled := _flat_distance(global_position, _retreat_origin)
	var arrived := _retreat_has_navigation_target and _flat_distance(global_position, _retreat_destination) <= tuning.arrival_distance
	if arrived or traveled >= tuning.qte_retreat_distance * 0.8 or _retreat_elapsed >= tuning.qte_retreat_seconds:
		_begin_recovery()

func _begin_recovery() -> void:
	_recovery_remaining = tuning.qte_recovery_seconds
	velocity.x = 0.0
	velocity.z = 0.0
	_change_state(State.RECOVERING)
	pursuit_debug_reason = "Recovering after QTE retreat"
	_set_visual_motion(false)

func _process_recovery(delta: float) -> void:
	_stop(delta)
	_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
	if _recovery_remaining > 0.0:
		return
	if has_last_seen:
		_begin_search()
	else:
		_change_state(State.LOST_TARGET)
	pursuit_debug_reason = "Recovery complete; resuming search"

func _begin_stun_reaction() -> void:
	if not is_instance_valid(visual):
		return
	_stun_visual_base_position = visual.position
	_stun_visual_base_rotation = visual.rotation
	_stun_pose_elapsed = 0.0
	stun_visual_active = true
	_set_visual_motion(false)

func _update_stun_visual(delta: float) -> void:
	if not stun_visual_active or not is_instance_valid(visual):
		return
	_stun_pose_elapsed += delta
	var duration := maxf(0.2, tuning.qte_visual_reaction_seconds)
	var t := clampf(_stun_pose_elapsed / duration, 0.0, 1.0)
	# A fast defensive recoil followed by a slower recovery; only the visual child
	# moves, so the navigation agent and collision capsule remain upright.
	var weight := smoothstep(0.0, 0.14, t) if t < 0.14 else 1.0 - smoothstep(0.14, 1.0, t)
	visual.position = _stun_visual_base_position + Vector3(0.0, 0.035 * weight, tuning.qte_visual_recoil_meters * weight)
	var tilt := deg_to_rad(tuning.qte_visual_tilt_degrees) * weight
	visual.rotation = _stun_visual_base_rotation + Vector3(-tilt, 0.0, tilt * 0.55)
	if t >= 1.0:
		_restore_stun_visual()

func _restore_stun_visual() -> void:
	if not stun_visual_active:
		return
	if is_instance_valid(visual):
		visual.position = _stun_visual_base_position
		visual.rotation = _stun_visual_base_rotation
	stun_visual_active = false

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
		stun_visual_active = false
		remove_child(visual)
		visual.queue_free()
	visual = preload("res://assets/monster/MotherVisual.tscn").instantiate()
	visual.set("appearance", appearance)
	visual.rotation.y = PI # Asset faces +Z; CharacterBody faces -Z.
	var performance := preload("res://systems/monster/threat_motion.gd").new()
	performance.actor = self
	visual.add_child(performance)
	add_child(visual)

func _set_visual_motion(moving: bool) -> void:
	if not is_instance_valid(visual):
		return
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var animation := players[0] as AnimationPlayer
	if moving:
		animation.speed_scale = clampf(Vector2(velocity.x, velocity.z).length() / 2.0, 0.5, 2.3)
		if not animation.is_playing():
			animation.play()
	else:
		animation.pause()

func reset_controller(position: Vector3) -> void:
	_crossing_stair = false
	_stair_exit = position
	_hunt_index = 0
	_search_needs_refresh = false
	_search_origin = position
	_restore_stun_visual()
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
	_search_pause_remaining = 0.0
	_search_travel_seconds = 0.0
	destination = position
	agent.target_position = position
	_last_step_position = position
	_step_distance = 0.0
	encounter_pending = false
	encounter_cooldown = 0.0
	stun_remaining = 0.0
	_recovery_remaining = 0.0
	_retreat_elapsed = 0.0
	_retreat_destination = position
	_retreat_has_navigation_target = false
	_visual_contact_seconds = 0.0
	_reachability_refresh_timer = 0.0
	_player_navigation_position = position
	pursuit_debug_reason = "Routine"
	stun_visual_active = false
	_stun_pose_elapsed = 0.0
	_path_refresh_timer = 0.0
	_change_state(State.DISGUISED)
	_set_appearance("Ordinary")
	monster_location = position

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
