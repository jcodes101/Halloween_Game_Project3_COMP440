class_name FamiliarVisualAdapter
extends Node3D
## Base interface / adapter for Familiar character visuals.
## Decouples behavior logic from specific meshes, rigs, or animation players.
## Implementations (e.g. PlaceholderVisualAdapter or MotherVisualAdapter) map
## these commands to their specific meshes, materials, and animation systems.

## Applies the visual treatment for a given behavior stage (e.g. Normal, Doubtful, Certain).
func apply_stage(_stage: int) -> void:
	pass

## Plays or transitions into a named action pose/animation (e.g. "cooking", "cleaning", "greet", "staring").
func play_action(_action_name: String) -> void:
	pass

## Toggles disturbed visual effects (stiff posture, unnatural micro-twitches, jitter).
func set_disturbed_state(_is_disturbed: bool, _intensity: float = 1.0) -> void:
	pass

## Smoothly rotates the head/body to look toward a target position in world space.
func look_toward(_target_global_position: Vector3, _delta: float, _turn_speed: float) -> void:
	pass

## Instantly snaps the orientation toward the target position.
func snap_look_at(_target_global_position: Vector3) -> void:
	pass

## Sets movement velocity cues (for walking/locomotion animation blending).
func set_movement_velocity(_velocity: Vector3, _delta: float) -> void:
	pass

## Resets visual state to default resting posture.
func reset_visuals() -> void:
	pass
