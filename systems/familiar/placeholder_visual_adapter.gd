class_name PlaceholderVisualAdapter
extends "res://systems/familiar/familiar_visual_adapter.gd"

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")
const PlaceholderHumanoidScript = preload("res://systems/familiar/placeholder_humanoid.gd")
## Visual adapter implementation for the temporary low-poly placeholder humanoid.
## Implements FamiliarVisualAdapter interface to decouple FamiliarController.

@export var humanoid_node: Node3D

func _ready() -> void:
	if not humanoid_node:
		# Auto-discover child if not explicitly assigned
		humanoid_node = get_node_or_null("PlaceholderHumanoid")
		if not humanoid_node:
			var found := find_children("*", "PlaceholderHumanoid", true, false)
			if not found.is_empty():
				humanoid_node = found[0] as Node3D

func apply_stage(stage: int) -> void:
	if humanoid_node:
		humanoid_node.apply_stage_visuals(stage)

func play_action(action_name: String) -> void:
	if humanoid_node:
		humanoid_node.set_current_action(action_name)

func set_disturbed_state(is_disturbed: bool, intensity: float = 1.0) -> void:
	if humanoid_node:
		humanoid_node.is_disturbed = is_disturbed
		humanoid_node.disturbance_intensity = intensity

func look_toward(target_global_position: Vector3, _delta: float, _turn_speed: float) -> void:
	if humanoid_node:
		humanoid_node.set_look_target(target_global_position)

func snap_look_at(target_global_position: Vector3) -> void:
	if humanoid_node:
		humanoid_node.set_look_target(target_global_position)

func set_movement_velocity(velocity: Vector3, _delta: float) -> void:
	# If walking, animate leg swing or subtle bobbing
	if humanoid_node and velocity.length_squared() > 0.01:
		if humanoid_node.current_action == FamiliarConstants.ACTION_IDLE:
			humanoid_node.hips.rotation.y = sin(humanoid_node.anim_time * 8.0) * deg_to_rad(3.0)
	elif humanoid_node and humanoid_node.current_action == FamiliarConstants.ACTION_IDLE:
		humanoid_node.hips.rotation.y = 0.0

func reset_visuals() -> void:
	if humanoid_node:
		humanoid_node.clear_look_target()
		humanoid_node.set_current_action(FamiliarConstants.ACTION_IDLE)
