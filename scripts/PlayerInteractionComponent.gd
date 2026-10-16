class_name PlayerInteractionComponent
extends Node
## Call interact() from a future input handler. No input actions are installed.
## Proximity selection has no aiming or obstruction test; range uses world units.
## Origin defaults to the nearest Node3D ancestor, or can be assigned explicitly.

signal target_changed(target: Node)
signal interaction_performed(target: Node, result: Variant)

@export_range(0.1, 20.0, 0.1) var interaction_distance: float = 2.5
@export var interaction_origin: Node3D
@export var player: Node
@export var interactable_group: StringName = &"observation_interactables"

var _target: Node

func _physics_process(_delta: float) -> void:
	refresh_target()

func get_nearby_interactables() -> Array[Node]:
	var result: Array[Node] = []
	var origin: Node3D = _origin()
	if not is_inside_tree() or not is_instance_valid(origin):
		return result
	for candidate: Node in get_tree().get_nodes_in_group(interactable_group):
		if not candidate.has_method("interact") or not candidate.has_method("get_interaction_position"):
			continue
		if candidate.has_method("can_interact") and not candidate.call("can_interact"):
			continue
		var position: Variant = candidate.call("get_interaction_position")
		if position is Vector3 and origin.global_position.distance_to(position) <= maxf(0.0, interaction_distance):
			result.append(candidate)
	return result

func refresh_target() -> Node:
	var next_target: Node = null
	var closest: float = INF
	var origin: Node3D = _origin()
	for candidate: Node in get_nearby_interactables():
		var distance: float = origin.global_position.distance_to(candidate.call("get_interaction_position"))
		if distance < closest:
			closest = distance
			next_target = candidate
	if next_target != _target:
		_target = next_target
		target_changed.emit(_target)
	return _target

## Rechecks range and availability at the instant of deliberate interaction.
func interact() -> Variant:
	var target: Node = refresh_target()
	if not is_instance_valid(target):
		return null
	var context: Node = player if is_instance_valid(player) else _origin()
	var result: Variant = target.call("interact", context)
	interaction_performed.emit(target, result)
	refresh_target()
	return result

func _origin() -> Node3D:
	if is_instance_valid(interaction_origin):
		return interaction_origin
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Node3D:
			return ancestor as Node3D
		ancestor = ancestor.get_parent()
	return null
