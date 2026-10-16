extends CharacterBody3D

signal moved
signal interact_requested
signal escape_requested
signal hiding_transition_finished(entered: bool, succeeded: bool)

const WALK_SPEED := 4.2
const RUN_SPEED := 5.8
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity := 0.0022
const GRAVITY := 18.0
const STANDING_HEIGHT := 1.8
const STANDING_CAMERA_Y := 1.05
const CAMERA_BOB_WALK := 0.012
const CAMERA_BOB_RUN := 0.021
const CAMERA_ROLL_MAX := 0.006
@export_group("Camera Comfort")
@export_range(0.0, 15.0, 1.0) var initial_look_up_degrees := 10.0
@export_range(0.0, 1.0, 0.05) var camera_motion_intensity := 1.0
@export_range(4.0, 32.0, 1.0) var ground_acceleration := 18.0
@export_range(4.0, 36.0, 1.0) var ground_deceleration := 24.0

var _camera: Camera3D
var flashlight: Node
var _capsule_node: CollisionShape3D
var _capsule_shape: CapsuleShape3D
var _hidden := false
var _transitioning := false
var _qte_locked := false
var _transition_tween: Tween
var _hide_config: Dictionary = {}
var _step_timer := 0.0
var _last_position := Vector3.ZERO
var _bob_phase := 0.0
var _bob_strength := 0.0
var _landing_offset := 0.0
var _was_on_floor := false
var _base_camera_position := Vector3(0, STANDING_CAMERA_Y, 0)
var _base_camera_roll := 0.0
var _qte_shove_strength := 0.0
var _qte_shove_tween: Tween
var _opening_camera_animated := false
var _transition_start_position := Vector3.ZERO
var _transition_start_yaw := 0.0
@export var allow_jump := false
var _jump_requested := false
var jump_count := 0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_capsule_node = CollisionShape3D.new()
	_capsule_shape = CapsuleShape3D.new()
	_capsule_shape.radius = 0.35
	_capsule_shape.height = STANDING_HEIGHT
	_capsule_node.shape = _capsule_shape
	_capsule_node.position.y = STANDING_HEIGHT * 0.5
	add_child(_capsule_node)
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.position = _base_camera_position
	_camera.rotation = standing_camera_rotation()
	_camera.current = true
	_camera.fov = 78
	add_child(_camera)
	flashlight = get_node_or_null("FlashlightController")
	_last_position = global_position
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(55)
	floor_snap_length = 0.4
	floor_block_on_wall = false
	safe_margin = 0.05
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_update_camera_bob(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or _qte_locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotate_x(-event.relative.y * mouse_sensitivity)
		_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-82), deg_to_rad(82))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if _hidden:
				escape_requested.emit()
			else:
				interact_requested.emit()
		elif event.is_action_pressed("flashlight_toggle") and not _has_keyboard_focus():
			if flashlight != null:
				flashlight.call("toggle_flashlight")
		elif event.keycode == KEY_SPACE and allow_jump and not _hidden:
			_jump_requested = true

func _has_keyboard_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is Control and focused.focus_mode != Control.FOCUS_NONE

func _physics_process(delta: float) -> void:
	if _transitioning or _qte_locked:
		velocity = Vector3.ZERO
		_last_position = global_position
		return

	var input_vector := Vector2.ZERO
	# Positive Y is forward here, so arrows and WASD share exactly the same mapping.
	if Input.is_action_pressed("move_left"): input_vector.x -= 1.0
	if Input.is_action_pressed("move_right"): input_vector.x += 1.0
	if Input.is_action_pressed("move_forward"): input_vector.y += 1.0
	if Input.is_action_pressed("move_backward"): input_vector.y -= 1.0
	input_vector = input_vector.limit_length()
	var direction := (transform.basis * Vector3(input_vector.x, 0, -input_vector.y)).normalized()
	var is_running := input_vector.length_squared() > 0.0 and Input.is_action_pressed("sprint") and not _hidden
	var movement_speed := RUN_SPEED if is_running else WALK_SPEED
	var horizontal_target := direction * movement_speed
	var horizontal_rate := ground_acceleration if input_vector.length_squared() > 0.0 else ground_deceleration
	velocity.x = move_toward(velocity.x, horizontal_target.x, horizontal_rate * delta)
	velocity.z = move_toward(velocity.z, horizontal_target.z, horizontal_rate * delta)
	if _jump_requested and is_on_floor():
		velocity.y = 7.5
		jump_count += 1
		floor_snap_length = 0.0
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
		floor_snap_length = 0.0
	else:
		velocity.y = 0.0
		floor_snap_length = 0.4
	_jump_requested = false
	var impact_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	var grounded := is_on_floor()
	if grounded and not _was_on_floor and impact_speed > 1.0:
		_landing_offset = -minf(0.045, impact_speed * 0.004) * clampf(camera_motion_intensity, 0.0, 1.0)
	_was_on_floor = grounded
	if global_position.distance_to(_last_position) > 0.018:
		_step_timer += delta
		if _step_timer >= 0.1:
			_step_timer = 0.0
			_last_position = global_position
			if Vector2(velocity.x, velocity.z).length() > 0.15:
				moved.emit()

func is_moving() -> bool:
	return Vector2(get_real_velocity().x, get_real_velocity().z).length() > 0.15

func is_still() -> bool:
	return not _transitioning and not is_moving() and not (Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward") or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"))

func monster_sight_position() -> Vector3:
	return _camera.global_position

func is_transitioning() -> bool:
	return _transitioning

func set_opening_camera_height(height: float) -> void:
	_base_camera_position.y = clampf(height, 0.4, STANDING_CAMERA_Y)
	if _camera != null:
		_camera.position.y = _base_camera_position.y

func set_opening_camera_pose(camera_position: Vector3, camera_rotation: Vector3) -> void:
	_opening_camera_animated = true
	_base_camera_position = camera_position
	if _camera != null:
		_camera.position = camera_position
		_camera.rotation = camera_rotation
		_base_camera_roll = camera_rotation.z

func standing_camera_rotation() -> Vector3:
	return Vector3(deg_to_rad(initial_look_up_degrees),0,0)

func reset_opening_camera_pose() -> void:
	set_opening_camera_pose(Vector3(0.0, STANDING_CAMERA_Y, 0.0), standing_camera_rotation())
	_opening_camera_animated = false

func play_qte_shove_reaction() -> void:
	if camera_motion_intensity <= 0.0 or _camera == null:
		return
	if _qte_shove_tween != null and _qte_shove_tween.is_running():
		_qte_shove_tween.kill()
	_qte_shove_strength = 0.0
	_qte_shove_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_qte_shove_tween.tween_property(self, "_qte_shove_strength", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_qte_shove_tween.tween_property(self, "_qte_shove_strength", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func set_hidden(value: bool) -> void:
	_hidden = value
	if value:
		velocity = Vector3.ZERO

func set_qte_locked(value: bool) -> void:
	_qte_locked = value
	if value:
		velocity = Vector3.ZERO

## Starts a collision-checked, context-configured entry animation.
func begin_hiding(config: Dictionary) -> void:
	if _transitioning or _hidden or config.is_empty():
		return
	var entry_position := _parent_to_global(config.entry)
	var route: Array[Vector3] = []
	for point in config.path:
		route.append(_parent_to_global(point))
	if route.is_empty():
		route.append(entry_position)
	_transition_start_position = global_position
	_transition_start_yaw = rotation.y
	if not _path_is_clear(global_transform, [entry_position]):
		hiding_transition_finished.emit(true, false)
		return

	var crouch_height: float = float(config.get("crouch_height", 0.95))
	var previous_height := _capsule_shape.height
	var previous_center := _capsule_node.position.y
	_set_capsule_height(crouch_height)
	var entry_transform := global_transform
	entry_transform.origin = entry_position
	var path_clear := _path_is_clear(entry_transform, route)
	_set_capsule_height(previous_height)
	_capsule_node.position.y = previous_center
	if not path_clear:
		hiding_transition_finished.emit(true, false)
		return

	_hide_config = config.duplicate(true)
	_transitioning = true
	_bob_strength = 0.0
	_transition_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_transition_tween.tween_property(self, "global_position", entry_position, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_callback(_set_capsule_height.bind(crouch_height))
	var crouch_camera_y: float = float(config.get("crouch_camera_y", 0.78))
	_transition_tween.tween_method(_apply_camera_height_progress.bind(_camera.position.y, crouch_camera_y), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var previous_point := entry_position
	for point in route:
		var duration := maxf(0.22, previous_point.distance_to(point) / 2.2)
		_transition_tween.tween_property(self, "global_position", point, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		previous_point = point
	var hidden_yaw: float = float(config.get("hidden_yaw", rotation.y))
	_transition_tween.parallel().tween_method(_apply_yaw_progress.bind(rotation.y, hidden_yaw), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.finished.connect(_finish_hiding_entry)

## Reverses the configured route, then raises the camera and collider at the clear entry point.
func begin_unhiding() -> void:
	if _transitioning or not _hidden or _hide_config.is_empty():
		return
	var entry_position := _parent_to_global(_hide_config.entry)
	var route: Array[Vector3] = []
	for point in _hide_config.path:
		route.append(_parent_to_global(point))
	route.reverse()
	route.append(entry_position)
	if not _path_is_clear(global_transform, route):
		hiding_transition_finished.emit(false, false)
		return

	_transitioning = true
	_transition_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var previous_point := global_position
	for point in route:
		var duration := maxf(0.22, previous_point.distance_to(point) / 2.2)
		_transition_tween.tween_property(self, "global_position", point, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		previous_point = point
	_transition_tween.tween_callback(_finish_unhiding_at_entry)

func _finish_hiding_entry() -> void:
	_transitioning = false
	_hidden = true
	velocity = Vector3.ZERO
	_last_position = global_position
	hiding_transition_finished.emit(true, true)

func _finish_unhiding_at_entry() -> void:
	if not _has_standing_clearance():
		_transitioning = false
		hiding_transition_finished.emit(false, false)
		return
	_set_capsule_height(STANDING_HEIGHT)
	var exit_yaw: float = float(_hide_config.get("exit_yaw", rotation.y))
	_transition_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_transition_tween.tween_method(_apply_camera_height_progress.bind(_camera.position.y, STANDING_CAMERA_Y), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.parallel().tween_method(_apply_yaw_progress.bind(rotation.y, exit_yaw), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_callback(_finish_hiding_exit)

func _finish_hiding_exit() -> void:
	_transitioning = false
	_hidden = false
	velocity = Vector3.ZERO
	_last_position = global_position
	hiding_transition_finished.emit(false, true)

func cancel_hiding_transition() -> void:
	if not _transitioning:
		return
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	_transitioning = false
	if _hidden:
		_set_capsule_height(float(_hide_config.get("crouch_height", 0.95)))
		_apply_camera_height(float(_hide_config.get("crouch_camera_y", 0.78)))
	else:
		# Entry paths are prevalidated; restore the safe starting point if another
		# system interrupts before the player is fully concealed.
		global_position = _transition_start_position
		rotation.y = _transition_start_yaw
		_set_capsule_height(STANDING_HEIGHT)
		_apply_camera_height(STANDING_CAMERA_Y)
	velocity = Vector3.ZERO

func _path_is_clear(start: Transform3D, points: Array[Vector3]) -> bool:
	var probe := start
	# Preflight slightly above floor contact; actual movement stays floor-level.
	probe.origin.y += 0.01
	for point in points:
		var clear_point := point+Vector3.UP*0.01
		var offset := clear_point - probe.origin
		if offset.length() < 0.02:
			probe.origin = clear_point
			continue
		var steps := maxi(1, ceili(offset.length() / 0.12))
		var motion := offset / float(steps)
		for _step in steps:
			if test_move(probe, motion, null, 0.001, false):
				return false
			probe.origin += motion
	return true

func _has_standing_clearance() -> bool:
	var standing_shape := CapsuleShape3D.new()
	standing_shape.radius = _capsule_shape.radius
	standing_shape.height = STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STANDING_HEIGHT * 0.5 + 0.02, 0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.0
	return get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()

func _parent_to_global(point: Vector3) -> Vector3:
	var parent_3d := get_parent() as Node3D
	var result := parent_3d.to_global(point) if parent_3d else point
	# Keep tiny authored height differences from pushing the capsule into the floor.
	if absf(result.y - global_position.y) < 0.05:
		result.y = global_position.y
	return result

func _set_capsule_height(height: float) -> void:
	_capsule_shape.height = height
	_capsule_node.position.y = height * 0.5

func _apply_camera_height(height: float) -> void:
	_base_camera_position.y = height

func _apply_camera_height_progress(progress: float, start: float, target: float) -> void:
	_apply_camera_height(lerpf(start, target, clampf(progress, 0.0, 1.0)))

func _apply_yaw_progress(progress: float, start: float, target: float) -> void:
	rotation.y = lerp_angle(start, target, clampf(progress, 0.0, 1.0))

func _update_camera_bob(delta: float) -> void:
	if _opening_camera_animated:
		return
	var motion := clampf(camera_motion_intensity, 0.0, 1.0)
	_landing_offset = lerpf(_landing_offset, 0.0, 1.0 - exp(-18.0 * delta)) if motion > 0.0 else 0.0
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_strength := 0.0
	if not _hidden and not _transitioning:
		target_strength = clampf(horizontal_speed / RUN_SPEED, 0.0, 1.0)
	_bob_strength = move_toward(_bob_strength, target_strength, delta * 4.5)
	if _bob_strength > 0.001:
		var run_blend := clampf((horizontal_speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
		var frequency := lerpf(6.0, 9.0, run_blend)
		_bob_phase += delta * frequency
	var amplitude := lerpf(CAMERA_BOB_WALK, CAMERA_BOB_RUN, clampf(horizontal_speed / RUN_SPEED, 0.0, 1.0))
	var shove := _qte_shove_strength * motion
	_camera.position = _base_camera_position + Vector3(sin(_bob_phase * 0.5) * 0.004 * _bob_strength * motion - 0.045 * shove, sin(_bob_phase) * amplitude * _bob_strength * motion + _landing_offset + 0.035 * shove, 0.055 * shove)
	_camera.rotation.z = _base_camera_roll + sin(_bob_phase * 0.5) * CAMERA_ROLL_MAX * _bob_strength * motion - deg_to_rad(2.2) * shove
