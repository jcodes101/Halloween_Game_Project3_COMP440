extends Node
## Player-owned light, battery, and low-charge flicker state.

signal flashlight_switched_on
signal flashlight_switched_off
signal battery_level_changed(percent: float)
signal low_battery
signal battery_depleted

@export_range(1.0, 300.0, 1.0) var maximum_battery_percent := 100.0
@export_range(1.0, 100.0, 1.0) var starting_battery_percent := 100.0
@export_range(10.0, 600.0, 1.0) var full_battery_duration_seconds := 120.0
@export_range(1.0, 50.0, 1.0) var flicker_start_percent := 25.0
@export_range(1.0, 25.0, 1.0) var critical_flicker_percent := 10.0
@export_range(5.0, 60.0, 1.0) var beam_range := 18.0
@export_range(10.0, 80.0, 1.0) var beam_angle_degrees := 38.0
@export_range(0.1, 8.0, 0.1) var beam_energy := 2.4

var battery_percent := 100.0
var flashlight_is_on := false
var flicker_active := false
var _spotlight: SpotLight3D
var _rng := RandomNumberGenerator.new()
var _flicker_wait := 0.0
var _dark_wait := 0.0
var _flicker_dark := false
var _last_reported_percent := -1
var _low_battery_reported := false

func _ready() -> void:
	battery_percent = clampf(starting_battery_percent, 0.0, maximum_battery_percent)
	_rng.randomize()
	call_deferred("_attach_to_player_camera")
	_refresh_battery_state()

func _attach_to_player_camera() -> void:
	var player := get_parent()
	var camera := player.get_node_or_null("PlayerCamera") as Camera3D
	if camera == null:
		push_error("FlashlightController requires its player's PlayerCamera child.")
		return
	_spotlight = SpotLight3D.new()
	_spotlight.name = "FlashlightBeam"
	_spotlight.position = Vector3(0.08, -0.04, -0.06)
	_spotlight.light_color = Color(1.0, 0.94, 0.82)
	_spotlight.light_energy = beam_energy
	_spotlight.spot_range = beam_range
	_spotlight.spot_angle = beam_angle_degrees
	_spotlight.spot_angle_attenuation = 1.4
	_spotlight.shadow_enabled = true
	_spotlight.shadow_bias = 0.04
	_spotlight.visible = false
	camera.add_child(_spotlight)

func _process(delta: float) -> void:
	if flashlight_is_on:
		_set_battery(battery_percent - maximum_battery_percent * delta / full_battery_duration_seconds)
		if battery_percent <= 0.0:
			_set_flashlight_enabled(false)
			battery_depleted.emit()
			return
	_update_flicker(delta)

func toggle_flashlight() -> bool:
	return _set_flashlight_enabled(not flashlight_is_on)

func recharge_battery(amount: float) -> float:
	var previous := battery_percent
	_set_battery(minf(maximum_battery_percent, battery_percent + maxf(0.0, amount)))
	return battery_percent - previous

func _set_flashlight_enabled(enabled: bool) -> bool:
	if enabled and battery_percent <= 0.0:
		return false
	if flashlight_is_on == enabled:
		return true
	flashlight_is_on = enabled
	_flicker_dark = false
	_dark_wait = 0.0
	if enabled:
		_schedule_next_flicker()
		flashlight_switched_on.emit()
	else:
		flashlight_switched_off.emit()
	_update_light_visibility()
	return true

func _set_battery(value: float) -> void:
	battery_percent = clampf(value, 0.0, maximum_battery_percent)
	var whole_percent := roundi(battery_percent)
	if whole_percent != _last_reported_percent:
		_last_reported_percent = whole_percent
		battery_level_changed.emit(battery_percent)
	_refresh_battery_state()

func _refresh_battery_state() -> void:
	flicker_active = battery_percent <= flicker_start_percent and battery_percent > 0.0
	if flicker_active and not _low_battery_reported:
		_low_battery_reported = true
		low_battery.emit()
	if not flicker_active:
		_low_battery_reported = false
		_flicker_dark = false
	_update_light_visibility()
	if roundi(battery_percent) != _last_reported_percent:
		_last_reported_percent = roundi(battery_percent)
		battery_level_changed.emit(battery_percent)

func _update_flicker(delta: float) -> void:
	if not flashlight_is_on or not flicker_active:
		_flicker_dark = false
		_update_light_visibility()
		return
	if _flicker_dark:
		_dark_wait -= delta
		if _dark_wait <= 0.0:
			_flicker_dark = false
			_schedule_next_flicker()
	else:
		_flicker_wait -= delta
		if _flicker_wait <= 0.0:
			_flicker_dark = true
			var severity := _flicker_severity()
			_dark_wait = _rng.randf_range(lerpf(0.045, 0.07, severity), lerpf(0.085, 0.15, severity))
	_update_light_visibility()

func _schedule_next_flicker() -> void:
	var severity := _flicker_severity()
	_flicker_wait = _rng.randf_range(lerpf(1.2, 0.28, severity), lerpf(2.2, 0.82, severity))

func _flicker_severity() -> float:
	if battery_percent > critical_flicker_percent:
		return clampf(inverse_lerp(flicker_start_percent, critical_flicker_percent, battery_percent), 0.0, 1.0) * 0.6
	return lerpf(0.6, 1.0, clampf(inverse_lerp(critical_flicker_percent, 0.0, battery_percent), 0.0, 1.0))

func _update_light_visibility() -> void:
	if _spotlight != null:
		_spotlight.visible = flashlight_is_on and not _flicker_dark and battery_percent > 0.0
