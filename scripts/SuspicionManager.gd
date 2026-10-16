class_name SuspicionManager
extends Node
## Explicit inspection calls confirm_clue(); merely seeing something calls
## register_anomaly(). No scene, autoload, or teammate system is controlled here.

signal clue_discovered(clue_id: String)
signal anomaly_noticed(anomaly_id: String)
signal suspicion_changed(new_level: int)

enum SuspicionStage { UNAWARE, DOUBTFUL, CERTAIN }

@export_range(1, 100, 1) var doubtful_threshold: int = 1
@export_range(2, 100, 1) var certain_threshold: int = 3

var suspicion_level: int:
	get:
		return _level
var clues_found: int:
	get:
		return _evidence.size()
var noticed_anomaly: bool:
	get:
		return not _anomalies.is_empty()

var _level: int = SuspicionStage.UNAWARE
var _evidence: Dictionary = {}
var _anomalies: Dictionary = {}

func register_anomaly(anomaly_id: String) -> bool:
	if anomaly_id.strip_edges().is_empty() or _anomalies.has(anomaly_id):
		return false
	_anomalies[anomaly_id] = true
	anomaly_noticed.emit(anomaly_id)
	return true

func confirm_clue(clue_id: String, story_text: String = "") -> bool:
	if clue_id.strip_edges().is_empty() or _evidence.has(clue_id):
		return false
	_evidence[clue_id] = story_text
	refresh_suspicion()
	clue_discovered.emit(clue_id)
	return true

## Call after changing thresholds during play. Enforces ordered, positive bounds.
func refresh_suspicion() -> void:
	var doubtful: int = maxi(1, doubtful_threshold)
	var certain: int = maxi(doubtful + 1, certain_threshold)
	var next_level: int = SuspicionStage.UNAWARE
	if clues_found >= certain:
		next_level = SuspicionStage.CERTAIN
	elif clues_found >= doubtful:
		next_level = SuspicionStage.DOUBTFUL
	if next_level != _level:
		_level = next_level
		suspicion_changed.emit(_level)

func get_suspicion_level() -> int:
	return _level

## Optional adapter for Familiar's existing 0..100 interface (35/75 thresholds).
## A future coordinator can forward this value when suspicion_changed fires.
func get_suspicion_score() -> float:
	return [0.0, 50.0, 100.0][_level]

func has_clue(clue_id: String) -> bool:
	return _evidence.has(clue_id)

func get_collected_evidence() -> Dictionary:
	return _evidence.duplicate(true)

func get_noticed_anomalies() -> Array:
	return _anomalies.keys()

func reset() -> void:
	_evidence.clear()
	_anomalies.clear()
	refresh_suspicion()
