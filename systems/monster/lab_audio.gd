class_name MonsterLabAudio
extends Node3D
## Presentation adapter: reusable spatial effects, independent of game state.
const STEPS = [preload("res://assets/audio/footstep00.ogg"), preload("res://assets/audio/footstep01.ogg"), preload("res://assets/audio/footstep02.ogg"), preload("res://assets/audio/footstep03.ogg")]
const EFFECTS = {
	"door_open": preload("res://assets/audio/door_open.wav"),
	"door_close": preload("res://assets/audio/door_close.wav"),
	"locked_door": preload("res://assets/audio/locked_door.ogg"),
	"item_pickup": preload("res://assets/audio/item_pickup.ogg"),
}
var events: Dictionary = {}
var _positions: Dictionary = {}
var _distances: Dictionary = {}
var _step_index := 0

func footstep(actor: CharacterBody3D, tag: String, enabled: bool) -> void:
	var previous: Vector3 = _positions.get(tag, actor.global_position)
	_positions[tag] = actor.global_position
	var distance := Vector2(actor.global_position.x - previous.x, actor.global_position.z - previous.z).length()
	if not enabled or not actor.is_on_floor() or distance > 0.6:
		_distances[tag] = 0.0
		return
	_distances[tag] = float(_distances.get(tag, 0.0)) + distance
	if float(_distances[tag]) >= 1.0:
		_distances[tag] = 0.0
		_play(STEPS[_step_index % STEPS.size()], actor.global_position + Vector3.UP * 0.1, tag, -15.0 if tag == "player_step" else -7.0)
		_step_index += 1

func effect(event: String, location: Vector3) -> void:
	if EFFECTS.has(event):
		_play(EFFECTS[event], location, event, -12.0)

func _play(clip: AudioStream, location: Vector3, event: String, volume: float) -> void:
	var speaker := AudioStreamPlayer3D.new()
	speaker.stream = clip
	speaker.volume_db = volume
	speaker.unit_size = 3.0
	speaker.max_distance = 20.0
	add_child(speaker)
	speaker.global_position = location
	speaker.finished.connect(speaker.queue_free)
	speaker.play()
	events[event] = int(events.get(event, 0)) + 1

func reset_audio() -> void:
	for speaker in get_children():
		(speaker as AudioStreamPlayer3D).stop()
		speaker.queue_free()
	events.clear()
	_positions.clear()
	_distances.clear()
	_step_index = 0
