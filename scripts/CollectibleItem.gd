class_name CollectibleItem
extends Node3D
## Future item scenes may use this as their root or a spatial child component.
## Collection does not hide/free objects, unlock doors, or affect suspicion.

const Definitions = preload("res://scripts/ItemDefinitions.gd")
const Inventory = preload("res://scripts/ItemInventory.gd")

signal collected(item_id: String)

@export_enum("basement_key", "crowbar", "room_key") var item_type: String = "basement_key"
@export var room_id: String = ""
@export var display_name: String = ""
@export var inventory: Inventory
@export var interactable_group: StringName = &"observation_interactables"

func _ready() -> void:
	add_to_group(interactable_group)

func get_definition() -> Dictionary:
	if item_type == "room_key":
		return Definitions.create_room_key(room_id, display_name)
	if item_type != Definitions.BASEMENT_KEY and item_type != Definitions.CROWBAR:
		return {}
	return Definitions.get_definition(item_type)

func can_interact() -> bool:
	var definition: Dictionary = get_definition()
	return is_instance_valid(inventory) and not definition.is_empty() and not inventory.has_item(str(definition["id"]))

func collect() -> bool:
	if not is_instance_valid(inventory):
		return false
	var definition: Dictionary = get_definition()
	if not inventory.collect_definition(definition):
		return false
	collected.emit(str(definition["id"]))
	return true

func interact(_player: Node = null) -> bool:
	return collect()

func get_interaction_position() -> Vector3:
	return global_position
