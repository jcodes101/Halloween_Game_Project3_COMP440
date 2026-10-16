extends "res://systems/familiar/familiar_controller.gd"
## Familiar schedules routines; the shared monster body executes navigation.
var actor: MonsterController

func _physics_process(delta: float) -> void:
	if is_monster_controlled:
		return
	super(delta)
	if Vector2(velocity.x, velocity.z).length() < 0.01:
		actor._stop(delta)

func _navigate_to_waypoint(delta: float, speed: float) -> void:
	if Vector2(target_waypoint.x - actor.global_position.x, target_waypoint.z - actor.global_position.z).length() <= 0.45:
		is_moving_to_station = false
		velocity = Vector3.ZERO
		_resume_current_station_action()
	else:
		actor._walk_to(target_waypoint, speed, delta)
		velocity = actor.velocity

func _rotate_toward_point(point: Vector3, delta: float, speed: float) -> void:
	actor._face(point, delta)
	if visual_adapter:
		visual_adapter.look_toward(point, delta, speed)
