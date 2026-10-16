class_name MemorabiliaInteraction
extends "res://scripts/InspectableClue.gd"
## Uses inherited item_id, story_text, suspicion_manager, inventory, configure(),
## collect(), notice(), and story_revealed(clue_id, story_text). Set item_id to one
## of ItemDefinitions.get_memorabilia_ids(). Empty story_text uses catalog text.
## Add beneath a Node3D item root; no visuals or story UI are created here.

@export var interaction_anchor: Node3D
@export var interactable_group: StringName = &"observation_interactables"

func _ready() -> void:
	add_to_group(interactable_group)

func is_valid_memorabilia() -> bool:
	return Definitions.get_memorabilia_ids().has(item_id)

func can_interact() -> bool:
	return is_valid_memorabilia() and is_instance_valid(suspicion_manager)

func notice() -> bool:
	return super.notice() if is_valid_memorabilia() else false

func collect() -> bool:
	return super.collect() if is_valid_memorabilia() else false

func inspect() -> String:
	if not is_valid_memorabilia():
		return ""
	return super.inspect()

func interact(_player: Node = null) -> String:
	if not can_interact():
		return ""
	collect()
	return inspect()

## Canonical catalog metadata prevents custom definitions from changing clue IDs.
## Story overrides remain supported through inherited story_text/configure().
func _item_definition() -> Dictionary:
	return Definitions.get_definition(item_id) if is_valid_memorabilia() else {}

func get_interaction_position() -> Vector3:
	if is_instance_valid(interaction_anchor):
		return interaction_anchor.global_position
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Node3D:
			return (ancestor as Node3D).global_position
		ancestor = ancestor.get_parent()
	return Vector3(INF, INF, INF)
