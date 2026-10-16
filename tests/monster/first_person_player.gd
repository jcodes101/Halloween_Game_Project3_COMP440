class_name MonsterTestPlayer
extends CharacterBody3D
## First-person controller for the isolated behavior lab only.
signal interact_requested
@export var walk_speed := 3.5
@export var sprint_speed := 5.0
@export var mouse_sensitivity := 0.0025
@export var eye_height := 1.05
@export var starting_look_up_degrees := 10.0
var movement_enabled := true
var hide_locked := false
var camera: Camera3D
var move_intent := Vector2.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 13
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = eye_height
	camera.rotation.x = deg_to_rad(starting_look_up_degrees)
	camera.fov = 75
	camera.near = 0.05
	add_child(camera)
	camera.current = true

func _input(event: InputEvent) -> void:
	if not movement_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-85), deg_to_rad(85))
	if event.is_action_pressed("monster_test_interact"):
		interact_requested.emit()

func _physics_process(delta: float) -> void:
	move_intent = Input.get_vector("monster_test_left", "monster_test_right", "monster_test_forward", "monster_test_back") if movement_enabled else Vector2.ZERO
	var direction := (basis * Vector3(move_intent.x, 0, move_intent.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("monster_test_sprint") else walk_speed
	velocity.x = direction.x * speed if movement_enabled and not hide_locked else 0.0
	velocity.z = direction.z * speed if movement_enabled and not hide_locked else 0.0
	velocity.y = -0.5 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()

func is_still() -> bool:
	return move_intent.length() < 0.01 and Vector2(velocity.x, velocity.z).length() < 0.05

func reset_player(position: Vector3) -> void:
	global_position = position
	rotation = Vector3.ZERO
	camera.rotation = Vector3(deg_to_rad(starting_look_up_degrees), 0, 0)
	velocity = Vector3.ZERO
	move_intent = Vector2.ZERO
	hide_locked = false
	movement_enabled = true
	camera.current = true
