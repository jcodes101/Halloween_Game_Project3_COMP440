extends Node
## Lightweight full-screen VHS composite whose strength follows the existing monster.

const MonsterController = preload("res://systems/monster/monster_controller.gd")
const VHS_SHADER = preload("res://game/integration/vhs_screen_effect.gdshader")

@export_group("Monster Distance")
@export_range(5.0, 60.0, 0.5) var far_distance := 18.0
@export_range(4.0, 40.0, 0.5) var mid_distance := 10.0
@export_range(1.0, 20.0, 0.5) var close_distance := 4.0

@export_group("VHS Intensity")
@export_range(0.0, 0.3, 0.01) var baseline_intensity := 0.08
@export_range(0.2, 1.0, 0.01) var maximum_intensity := 0.82
@export_range(0.2, 8.0, 0.1) var response_speed := 2.8

var player: Node3D
var monster: Node3D
var current_intensity := 0.08
var user_intensity_scale := 1.0
var _material: ShaderMaterial

func _ready() -> void:
	current_intensity = baseline_intensity
	var canvas := CanvasLayer.new()
	canvas.name = "VHSOverlayLayer"
	canvas.layer = -1 # Composite over the 3D world but below the readable game HUD.
	add_child(canvas)
	var overlay := ColorRect.new()
	overlay.name = "VHSOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = VHS_SHADER
	_material.set_shader_parameter("intensity", current_intensity)
	overlay.material = _material
	canvas.add_child(overlay)
	get_viewport().size_changed.connect(_update_shader_size)
	_update_shader_size()

func _process(delta: float) -> void:
	var target := _target_intensity()
	var blend := 1.0 - exp(-response_speed * delta)
	current_intensity = lerpf(current_intensity, target, blend)
	if _material != null:
		_material.set_shader_parameter("intensity", current_intensity * user_intensity_scale)

func _target_intensity() -> float:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return baseline_intensity
	if not is_instance_valid(monster) or not monster.is_inside_tree() or monster.is_queued_for_deletion():
		return baseline_intensity
	if int(monster.get("monster_state")) == MonsterController.State.CAPTURED:
		return baseline_intensity
	return intensity_for_distance(player.global_position.distance_to(monster.global_position))

func intensity_for_distance(distance: float) -> float:
	var far := maxf(far_distance, mid_distance + 0.1)
	var middle := maxf(mid_distance, close_distance + 0.1)
	var close := maxf(0.0, close_distance)
	if distance >= far:
		return baseline_intensity
	var middle_intensity := lerpf(baseline_intensity, maximum_intensity, 0.55)
	if distance > middle:
		var progress := _smooth_progress(inverse_lerp(far, middle, distance))
		return lerpf(baseline_intensity, middle_intensity, progress)
	if distance > close:
		var progress := _smooth_progress(inverse_lerp(middle, close, distance))
		return lerpf(middle_intensity, maximum_intensity, progress)
	return maximum_intensity

func _smooth_progress(value: float) -> float:
	var amount := clampf(value, 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)

func _update_shader_size() -> void:
	if _material != null:
		_material.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
