class_name InspectableClue
extends Node
## Attach as an interaction component later; inject manager/inventory references
## in the Inspector or via configure(). No input, UI, or scene changes are needed
## here. The player's deliberate interaction should call inspect() (or interact).
## Looking calls notice(); picking up calls collect(). Neither confirms evidence.

const Definitions = preload("res://scripts/ItemDefinitions.gd")
const Manager = preload("res://scripts/SuspicionManager.gd")
const Inventory = preload("res://scripts/ItemInventory.gd")

signal story_revealed(clue_id: String, story_text: String)

@export var clue_id: String = ""
@export var anomaly_id: String = ""
@export var item_id: String = ""
@export_multiline var story_text: String = ""
@export var suspicion_manager: Manager
@export var inventory: Inventory

## Configure a collectible from a catalog definition or a custom room key.
## Memorabilia must use their canonical ID for evidence across all instances.
var _definition: Dictionary = {}

func configure(definition: Dictionary, manager: Manager = null, bag: Inventory = null) -> void:
	_definition = definition.duplicate(true)
	item_id = str(definition.get("id", ""))
	clue_id = str(definition.get("clue_id", ""))
	story_text = str(definition.get("story_text", ""))
	suspicion_manager = manager
	inventory = bag

func notice() -> bool:
	if not is_instance_valid(suspicion_manager):
		return false
	var id: String = anomaly_id if not anomaly_id.is_empty() else _evidence_id()
	return suspicion_manager.register_anomaly(id)

func collect() -> bool:
	if not is_instance_valid(inventory) or item_id.is_empty():
		return false
	return inventory.collect_definition(_item_definition())

## Returns story information on every inspection; manager deduplicates globally.
## No local inspected flag: resetting the manager allows fresh evidence discovery.
func inspect() -> String:
	var definition: Dictionary = _item_definition()
	var story: String = story_text if not story_text.is_empty() else str(definition.get("story_text", ""))
	var evidence_id: String = _evidence_id()
	# Unknown collectible definitions and ordinary tools/keys are not evidence.
	var is_evidence: bool = item_id.is_empty() or bool(definition.get("requires_inspection", false))
	if is_evidence and not evidence_id.strip_edges().is_empty():
		if is_instance_valid(suspicion_manager):
			suspicion_manager.confirm_clue(evidence_id, story)
		story_revealed.emit(evidence_id, story)
	return story

## Deliberate use may collect and inspect; collection without inspection remains
## available separately. Player context is accepted without controlling it.
func interact(_player: Node = null) -> String:
	collect()
	return inspect()

func _item_definition() -> Dictionary:
	if not _definition.is_empty() and str(_definition.get("id", "")) == item_id:
		return _definition.duplicate(true)
	return Definitions.get_definition(item_id)

func _evidence_id() -> String:
	var definition: Dictionary = _item_definition()
	if not item_id.is_empty():
		return str(definition.get("clue_id", ""))
	return clue_id
