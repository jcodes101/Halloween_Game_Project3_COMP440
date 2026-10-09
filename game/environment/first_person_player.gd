extends CharacterBody3D

signal moved
signal interact_requested
signal escape_requested
signal hiding_transition_finished(entered: bool, succeeded: bool)

const WALK_SPEED := 4.2
const RUN_SPEED := 5.8
const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 18.0
const STANDING_HEIGHT := 1.8
const STANDING_CAMERA_Y := 1.55
const CAMERA_BOB_WALK := 0.012
const CAMERA_BOB_RUN := 0.021
const CAMERA_ROLL_MAX := 0.006

var _camera: Camera3D
var _capsule_node: CollisionShape3D
var _capsule_shape: CapsuleShape3D
var _hidden := false
var _transitioning := false
var _transition_tween: Tween
var _hide_config: Dictionary = {}
var _step_timer := 0.0
var _last_position := Vector3.ZERO
var _bob_phase := 0.0
var _bob_strength := 0.0
var _base_camera_position := Vector3(0, STANDING_CAMERA_Y, 0)
var _base_camera_roll := 0.0
var _transition_start_position := Vector3.ZERO
var _transition_start_yaw := 0.0

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
	_camera.position = _base_camera_position
	_camera.current = true
	_camera.fov = 78
	add_child(_camera)
	_last_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_update_camera_bob(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-82), deg_to_rad(82))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if _hidden:
				escape_requested.emit()
			else:
				interact_requested.emit()
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if _transitioning:
		velocity = Vector3.ZERO
		_last_position = global_position
		return

	var input_vector := Vector2.ZERO
	# Positive Y is forward here, so arrows and WASD share exactly the same mapping.
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): input_vector.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): input_vector.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): input_vector.y += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): input_vector.y -= 1.0
	input_vector = input_vector.limit_length()
	var direction := (transform.basis * Vector3(input_vector.x, 0, -input_vector.y)).normalized()
	var is_running := input_vector.length_squared() > 0.0 and Input.is_key_pressed(KEY_SHIFT) and not _hidden
	var movement_speed := RUN_SPEED if is_running else WALK_SPEED
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if global_position.distance_to(_last_position) > 0.018:
		_step_timer += delta
		if _step_timer >= 0.1:
			_step_timer = 0.0
			_last_position = global_position
			if Vector2(velocity.x, velocity.z).length() > 0.15:
				moved.emit()

func is_moving() -> bool:
	return Vector2(get_real_velocity().x, get_real_velocity().z).length() > 0.15

func is_transitioning() -> bool:
	return _transitioning

func set_hidden(value: bool) -> void:
	_hidden = value
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
	for point in points:
		var offset := point - probe.origin
		if offset.length() < 0.02:
			probe.origin = point
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
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STANDING_HEIGHT * 0.5, 0))
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
	_camera.position = _base_camera_position + Vector3(sin(_bob_phase * 0.5) * 0.004, sin(_bob_phase) * amplitude * _bob_strength, 0)
	_camera.rotation.z = _base_camera_roll + sin(_bob_phase * 0.5) * CAMERA_ROLL_MAX * _bob_strength
