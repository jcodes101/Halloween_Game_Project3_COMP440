class_name FamiliarController
extends CharacterBody3D

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")
const FamiliarVisualAdapter = preload("res://systems/familiar/familiar_visual_adapter.gd")
## Controller for the Familiar Behavior System.
## Owns trust_level, behavior_stage, current_action, and is_acting_normal.
## Decoupled from visuals via FamiliarVisualAdapter.
## Communicates with Michael's Observation System via clear public API and signals.

# Signals for state changes
signal behavior_stage_changed(previous_stage: int, new_stage: int)
signal action_changed(previous_action: String, new_action: String)
signal acting_normal_changed(is_acting_normal: bool)
signal trust_level_changed(new_trust: float)
signal greeting_emitted(message: String)
signal cue_emitted(cue_text: String)
signal routine_station_changed(station_name: String)
signal monster_handoff_started
signal monster_handoff_ended

# Exported configuration & dependencies
@export_group("Dependencies")
@export var visual_adapter: FamiliarVisualAdapter
@export var player_target: Node3D
@export var routine_stations: Array[Node3D] = []

@export_group("Tuning")
@export var move_speed_normal: float = 2.0
@export var move_speed_doubtful: float = 1.4
@export var greeting_distance: float = 4.0
@export var greeting_cooldown: float = 20.0
@export var routine_duration_normal: float = 6.0
@export var unnatural_pause_duration: float = 4.0
@export var slow_turn_speed: float = 0.8
@export var stare_turn_speed: float = 5.0

# Owned state
var trust_level: float = 100.0:
	set(val):
		var clamped := clampf(val, 0.0, 100.0)
		if not is_equal_approx(trust_level, clamped):
			trust_level = clamped
			trust_level_changed.emit(trust_level)

var behavior_stage: int = FamiliarConstants.BehaviorStage.NORMAL:
	set(val):
		if behavior_stage != val:
			var prev := behavior_stage
			behavior_stage = val
			_on_stage_changed(prev, val)
			behavior_stage_changed.emit(prev, val)

var current_action: String = FamiliarConstants.ACTION_IDLE:
	set(val):
		if current_action != val:
			var prev := current_action
			current_action = val
			if visual_adapter:
				visual_adapter.play_action(current_action)
			action_changed.emit(prev, val)

var is_acting_normal: bool = true:
	set(val):
		if is_acting_normal != val:
			is_acting_normal = val
			acting_normal_changed.emit(is_acting_normal)

# Internal timers & routine tracking
var suspicion_level: float = 0.0
var routine_timer: float = 0.0
var state_timer: float = 0.0
var greeting_timer: float = 0.0
var current_station_index: int = 0
var target_waypoint: Vector3 = Vector3.ZERO
var is_moving_to_station: bool = false
var has_greeted_player: bool = false
var repeat_chore_count: int = 0

# Dialogue / Cue tables
const GREETING_LINES: Array[String] = [
	"Hello dear, dinner will be ready in a little while.",
	"Did you finish your schoolwork for tomorrow?",
	"You look tired, sweetie. Make yourself comfortable."
]

const DOUBTFUL_CUES: Array[String] = [
	"...Did you hear footsteps upstairs?",
	"Where did I put the paring knife...? I just had it.",
	"Why are you watching me so quietly?",
	"I must have stirred this already... why is it still cold?"
]

const CERTAIN_CUES: Array[String] = [
	"You know, don't you.",
	"Why are you looking at Mother like that?",
	"Come closer. Look at me.",
	"..."
]

func _ready() -> void:
	_resolve_dependencies()
	_initialize_state()

func _resolve_dependencies() -> void:
	if not visual_adapter:
		# Search children for visual adapter implementation without hardcoding paths
		var adapters := find_children("*", "FamiliarVisualAdapter", true, false)
		if not adapters.is_empty():
			visual_adapter = adapters[0] as FamiliarVisualAdapter

func _initialize_state() -> void:
	self.behavior_stage = FamiliarConstants.BehaviorStage.NORMAL
	self.is_acting_normal = true
	self.current_action = FamiliarConstants.ACTION_IDLE
	if visual_adapter:
		visual_adapter.apply_stage(behavior_stage)
		visual_adapter.play_action(current_action)

# ==============================================================================
# Public Interface for Michael's Observation System
# ==============================================================================

## Receives suspicion level from Observation System (0.0 to 100.0).
func set_suspicion_level(new_suspicion: float) -> void:
	suspicion_level = clampf(new_suspicion, 0.0, 100.0)
	# Trust inversely relates to suspicion
	self.trust_level = clampf(100.0 - suspicion_level, 0.0, 100.0)
	_evaluate_stage_from_suspicion()

## Alias for Observation System compatibility
func receive_suspicion(level: float) -> void:
	set_suspicion_level(level)

## Setter for Jadin's player reference
func set_player(node: Node3D) -> void:
	player_target = node

## Setter for Jadin's routine stations
func set_routine_stations(stations: Array) -> void:
	routine_stations.clear()
	for s in stations:
		if s is Node3D:
			routine_stations.append(s)

## Snapshot / context-based observation intake for Observation System adapter
func receive_observation(new_suspicion: float, extra_context: Dictionary = {}) -> void:
	set_suspicion_level(new_suspicion)
	if extra_context.has("player_node") and extra_context["player_node"] is Node3D:
		player_target = extra_context["player_node"]

## Read-only queries for Observation System
func get_behavior_stage() -> int:
	return behavior_stage

func get_current_action() -> String:
	return current_action

func get_is_acting_normal() -> bool:
	return is_acting_normal

func get_trust_level() -> float:
	return trust_level

func get_observation_snapshot() -> Dictionary:
	return {
		"behavior_stage": behavior_stage,
		"stage_name": FamiliarConstants.STAGE_NAMES.get(behavior_stage, "Unknown"),
		"current_action": current_action,
		"is_acting_normal": is_acting_normal,
		"trust_level": trust_level,
		"suspicion_level": suspicion_level
	}

# ==============================================================================
# Physics & Process Loop
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_monster_controlled:
		return
	
	greeting_timer += delta
	
	match behavior_stage:
		FamiliarConstants.BehaviorStage.NORMAL:
			_process_normal_stage(delta)
		FamiliarConstants.BehaviorStage.DOUBTFUL:
			_process_doubtful_stage(delta)
		FamiliarConstants.BehaviorStage.CERTAIN:
			_process_certain_stage(delta)
	
	if visual_adapter:
		visual_adapter.set_movement_velocity(velocity, delta)

# ==============================================================================
# Stage Transition & Evaluation
# ==============================================================================

func _evaluate_stage_from_suspicion() -> void:
	if suspicion_level >= FamiliarConstants.CERTAIN_THRESHOLD:
		self.behavior_stage = FamiliarConstants.BehaviorStage.CERTAIN
	elif suspicion_level >= FamiliarConstants.DOUBTFUL_THRESHOLD:
		self.behavior_stage = FamiliarConstants.BehaviorStage.DOUBTFUL
	else:
		self.behavior_stage = FamiliarConstants.BehaviorStage.NORMAL

func _on_stage_changed(_prev: int, new_stage: int) -> void:
	state_timer = 0.0
	routine_timer = 0.0
	repeat_chore_count = 0
	
	if visual_adapter:
		visual_adapter.apply_stage(new_stage)
	
	match new_stage:
		FamiliarConstants.BehaviorStage.NORMAL:
			self.is_acting_normal = true
			if visual_adapter:
				visual_adapter.set_disturbed_state(false, 0.0)
			_pick_next_routine_station()
		FamiliarConstants.BehaviorStage.DOUBTFUL:
			self.is_acting_normal = false
			if visual_adapter:
				visual_adapter.set_disturbed_state(true, 0.5)
			_emit_random_cue(DOUBTFUL_CUES)
		FamiliarConstants.BehaviorStage.CERTAIN:
			self.is_acting_normal = false
			velocity = Vector3.ZERO
			self.current_action = FamiliarConstants.ACTION_STARING
			if visual_adapter:
				visual_adapter.set_disturbed_state(true, 1.0)
			_emit_random_cue(CERTAIN_CUES)

# ==============================================================================
# Stage 1: Normal Behavior
# ==============================================================================

func _process_normal_stage(delta: float) -> void:
	self.is_acting_normal = true
	
	# Check for player proximity greeting
	if _should_greet_player():
		_execute_greeting(delta)
		return
	
	# Routine navigation and execution
	if is_moving_to_station:
		_navigate_to_waypoint(delta, move_speed_normal)
	else:
		routine_timer += delta
		if routine_timer >= routine_duration_normal:
			_pick_next_routine_station()

func _safe_global_pos(node: Node3D) -> Vector3:
	if not node:
		return Vector3.ZERO
	return node.global_position if node.is_inside_tree() else node.position

func _self_global_pos() -> Vector3:
	return global_position if is_inside_tree() else position

func _should_greet_player() -> bool:
	if not player_target:
		return false
	if greeting_timer < greeting_cooldown and has_greeted_player:
		return false
	var dist: float = _self_global_pos().distance_to(_safe_global_pos(player_target))
	return dist <= greeting_distance

func _execute_greeting(delta: float) -> void:
	if current_action != FamiliarConstants.ACTION_GREET:
		self.current_action = FamiliarConstants.ACTION_GREET
		velocity = Vector3.ZERO
		state_timer = 0.0
		has_greeted_player = true
		greeting_timer = 0.0
		var greet_msg := GREETING_LINES[randi() % GREETING_LINES.size()]
		greeting_emitted.emit(greet_msg)
		cue_emitted.emit(greet_msg)
	
	state_timer += delta
	# Look smoothly at player during greeting
	if player_target:
		_rotate_toward_point(_safe_global_pos(player_target), delta, 3.0)
	
	if state_timer >= 2.5:
		# Resume normal routine after greeting
		_resume_current_station_action()

func _resume_current_station_action() -> void:
	var action_for_station := _get_action_for_station_index(current_station_index)
	self.current_action = action_for_station

# ==============================================================================
# Stage 2: Doubtful Behavior
# ==============================================================================

func _process_doubtful_stage(delta: float) -> void:
	self.is_acting_normal = false
	state_timer += delta
	
	# Sub-states: Repeating Chores -> Unnatural Pause -> Creeping Slow Turn toward player
	match current_action:
		FamiliarConstants.ACTION_REPEATING_CHORE:
			velocity = Vector3.ZERO
			if state_timer >= 4.0:
				# Transition to unnatural freeze/pause
				_trigger_unnatural_pause()
		
		FamiliarConstants.ACTION_UNNATURAL_PAUSE:
			velocity = Vector3.ZERO
			# Freeze completely in place
			if player_target and state_timer > 1.5:
				# Begin slowly turning toward the player mid-pause
				self.current_action = FamiliarConstants.ACTION_SLOW_TURN
		
		FamiliarConstants.ACTION_SLOW_TURN:
			velocity = Vector3.ZERO
			if player_target:
				_rotate_toward_point(player_target.global_position, delta, slow_turn_speed)
			if state_timer >= unnatural_pause_duration + 2.0:
				# Cycle to another flawed chore or resume erratic navigation
				state_timer = 0.0
				repeat_chore_count += 1
				if repeat_chore_count > 2:
					repeat_chore_count = 0
					_pick_next_routine_station()
				else:
					self.current_action = FamiliarConstants.ACTION_REPEATING_CHORE
					_emit_random_cue(DOUBTFUL_CUES)
		
		_:
			# Default routine interrupted by faulty chore
			if is_moving_to_station:
				_navigate_to_waypoint(delta, move_speed_doubtful)
			else:
				self.current_action = FamiliarConstants.ACTION_REPEATING_CHORE
				state_timer = 0.0

func _trigger_unnatural_pause() -> void:
	self.current_action = FamiliarConstants.ACTION_UNNATURAL_PAUSE
	velocity = Vector3.ZERO
	state_timer = 0.0

# ==============================================================================
# Stage 3: Certain Behavior
# ==============================================================================

func _process_certain_stage(delta: float) -> void:
	self.is_acting_normal = false
	velocity = Vector3.ZERO
	
	# Routines stopped; locked stare at the player
	if current_action != FamiliarConstants.ACTION_STARING and current_action != FamiliarConstants.ACTION_DISTURBED_IDLE:
		self.current_action = FamiliarConstants.ACTION_STARING
	
	if player_target:
		# Rigid locked orientation tracking the player directly
		var p_pos := _safe_global_pos(player_target)
		_rotate_toward_point(p_pos, delta, stare_turn_speed)
		if visual_adapter:
			visual_adapter.look_toward(p_pos, delta, stare_turn_speed)
	
	state_timer += delta
	if state_timer >= 7.0:
		state_timer = 0.0
		_emit_random_cue(CERTAIN_CUES)

# ==============================================================================
# Routine Station Management
# ==============================================================================

func _pick_next_routine_station() -> void:
	routine_timer = 0.0
	state_timer = 0.0
	
	if routine_stations.is_empty():
		# Fallback to local default waypoints if no external station nodes configured
		current_station_index = (current_station_index + 1) % 4
		target_waypoint = _get_default_station_pos(current_station_index)
	else:
		current_station_index = (current_station_index + 1) % routine_stations.size()
		target_waypoint = routine_stations[current_station_index].global_position
	
	is_moving_to_station = true
	self.current_action = FamiliarConstants.ACTION_IDLE
	var station_name := _get_station_name(current_station_index)
	routine_station_changed.emit(station_name)

func _navigate_to_waypoint(delta: float, speed: float) -> void:
	var to_target: Vector3 = target_waypoint - _self_global_pos()
	to_target.y = 0.0 # Keep on ground plane
	var dist: float = to_target.length()
	
	if dist <= 0.4:
		# Arrived at routine station
		is_moving_to_station = false
		velocity = Vector3.ZERO
		_resume_current_station_action()
	else:
		var dir := to_target.normalized()
		velocity = dir * speed
		_rotate_toward_point(target_waypoint, delta, 4.0)
		move_and_slide()

func _rotate_toward_point(target_pos: Vector3, delta: float, turn_speed: float) -> void:
	var local_dir: Vector3 = target_pos - _self_global_pos()
	local_dir.y = 0.0
	if local_dir.length_squared() > 0.01:
		var target_angle: float = atan2(-local_dir.x, -local_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * turn_speed)
		if visual_adapter:
			visual_adapter.look_toward(target_pos, delta, turn_speed)

func _get_action_for_station_index(idx: int) -> String:
	match idx % 4:
		0: return FamiliarConstants.ACTION_COOKING
		1: return FamiliarConstants.ACTION_CLEANING
		2: return FamiliarConstants.ACTION_READING
		3: return FamiliarConstants.ACTION_CHECKING_PANTRY
		_: return FamiliarConstants.ACTION_IDLE

func _get_station_name(idx: int) -> String:
	match idx % 4:
		0: return FamiliarConstants.STATION_KITCHEN
		1: return FamiliarConstants.STATION_DINING
		2: return FamiliarConstants.STATION_BOOKSHELF
		3: return FamiliarConstants.STATION_PANTRY
		_: return "General"

func _get_default_station_pos(idx: int) -> Vector3:
	match idx % 4:
		0: return Vector3(-3.0, 0.0, -2.0) # Kitchen
		1: return Vector3(2.5, 0.0, -2.5)  # Dining
		2: return Vector3(3.0, 0.0, 2.5)   # Bookshelf
		3: return Vector3(-2.5, 0.0, 2.5)  # Pantry
		_: return Vector3.ZERO

func _emit_random_cue(cue_list: Array[String]) -> void:
	if cue_list.is_empty():
		return
	var text := cue_list[randi() % cue_list.size()]
	cue_emitted.emit(text)

# ==============================================================================
# Helper / Test Methods
# ==============================================================================

func force_stage(stage: int) -> void:
	match stage:
		FamiliarConstants.BehaviorStage.NORMAL:
			set_suspicion_level(15.0)
		FamiliarConstants.BehaviorStage.DOUBTFUL:
			set_suspicion_level(50.0)
		FamiliarConstants.BehaviorStage.CERTAIN:
			set_suspicion_level(85.0)

func force_next_station() -> void:
	_pick_next_routine_station()

func force_pause() -> void:
	_trigger_unnatural_pause()

# ==============================================================================
# Monster Handoff API
# ==============================================================================

var is_monster_controlled: bool = false

func hand_off_to_monster() -> void:
	is_monster_controlled = true
	velocity = Vector3.ZERO
	if visual_adapter and visual_adapter.has_method("hand_off_to_monster"):
		visual_adapter.call("hand_off_to_monster")
	monster_handoff_started.emit()

func reclaim_from_monster() -> void:
	is_monster_controlled = false
	if visual_adapter and visual_adapter.has_method("reclaim_from_monster"):
		visual_adapter.call("reclaim_from_monster")
	else:
		_initialize_state()
	monster_handoff_ended.emit()

