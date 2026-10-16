extends "res://systems/familiar/familiar_controller.gd"
## Familiar schedules routines; the shared monster body executes navigation.
var actor: MonsterController
var patrol_sequence: Array[int] = []
var _patrol_cursor := 0

func _next_station_index(station_count: int) -> int:
	if patrol_sequence.is_empty():
		return super(station_count)
	var index := patrol_sequence[_patrol_cursor % patrol_sequence.size()]
	_patrol_cursor += 1
	return clampi(index,0,station_count-1)

func _physics_process(delta: float) -> void:
	if is_monster_controlled:
		return
	# The actor's threat tick is disabled during routines, so its path refresh
	# timer must advance here or the second station can never become a target.
	actor._path_refresh_timer = maxf(0.0,actor._path_refresh_timer-delta)
	super(delta)
	if Vector2(velocity.x, velocity.z).length() < 0.01:
		actor._stop(delta)

func _navigate_to_waypoint(delta: float, speed: float) -> void:
	if target_waypoint.distance_to(actor.global_position) <= 0.65:
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
