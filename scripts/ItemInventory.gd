class_name ItemInventory
extends Node
## Stores unique items only; never calls SuspicionManager. Room keys are supplied
## through ItemDefinitions.create_room_key(). Getters return defensive copies.

const Definitions = preload("res://scripts/ItemDefinitions.gd")

signal item_collected(item_id: String)
signal inventory_reset()

var _items: Dictionary = {}

func collect_item(item_id: String) -> bool:
	return collect_definition(Definitions.get_definition(item_id))

func collect_definition(definition: Dictionary) -> bool:
	var id: String = str(definition.get("id", ""))
	if id.strip_edges().is_empty() or _items.has(id):
		return false
	_items[id] = definition.duplicate(true)
	item_collected.emit(id)
	return true

func has_item(item_id: String) -> bool:
	return _items.has(item_id)

func has_basement_key() -> bool:
	return has_item(Definitions.BASEMENT_KEY)

func has_crowbar() -> bool:
	return has_item(Definitions.CROWBAR)

func has_room_key(room_id: String) -> bool:
	return has_item("room_key:" + room_id)

func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {}).duplicate(true)

func get_items() -> Dictionary:
	return _items.duplicate(true)

func reset() -> void:
	_items.clear()
	inventory_reset.emit()
