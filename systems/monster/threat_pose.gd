extends SkeletonModifier3D
## Temporary bone offsets applied after the existing animation by Skeleton3D.
var actor: MonsterController
var elapsed := 0.0
var blend := 0.0

func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.is_physics_processing():
		blend = 0.0
		return
	var rig := get_skeleton()
	if rig == null:
		return
	elapsed += delta
	blend = move_toward(blend, 1.0, delta * 4.0)
	var searching := actor.monster_state == MonsterController.State.SEARCHING
	var stalking := actor.monster_state == MonsterController.State.STALKING
	var grabbing := actor.encounter_pending or actor.monster_state == MonsterController.State.CAPTURED
	var chasing := actor.monster_state == MonsterController.State.PURSUING
	var yaw := sin(elapsed * 0.85) * 16.0 if searching else 0.0
	_offset(rig, "Head_021", Vector3(0, yaw, 5.0 if stalking else 0.0))
	_offset(rig, "Spine_011", Vector3(-5.0 if chasing else 0.0, 0, 0))
	if grabbing:
		_offset(rig, "LeftArm_013", Vector3(-35, 0, -15))
		_offset(rig, "RightArm_017", Vector3(-35, 0, 15))
		_offset(rig, "LeftForeArm_014", Vector3(-20, 0, 0))
		_offset(rig, "RightForeArm_018", Vector3(-20, 0, 0))

func _offset(rig: Skeleton3D, bone_name: String, degrees: Vector3) -> void:
	var index := rig.find_bone(bone_name)
	if index < 0:
		return
	var angles := degrees * (PI / 180.0) * blend
	rig.set_bone_pose_rotation(index, rig.get_bone_pose_rotation(index) * Quaternion.from_euler(angles))
