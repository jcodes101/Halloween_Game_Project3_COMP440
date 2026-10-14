class_name TestFirstPersonPlayer
extends CharacterBody3D
## Self-contained first-person test player for Familiar Behavior lab scenes.
## Uses raw keycodes so it requires zero project.godot input mapping changes.
## Allows walking up to the mother character to experience behavioral stages up close.

@export var move_speed: float = 3.5
@export var mouse_sensitivity: float = 0.0025
@export var camera: Camera3D

var camera_pitch: float = 0.0
var mouse_captured: bool = false
var is_active_camera: bool = true

func _ready() -> void:
	if not camera:
		camera = find_child("FirstPersonCamera", true, false) as Camera3D

func capture_mouse() -> void:
	if is_active_camera:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

func set_active(active: bool) -> void:
	is_active_camera = active
	if camera:
		camera.current = active
	if not active:
		release_mouse()
		velocity = Vector3.ZERO
	else:
		capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active_camera:
		return
	
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE:
			release_mouse()
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		if not mouse_captured and is_active_camera:
			capture_mouse()
	
	if mouse_captured and event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		# Yaw on player body
		rotate_y(-mouse_event.relative.x * mouse_sensitivity)
		# Pitch on camera
		if camera:
			camera_pitch = clampf(camera_pitch - mouse_event.relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
			camera.rotation.x = camera_pitch

func _physics_process(delta: float) -> void:
	if not is_active_camera:
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	
	# WASD Movement
	var input_dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		var wish_dir: Vector3 = (transform.basis * input_dir).normalized()
		velocity.x = wish_dir.x * move_speed
		velocity.z = wish_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 10.0 * delta)
	
	move_and_slide()
