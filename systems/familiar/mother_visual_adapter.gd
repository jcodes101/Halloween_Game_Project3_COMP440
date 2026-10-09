class_name MotherVisualAdapter
extends "res://systems/familiar/familiar_visual_adapter.gd"
## Visual adapter integrating the actual mother character scene (MotherVisual.tscn / GLBs).
## Drives Skeleton3D procedural bone posing for Familiar behavior stages (head tilt, staring,
## micro-twitches, household chore arms, and multi-step Certain contortion sequence).
## Aligns imported asset orientation so forward locomotion matches Godot CharacterBody3D.
## Provides a clean handoff mechanism for K'von's Monster System during pursuit/stalking.

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")

signal monster_handoff_started
signal monster_handoff_ended

@export var mother_scene: PackedScene
@export var enable_procedural_bones: bool = true

# Node references
var mother_instance: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer

# State tracking
var current_stage: int = FamiliarConstants.BehaviorStage.NORMAL
var current_action: String = FamiliarConstants.ACTION_IDLE
var is_disturbed: bool = false
var disturbance_intensity: float = 0.0
var is_monster_controlled: bool = false
var is_moving: bool = false

# Procedural animation parameters
var anim_time: float = 0.0
var twitch_timer: float = 0.0
var twitch_impulse: float = 0.0
var target_look_point: Vector3 = Vector3.ZERO
var has_look_target: bool = false
var current_look_yaw: float = 0.0
var current_look_pitch: float = 0.0

# Certain stage recurring sequence state
var certain_phase: int = FamiliarConstants.CertainPhase.EYE_CONTACT
var certain_phase_timer: float = 0.0
var certain_cycle_count: int = 0

# Verified 25-bone rig bone indices (cached safely at runtime)
var bone_indices: Dictionary = {
	"root": -1,
	"hips": -1,
	"spine_lower": -1,
	"spine_mid": -1,
	"spine_upper": -1,
	"neck": -1,
	"head": -1,
	"shoulder_l": -1,
	"arm_l": -1,
	"forearm_l": -1,
	"hand_l": -1,
	"shoulder_r": -1,
	"arm_r": -1,
	"forearm_r": -1,
	"hand_r": -1
}

# Original cached bone rest/pose rotations to prevent permanent resource mutations
var base_bone_poses: Dictionary = {}

func _ready() -> void:
	_setup_mother_instance()

func _setup_mother_instance() -> void:
	if not mother_scene:
		var scene_path: String = "res://assets/monster/MotherVisual.tscn"
		if ResourceLoader.exists(scene_path):
			mother_scene = load(scene_path) as PackedScene
	
	if mother_scene:
		mother_instance = mother_scene.instantiate() as Node3D
		# Fix forward orientation: Imported asset mesh faces +Z in local space.
		# Godot CharacterBody3D and standard navigation move forward along -Z.
		# Rotating the visual node by PI perfectly aligns the mother's forward facing
		# with the character controller movement direction, eliminating backward movement.
		mother_instance.rotation.y = PI
		add_child(mother_instance)
		_discover_rig_components()

func _discover_rig_components() -> void:
	if not mother_instance:
		return
	
	# Ensure child scene has executed its _ready initialization
	if mother_instance.get_child_count() == 0:
		mother_instance.notification(Node.NOTIFICATION_READY)
	
	# Find AnimationPlayer
	var players := mother_instance.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0] as AnimationPlayer
	
	# Find Skeleton3D
	var skeletons := mother_instance.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeleton = skeletons[0] as Skeleton3D
		_cache_skeleton_bones()

func _cache_skeleton_bones() -> void:
	if not skeleton:
		return
	
	# Verify and store bone indices without assuming names blindly
	bone_indices["root"] = skeleton.find_bone("_rootJoint")
	bone_indices["hips"] = skeleton.find_bone("Hips_00")
	bone_indices["spine_lower"] = skeleton.find_bone("Spine02_09")
	bone_indices["spine_mid"] = skeleton.find_bone("Spine01_010")
	bone_indices["spine_upper"] = skeleton.find_bone("Spine_011")
	bone_indices["neck"] = skeleton.find_bone("neck_020")
	bone_indices["head"] = skeleton.find_bone("Head_021")
	bone_indices["shoulder_l"] = skeleton.find_bone("LeftShoulder_012")
	bone_indices["arm_l"] = skeleton.find_bone("LeftArm_013")
	bone_indices["forearm_l"] = skeleton.find_bone("LeftForeArm_014")
	bone_indices["hand_l"] = skeleton.find_bone("LeftHand_015")
	bone_indices["shoulder_r"] = skeleton.find_bone("RightShoulder_016")
	bone_indices["arm_r"] = skeleton.find_bone("RightArm_017")
	bone_indices["forearm_r"] = skeleton.find_bone("RightForeArm_018")
	bone_indices["hand_r"] = skeleton.find_bone("RightHand_019")
	
	# Cache original poses for all bones
	base_bone_poses.clear()
	for b in range(skeleton.get_bone_count()):
		base_bone_poses[b] = skeleton.get_bone_pose_rotation(b)

func _process(delta: float) -> void:
	# Deferred check for skeleton if loaded dynamically by child
	if not skeleton and mother_instance:
		_discover_rig_components()
	
	if is_monster_controlled or not enable_procedural_bones or not skeleton:
		return
	
	anim_time += delta
	_update_twitch(delta)
	
	if current_stage == FamiliarConstants.BehaviorStage.CERTAIN:
		_update_certain_sequence(delta)
	else:
		_update_procedural_skeletal_pose(delta)

# ==============================================================================
# Familiar Visual Adapter Interface Implementation
# ==============================================================================

func apply_stage(stage: int) -> void:
	current_stage = stage
	
	# Forward appearance string to teammate's mesh exporter if supported
	var stage_appearance: String = "Ordinary"
	match stage:
		FamiliarConstants.BehaviorStage.NORMAL:
			stage_appearance = "Ordinary"
			is_disturbed = false
			disturbance_intensity = 0.0
		FamiliarConstants.BehaviorStage.DOUBTFUL:
			stage_appearance = "Doubtful"
			is_disturbed = true
			disturbance_intensity = 0.4
		FamiliarConstants.BehaviorStage.CERTAIN:
			stage_appearance = "Uncanny"
			is_disturbed = true
			disturbance_intensity = 1.0
			certain_phase = FamiliarConstants.CertainPhase.EYE_CONTACT
			certain_phase_timer = 0.0
	
	if mother_instance and "appearance" in mother_instance:
		mother_instance.set("appearance", stage_appearance)
		if mother_instance.has_method("apply_appearance"):
			mother_instance.call("apply_appearance")

func play_action(action_name: String) -> void:
	current_action = action_name

func set_disturbed_state(p_is_disturbed: bool, intensity: float = 1.0) -> void:
	is_disturbed = p_is_disturbed
	disturbance_intensity = intensity

func look_toward(target_global_position: Vector3, _delta: float, _turn_speed: float) -> void:
	target_look_point = target_global_position
	has_look_target = true

func snap_look_at(target_global_position: Vector3) -> void:
	target_look_point = target_global_position
	has_look_target = true
	var local_dir: Vector3 = to_local(target_look_point)
	local_dir.y = 0.0
	if local_dir.length_squared() > 0.01:
		current_look_yaw = atan2(-local_dir.x, -local_dir.z)

func set_movement_velocity(velocity: Vector3, _delta: float) -> void:
	if is_monster_controlled or not animation_player:
		return
	
	is_moving = velocity.length_squared() > 0.04
	if is_moving:
		if animation_player.has_animation("Armature|Armature|walking_man|baselayer"):
			if not animation_player.is_playing():
				animation_player.play("Armature|Armature|walking_man|baselayer")
			animation_player.speed_scale = clampf(velocity.length() / 2.0, 0.6, 1.8)
	else:
		if animation_player.is_playing() and animation_player.current_animation.contains("walking_man"):
			animation_player.pause()

func reset_visuals() -> void:
	has_look_target = false
	current_action = FamiliarConstants.ACTION_IDLE
	reset_all_bone_overrides()

# ==============================================================================
# Procedural Bone Manipulation: Normal & Doubtful Stages
# ==============================================================================

func _update_twitch(delta: float) -> void:
	if not is_disturbed:
		twitch_impulse = 0.0
		return
	
	twitch_timer += delta
	var twitch_rate: float = 3.2 if current_stage == FamiliarConstants.BehaviorStage.DOUBTFUL else 0.8
	if twitch_timer >= twitch_rate:
		twitch_timer = 0.0
		twitch_impulse = randf_range(0.3, 0.8) * disturbance_intensity
	else:
		twitch_impulse = lerpf(twitch_impulse, 0.0, delta * 6.0)

func _update_procedural_skeletal_pose(delta: float) -> void:
	if not skeleton:
		return
	
	# In Normal mode while walking, the walking animation plays cleanly without
	# static upper-body chore offsets fighting it.
	if current_stage == FamiliarConstants.BehaviorStage.NORMAL and is_moving:
		# Walking animation naturally drives the entire body
		return
	
	# Freeze completely during unnatural pause in Doubtful stage
	if current_action == FamiliarConstants.ACTION_UNNATURAL_PAUSE:
		return
	
	# --------------------------------------------------------------------------
	# 1. Head Tilt & Gaze Tracking (neck_020 & Head_021)
	# --------------------------------------------------------------------------
	var tilt_angle_z: float = 0.0
	if current_stage == FamiliarConstants.BehaviorStage.DOUBTFUL:
		tilt_angle_z = deg_to_rad(14.0) # Subtle unnatural tilt
	
	var twitch_roll: float = (sin(anim_time * 28.0) * deg_to_rad(6.0) * twitch_impulse)
	var twitch_yaw: float = (cos(anim_time * 22.0) * deg_to_rad(5.0) * twitch_impulse)
	
	# Calculate target gaze relative to adapter orientation
	var target_yaw: float = 0.0
	var target_pitch: float = 0.0
	if has_look_target:
		var local_target: Vector3 = to_local(target_look_point)
		target_yaw = clampf(atan2(-local_target.x, -local_target.z), deg_to_rad(-65.0), deg_to_rad(65.0))
		var horiz_dist: float = maxf(Vector2(local_target.x, local_target.z).length(), 0.1)
		target_pitch = clampf(atan2(local_target.y - 1.5, horiz_dist), deg_to_rad(-25.0), deg_to_rad(25.0))
	
	# Gaze interpolation speed: Delayed creeping tracking in Doubtful, smooth natural in Normal
	var gaze_turn_speed: float = 3.5 if current_stage == FamiliarConstants.BehaviorStage.NORMAL else 0.9
	current_look_yaw = lerp_angle(current_look_yaw, target_yaw, delta * gaze_turn_speed)
	current_look_pitch = lerpf(current_look_pitch, target_pitch, delta * gaze_turn_speed)
	
	# Distribute gaze: 35% on neck, 65% on head
	var neck_rot := Quaternion.from_euler(Vector3(
		current_look_pitch * 0.35,
		current_look_yaw * 0.35,
		tilt_angle_z * 0.5 + twitch_roll * 0.4
	))
	var head_rot := Quaternion.from_euler(Vector3(
		current_look_pitch * 0.65,
		current_look_yaw * 0.65 + twitch_yaw,
		tilt_angle_z * 0.5 + twitch_roll * 0.6
	))
	
	_apply_bone_offset("neck", neck_rot)
	_apply_bone_offset("head", head_rot)
	
	# --------------------------------------------------------------------------
	# 2. Torso Posture & Breathing
	# --------------------------------------------------------------------------
	if current_stage == FamiliarConstants.BehaviorStage.NORMAL:
		# Gentle, natural breathing expansion while idling/standing (no contortions)
		var breath: float = sin(anim_time * 2.2) * deg_to_rad(1.0)
		_apply_bone_offset("spine_upper", Quaternion.from_euler(Vector3(breath, 0.0, 0.0)))
		_apply_bone_offset("spine_mid", Quaternion.IDENTITY)
	elif current_stage == FamiliarConstants.BehaviorStage.DOUBTFUL:
		# Slightly stiff posture with slight shoulder twitch
		var sh_twitch: float = sin(anim_time * 25.0) * deg_to_rad(4.0) * twitch_impulse
		_apply_bone_offset("shoulder_r", Quaternion.from_euler(Vector3(0.0, 0.0, sh_twitch)))
		_apply_bone_offset("spine_upper", Quaternion.IDENTITY)
	
	# --------------------------------------------------------------------------
	# 3. Arm Movements & Household Routines
	# --------------------------------------------------------------------------
	match current_action:
		FamiliarConstants.ACTION_GREET:
			# Friendly welcoming wave (right arm raised naturally)
			var wave: float = sin(anim_time * 8.0) * deg_to_rad(15.0)
			var r_arm := Quaternion.from_euler(Vector3(deg_to_rad(-70.0), 0.0, deg_to_rad(-35.0) + wave))
			var r_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-40.0), 0.0, 0.0))
			_apply_bone_offset("arm_r", r_arm)
			_apply_bone_offset("forearm_r", r_forearm)
			_apply_bone_offset("arm_l", Quaternion.IDENTITY)
			_apply_bone_offset("forearm_l", Quaternion.IDENTITY)
		
		FamiliarConstants.ACTION_COOKING:
			# Both arms bent forward, natural rhythmic stirring
			var stir_r: float = sin(anim_time * 3.5) * deg_to_rad(16.0)
			var stir_l: float = cos(anim_time * 3.5) * deg_to_rad(12.0)
			var r_arm := Quaternion.from_euler(Vector3(deg_to_rad(-50.0) + stir_r, deg_to_rad(15.0), deg_to_rad(-10.0)))
			var r_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-60.0), 0.0, 0.0))
			var l_arm := Quaternion.from_euler(Vector3(deg_to_rad(-45.0) + stir_l, deg_to_rad(-15.0), deg_to_rad(10.0)))
			var l_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-55.0), 0.0, 0.0))
			_apply_bone_offset("arm_r", r_arm)
			_apply_bone_offset("forearm_r", r_forearm)
			_apply_bone_offset("arm_l", l_arm)
			_apply_bone_offset("forearm_l", l_forearm)
		
		FamiliarConstants.ACTION_CLEANING:
			# Right arm wiping back and forth
			var wipe: float = sin(anim_time * 4.5) * deg_to_rad(28.0)
			var r_arm := Quaternion.from_euler(Vector3(deg_to_rad(-45.0), wipe, deg_to_rad(-15.0)))
			var r_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-50.0), 0.0, 0.0))
			_apply_bone_offset("arm_r", r_arm)
			_apply_bone_offset("forearm_r", r_forearm)
			_apply_bone_offset("arm_l", Quaternion.IDENTITY)
			_apply_bone_offset("forearm_l", Quaternion.IDENTITY)
		
		FamiliarConstants.ACTION_READING:
			# Holding book in both hands, head tilted slightly down
			var r_arm := Quaternion.from_euler(Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), deg_to_rad(-15.0)))
			var r_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-70.0), 0.0, 0.0))
			var l_arm := Quaternion.from_euler(Vector3(deg_to_rad(-55.0), deg_to_rad(-20.0), deg_to_rad(15.0)))
			var l_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-70.0), 0.0, 0.0))
			_apply_bone_offset("arm_r", r_arm)
			_apply_bone_offset("forearm_r", r_forearm)
			_apply_bone_offset("arm_l", l_arm)
			_apply_bone_offset("forearm_l", l_forearm)
		
		FamiliarConstants.ACTION_CHECKING_PANTRY:
			var r_arm := Quaternion.from_euler(Vector3(deg_to_rad(-105.0), 0.0, deg_to_rad(-10.0)))
			var r_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-20.0), 0.0, 0.0))
			_apply_bone_offset("arm_r", r_arm)
			_apply_bone_offset("forearm_r", r_forearm)
			_apply_bone_offset("arm_l", Quaternion.IDENTITY)
			_apply_bone_offset("forearm_l", Quaternion.IDENTITY)
		
		FamiliarConstants.ACTION_REPEATING_CHORE:
			# Rapid, mechanical, glitchy chore repetition (Doubtful stage)
			var glitch: float = sin(anim_time * 15.0) * deg_to_rad(38.0)
			var r_arm := Quaternion.from_euler(Vector3(deg_to_rad(-60.0) + glitch, 0.0, deg_to_rad(-15.0)))
			var r_forearm := Quaternion.from_euler(Vector3(deg_to_rad(-50.0), 0.0, 0.0))
			_apply_bone_offset("arm_r", r_arm)
			_apply_bone_offset("forearm_r", r_forearm)
			_apply_bone_offset("arm_l", Quaternion.IDENTITY)
			_apply_bone_offset("forearm_l", Quaternion.IDENTITY)
		
		_:
			# Default idle: arms relaxed naturally at sides
			_apply_bone_offset("arm_r", Quaternion.IDENTITY)
			_apply_bone_offset("forearm_r", Quaternion.IDENTITY)
			_apply_bone_offset("arm_l", Quaternion.IDENTITY)
			_apply_bone_offset("forearm_l", Quaternion.IDENTITY)

# ==============================================================================
# Stage 3: Certain Stage 9-Step Recurring Contortion Sequence
# ==============================================================================

func _update_certain_sequence(delta: float) -> void:
	if not skeleton:
		return
	
	certain_phase_timer += delta
	
	# Maintain continuous gaze tracking onto player during entire Certain sequence
	var target_yaw: float = 0.0
	var target_pitch: float = 0.0
	if has_look_target:
		var local_target: Vector3 = to_local(target_look_point)
		target_yaw = clampf(atan2(-local_target.x, -local_target.z), deg_to_rad(-75.0), deg_to_rad(75.0))
		var horiz_dist: float = maxf(Vector2(local_target.x, local_target.z).length(), 0.1)
		target_pitch = clampf(atan2(local_target.y - 1.5, horiz_dist), deg_to_rad(-30.0), deg_to_rad(30.0))
	
	# Locked gaze interpolation
	current_look_yaw = lerp_angle(current_look_yaw, target_yaw, delta * 7.0)
	current_look_pitch = lerpf(current_look_pitch, target_pitch, delta * 7.0)
	
	# Determine sequence duration per phase
	var phase_duration: float = 2.0
	match certain_phase:
		FamiliarConstants.CertainPhase.EYE_CONTACT:
			phase_duration = 2.0
		FamiliarConstants.CertainPhase.NECK_TWIST:
			phase_duration = 1.0
		FamiliarConstants.CertainPhase.TORSO_BEND:
			phase_duration = 1.2
		FamiliarConstants.CertainPhase.SHOULDER_ASYMMETRY:
			phase_duration = 0.9
		FamiliarConstants.CertainPhase.ARMS_JERK:
			phase_duration = 1.0
		FamiliarConstants.CertainPhase.CONTORTED_FREEZE:
			phase_duration = 2.8
		FamiliarConstants.CertainPhase.SLOW_RECOVERY:
			phase_duration = 2.2
	
	# Progress phase when duration met
	if certain_phase_timer >= phase_duration:
		certain_phase_timer = 0.0
		certain_phase = (certain_phase + 1) % 7
		if certain_phase == FamiliarConstants.CertainPhase.EYE_CONTACT:
			certain_cycle_count += 1
	
	# Contortion parameters based on phase
	var neck_twist_yaw: float = 0.0
	var neck_tilt_roll: float = 0.0
	var spine_side_bend: float = 0.0
	var spine_arch: float = 0.0
	var shoulder_r_lift: float = 0.0
	var shoulder_l_drop: float = 0.0
	var arm_r_pose := Quaternion.IDENTITY
	var arm_l_pose := Quaternion.IDENTITY
	var forearm_r_pose := Quaternion.IDENTITY
	var forearm_l_pose := Quaternion.IDENTITY
	var freeze_shudder: float = 0.0
	
	# Controlled variation alternate direction on alternate cycles
	var dir_mult: float = 1.0 if (certain_cycle_count % 2 == 0) else -1.0
	
	match certain_phase:
		FamiliarConstants.CertainPhase.EYE_CONTACT:
			# Step 1 & 2: Prolonged eye contact, rigid upright posture
			pass
		
		FamiliarConstants.CertainPhase.NECK_TWIST:
			# Step 3: Suddenly twist or tilt the neck
			var t: float = clampf(certain_phase_timer / 0.5, 0.0, 1.0)
			neck_twist_yaw = deg_to_rad(28.0 * dir_mult) * t
			neck_tilt_roll = deg_to_rad(22.0 * dir_mult) * t
		
		FamiliarConstants.CertainPhase.TORSO_BEND:
			# Step 4: Bend upper torso sideways or rotate unnaturally
			neck_twist_yaw = deg_to_rad(28.0 * dir_mult)
			neck_tilt_roll = deg_to_rad(22.0 * dir_mult)
			var t: float = clampf(certain_phase_timer / 0.8, 0.0, 1.0)
			spine_side_bend = deg_to_rad(14.0 * dir_mult) * t
			spine_arch = deg_to_rad(-7.0) * t
		
		FamiliarConstants.CertainPhase.SHOULDER_ASYMMETRY:
			# Step 5: Raise shoulders asymmetrically
			neck_twist_yaw = deg_to_rad(28.0 * dir_mult)
			neck_tilt_roll = deg_to_rad(22.0 * dir_mult)
			spine_side_bend = deg_to_rad(14.0 * dir_mult)
			spine_arch = deg_to_rad(-7.0)
			var t: float = clampf(certain_phase_timer / 0.6, 0.0, 1.0)
			shoulder_r_lift = deg_to_rad(22.0) * t
			shoulder_l_drop = deg_to_rad(-10.0) * t
		
		FamiliarConstants.CertainPhase.ARMS_JERK:
			# Step 6: Make arms jerk into disturbing positions
			neck_twist_yaw = deg_to_rad(28.0 * dir_mult)
			neck_tilt_roll = deg_to_rad(22.0 * dir_mult)
			spine_side_bend = deg_to_rad(14.0 * dir_mult)
			spine_arch = deg_to_rad(-7.0)
			shoulder_r_lift = deg_to_rad(22.0)
			shoulder_l_drop = deg_to_rad(-10.0)
			var t: float = clampf(certain_phase_timer / 0.6, 0.0, 1.0)
			arm_r_pose = Quaternion.from_euler(Vector3(deg_to_rad(-30.0) * t, deg_to_rad(25.0) * t, deg_to_rad(-45.0) * t))
			forearm_r_pose = Quaternion.from_euler(Vector3(deg_to_rad(-65.0) * t, 0.0, 0.0))
			arm_l_pose = Quaternion.from_euler(Vector3(deg_to_rad(15.0) * t, deg_to_rad(-20.0) * t, deg_to_rad(25.0) * t))
			forearm_l_pose = Quaternion.from_euler(Vector3(deg_to_rad(-40.0) * t, 0.0, 0.0))
		
		FamiliarConstants.CertainPhase.CONTORTED_FREEZE:
			# Step 7: Freeze completely in contorted pose with subtle tension micro-tremor
			freeze_shudder = sin(anim_time * 45.0) * deg_to_rad(1.5)
			neck_twist_yaw = deg_to_rad(28.0 * dir_mult) + freeze_shudder
			neck_tilt_roll = deg_to_rad(22.0 * dir_mult)
			spine_side_bend = deg_to_rad(14.0 * dir_mult)
			spine_arch = deg_to_rad(-7.0)
			shoulder_r_lift = deg_to_rad(22.0)
			shoulder_l_drop = deg_to_rad(-10.0)
			arm_r_pose = Quaternion.from_euler(Vector3(deg_to_rad(-30.0), deg_to_rad(25.0), deg_to_rad(-45.0)))
			forearm_r_pose = Quaternion.from_euler(Vector3(deg_to_rad(-65.0), 0.0, 0.0))
			arm_l_pose = Quaternion.from_euler(Vector3(deg_to_rad(15.0), deg_to_rad(-20.0), deg_to_rad(25.0)))
			forearm_l_pose = Quaternion.from_euler(Vector3(deg_to_rad(-40.0), 0.0, 0.0))
		
		FamiliarConstants.CertainPhase.SLOW_RECOVERY:
			# Step 8: Slowly recover while maintaining eye contact
			var rec: float = 1.0 - clampf(certain_phase_timer / 2.0, 0.0, 1.0)
			neck_twist_yaw = deg_to_rad(28.0 * dir_mult) * rec
			neck_tilt_roll = deg_to_rad(22.0 * dir_mult) * rec
			spine_side_bend = deg_to_rad(14.0 * dir_mult) * rec
			spine_arch = deg_to_rad(-7.0) * rec
			shoulder_r_lift = deg_to_rad(22.0) * rec
			shoulder_l_drop = deg_to_rad(-10.0) * rec
			arm_r_pose = Quaternion.from_euler(Vector3(deg_to_rad(-30.0) * rec, deg_to_rad(25.0) * rec, deg_to_rad(-45.0) * rec))
			forearm_r_pose = Quaternion.from_euler(Vector3(deg_to_rad(-65.0) * rec, 0.0, 0.0))
			arm_l_pose = Quaternion.from_euler(Vector3(deg_to_rad(15.0) * rec, deg_to_rad(-20.0) * rec, deg_to_rad(25.0) * rec))
			forearm_l_pose = Quaternion.from_euler(Vector3(deg_to_rad(-40.0) * rec, 0.0, 0.0))
	
	# Apply final rotations to skeleton:
	var neck_rot := Quaternion.from_euler(Vector3(
		current_look_pitch * 0.35,
		current_look_yaw * 0.35 + neck_twist_yaw * 0.5,
		neck_tilt_roll * 0.5
	))
	var head_rot := Quaternion.from_euler(Vector3(
		current_look_pitch * 0.65,
		current_look_yaw * 0.65 + neck_twist_yaw * 0.5,
		neck_tilt_roll * 0.5
	))
	var spine_rot := Quaternion.from_euler(Vector3(spine_arch, 0.0, spine_side_bend))
	
	_apply_bone_offset("neck", neck_rot)
	_apply_bone_offset("head", head_rot)
	_apply_bone_offset("spine_upper", spine_rot)
	_apply_bone_offset("shoulder_r", Quaternion.from_euler(Vector3(0.0, 0.0, shoulder_r_lift)))
	_apply_bone_offset("shoulder_l", Quaternion.from_euler(Vector3(0.0, 0.0, shoulder_l_drop)))
	_apply_bone_offset("arm_r", arm_r_pose)
	_apply_bone_offset("forearm_r", forearm_r_pose)
	_apply_bone_offset("arm_l", arm_l_pose)
	_apply_bone_offset("forearm_l", forearm_l_pose)

func _apply_bone_offset(bone_key: String, local_offset_rot: Quaternion) -> void:
	var idx: int = bone_indices.get(bone_key, -1)
	if idx >= 0 and base_bone_poses.has(idx):
		var base_rot: Quaternion = base_bone_poses[idx]
		skeleton.set_bone_pose_rotation(idx, base_rot * local_offset_rot)

func reset_all_bone_overrides() -> void:
	if not skeleton:
		return
	for b in base_bone_poses:
		skeleton.set_bone_pose_rotation(b, base_bone_poses[b])

# ==============================================================================
# Monster System Handoff Mechanism (K'von's Monster Integration)
# ==============================================================================

## Hands off skeletal control to K'von's Monster System during STALKING, PURSUING, or CAPTURE.
## Restores all bones to base poses so animation clips play without interference.
func hand_off_to_monster() -> void:
	is_monster_controlled = true
	reset_all_bone_overrides()
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	monster_handoff_started.emit()

## Reclaims control when the monster returns to disguised household routine state.
func reclaim_from_monster() -> void:
	is_monster_controlled = false
	apply_stage(current_stage)
	play_action(current_action)
	monster_handoff_ended.emit()
