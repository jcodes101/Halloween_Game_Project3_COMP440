extends "res://game/integration/main_game.gd"
## Production evidence bridge. The original game remains the owner of gameplay.
const CoordinatorScene = preload("res://scripts/observation/scenes/observation_system.tscn")
const InventoryBridge = preload("res://scripts/observation/house/EnvironmentInventoryAdapter.gd")
const JournalScene = preload("res://scripts/observation/house/story_panel.tscn")

var observation_coordinator: Node
var inventory_bridge: Node
var story_panel: CanvasLayer

func threat_progression_score() -> float:
	if not is_instance_valid(observation_coordinator):
		return 0.0
	return observation_coordinator.observation.evidence_score

func _build_actors() -> void:
	super()
	observation_coordinator = CoordinatorScene.instantiate()
	add_child(observation_coordinator)
	# The original detection source continues to serve the original monster API.
	observation_coordinator.observation.bind_alertness_source(observation)

func _connect_game() -> void:
	super()
	# Replace only the preview's signal route, not either controller's behavior.
	observation.suspicion_changed.disconnect(familiar.set_suspicion_level)
	observation_coordinator.observation.evidence_changed.connect(_apply_evidence)
	familiar.monster_handoff_ended.connect(_restore_evidence)
	_restore_evidence()

func _build_hud() -> void:
	super()
	environment.configure_observation(observation_coordinator, self)
	inventory_bridge = InventoryBridge.new()
	add_child(inventory_bridge)
	inventory_bridge.setup(environment, observation_coordinator.inventory)
	story_panel = JournalScene.instantiate()
	add_child(story_panel)
	story_panel.setup(observation_coordinator, self)

func _apply_evidence(_stage: int, score: float, _clues: int) -> void:
	# Snapshot signals may repeat; avoid restarting a familiar stage on rereads.
	if not is_equal_approx(familiar.suspicion_level, score):
		familiar.set_suspicion_level(score)

func _restore_evidence() -> void:
	# Some visual adapters reset familiar state while reclaiming the shared body.
	familiar.set_suspicion_level(observation_coordinator.observation.evidence_score)
