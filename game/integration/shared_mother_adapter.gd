extends "res://systems/familiar/mother_visual_adapter.gd"
## Reuse the one visible mother's rig rather than instantiate a second model.
var actor: MonsterController

func _setup_mother_instance() -> void:
	bind_actor_visual()

func bind_actor_visual() -> void:
	mother_instance = actor.visual
	base_bone_poses.clear()
	_discover_rig_components()
