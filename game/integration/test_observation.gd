extends Node
## Temporary approved input adapter until the team's Observation system exists.
signal suspicion_changed(level: float)
var suspicion_level := 0.0

func set_test_suspicion(level: float) -> void:
	suspicion_level = clampf(level, 0, 100)
	suspicion_changed.emit(suspicion_level)
