extends Node
## Escape state is authoritative. Inventory is a one-way, deduplicated mirror.
const Definitions = preload("res://scripts/ItemDefinitions.gd")
var _environment: Node
var _inventory: Node

func setup(environment: Node, inventory: Node) -> void:
	if is_instance_valid(_environment):
		_environment.environment_state_changed.disconnect(_sync_escape_items)
	_environment = environment
	_inventory = inventory
	_environment.environment_state_changed.connect(_sync_escape_items)
	_sync_escape_items()

func _sync_escape_items() -> void:
	if _environment.has_crowbar:
		_inventory.collect_item(Definitions.CROWBAR)
	if _environment.has_window_key:
		_inventory.collect_definition(Definitions.create_room_key("attic_window", "Mother's Window Key"))
