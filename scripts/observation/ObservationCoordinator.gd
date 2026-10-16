extends Node
## Scene-local ownership. No autoload, input, actor, environment or UI mutation.
const Manager = preload("res://scripts/SuspicionManager.gd")
const Inventory = preload("res://scripts/ItemInventory.gd")
const Adapter = preload("res://scripts/observation/ObservationAdapter.gd")
const Clue = preload("res://scripts/InspectableClue.gd")
const Collectible = preload("res://scripts/CollectibleItem.gd")

signal story_revealed(clue_id: String, story_text: String)
signal session_reset

var manager := Manager.new()
var inventory := Inventory.new()
var observation := Adapter.new()

func _init() -> void:
	manager.name = "SuspicionManager"
	inventory.name = "ItemInventory"
	observation.name = "ObservationAdapter"
	add_child(manager)
	add_child(inventory)
	add_child(observation)
	observation.configure(manager)

func bind_item(item: Node) -> bool:
	if item is Clue:
		item.suspicion_manager = manager
		item.inventory = inventory
		if not item.story_revealed.is_connected(_relay_story):
			item.story_revealed.connect(_relay_story)
		return true
	if item is Collectible:
		item.inventory = inventory
		return true
	return false

## Reset this local session. An externally bound detection source remains owned
## by its caller; reset does not reset its alertness or overwrite its state.
func reset_session(reset_alertness: bool = false) -> void:
	manager.reset()
	inventory.reset()
	observation.refresh_evidence()
	if reset_alertness:
		observation.set_test_suspicion(0.0)
	session_reset.emit()

func _relay_story(id: String, story: String) -> void:
	story_revealed.emit(id, story)
