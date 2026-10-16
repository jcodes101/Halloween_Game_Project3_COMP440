extends Node
## Compatibility with test_observation.gd: suspicion_level and suspicion_changed
## represent TEMPORARY alertness only. Evidence has its own read-only channel.
signal suspicion_changed(level: float)
signal evidence_changed(stage: int, score: float, clues: int)

var suspicion_level: float:
	get:
		return _alertness
var temporary_alertness: float:
	get:
		return _alertness
var evidence_stage: int:
	get:
		return _evidence_stage
var evidence_score: float:
	get:
		return _evidence_score

var _alertness := 0.0
var _evidence_stage := 0
var _evidence_score := 0.0
var _manager: Node
var _source: Node

func configure(manager: Node, source: Node = null) -> void:
	if is_instance_valid(_manager):
		_manager.clue_discovered.disconnect(_on_clue)
		_manager.suspicion_changed.disconnect(_on_stage)
	_manager = manager
	_manager.clue_discovered.connect(_on_clue)
	_manager.suspicion_changed.connect(_on_stage)
	bind_alertness_source(source)
	refresh_evidence()

## Optional one-way mirror of an existing detection adapter. Never writes to it.
func bind_alertness_source(source: Node) -> void:
	if is_instance_valid(_source):
		_source.disconnect("suspicion_changed", set_test_suspicion)
	_source = null
	if is_instance_valid(source) and source != self:
		if source.has_signal("suspicion_changed") and source.get("suspicion_level") != null:
			_source = source
			_source.connect("suspicion_changed", set_test_suspicion)
			set_test_suspicion(float(_source.get("suspicion_level")))

func set_test_suspicion(level: float) -> void:
	if not is_finite(level):
		return
	_alertness = clampf(level, 0.0, 100.0)
	suspicion_changed.emit(_alertness)

func refresh_evidence() -> void:
	_evidence_stage = _manager.get_suspicion_level()
	_evidence_score = _manager.get_suspicion_score()
	evidence_changed.emit(_evidence_stage, _evidence_score, _manager.clues_found)

func _on_clue(_id: String) -> void:
	refresh_evidence()

func _on_stage(_stage: int) -> void:
	refresh_evidence()
