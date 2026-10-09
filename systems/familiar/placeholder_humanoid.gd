class_name PlaceholderHumanoid
extends Node3D

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")
## Low-poly placeholder humanoid model for the Familiar.
## Provides procedural posing, animations, and stage-specific visual cues.

@onready var hips: Node3D = $Hips
@onready var torso: MeshInstance3D = $Hips/Torso
@onready var head_pivot: Node3D = $Hips/HeadPivot
@onready var head_mesh: MeshInstance3D = $Hips/HeadPivot/HeadMesh
@onready var eye_left: MeshInstance3D = $Hips/HeadPivot/EyeLeft
@onready var eye_right: MeshInstance3D = $Hips/HeadPivot/EyeRight
@onready var left_arm_pivot: Node3D = $Hips/LeftArmPivot
@onready var right_arm_pivot: Node3D = $Hips/RightArmPivot
@onready var left_arm_mesh: MeshInstance3D = $Hips/LeftArmPivot/LeftArmMesh
@onready var right_arm_mesh: MeshInstance3D = $Hips/RightArmPivot/RightArmMesh
@onready var left_leg: MeshInstance3D = $Hips/LeftLeg
@onready var right_leg: MeshInstance3D = $Hips/RightLeg

var current_stage: int = FamiliarConstants.BehaviorStage.NORMAL
var current_action: String = FamiliarConstants.ACTION_IDLE
var is_disturbed: bool = false
var disturbance_intensity: float = 0.0

# Animation timer
var anim_time: float = 0.0
var twitch_timer: float = 0.0
var twitch_offset: Vector3 = Vector3.ZERO
var target_look_point: Vector3 = Vector3.ZERO
var has_look_target: bool = false

# Certain stage recurring sequence
var certain_phase: int = FamiliarConstants.CertainPhase.EYE_CONTACT
var certain_phase_timer: float = 0.0
var certain_cycle_count: int = 0

# Materials
var torso_mat: StandardMaterial3D
var eye_mat: StandardMaterial3D
var skin_mat: StandardMaterial3D

func _ready() -> void:
	_init_materials()
	apply_stage_visuals(current_stage)

func _init_materials() -> void:
	torso_mat = StandardMaterial3D.new()
	torso_mat.albedo_color = Color(0.82, 0.65, 0.52) # Warm everyday cardigan
	if torso:
		torso.material_override = torso_mat
	
	skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.92, 0.80, 0.72) # Natural skin tone
	if head_mesh:
		head_mesh.material_override = skin_mat
	
	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.12, 0.12, 0.15) # Dark natural eyes
	if eye_left:
		eye_left.material_override = eye_mat
	if eye_right:
		eye_right.material_override = eye_mat

func _process(delta: float) -> void:
	anim_time += delta
	_update_twitch(delta)
	
	if current_stage == FamiliarConstants.BehaviorStage.CERTAIN:
		_update_certain_sequence(delta)
	else:
		_update_procedural_pose(delta)
	
	_update_look_at(delta)

func apply_stage_visuals(stage: int) -> void:
	current_stage = stage
	if not torso_mat or not eye_mat:
		return
	
	match stage:
		FamiliarConstants.BehaviorStage.NORMAL:
			torso_mat.albedo_color = Color(0.82, 0.65, 0.52) # Warm friendly beige
			eye_mat.albedo_color = Color(0.15, 0.15, 0.18)
			eye_mat.emission_enabled = false
			head_pivot.rotation.z = 0.0
			if torso:
				torso.rotation = Vector3.ZERO
			is_disturbed = false
			disturbance_intensity = 0.0
		FamiliarConstants.BehaviorStage.DOUBTFUL:
			torso_mat.albedo_color = Color(0.72, 0.58, 0.48) # Slightly duller
			eye_mat.albedo_color = Color(0.4, 0.3, 0.15)
			eye_mat.emission_enabled = false
			head_pivot.rotation.z = deg_to_rad(14.0) # Unnatural slight head tilt
			if torso:
				torso.rotation = Vector3.ZERO
			is_disturbed = true
			disturbance_intensity = 0.4
		FamiliarConstants.BehaviorStage.CERTAIN:
			torso_mat.albedo_color = Color(0.55, 0.50, 0.48) # Cold, washed out
			eye_mat.albedo_color = Color(0.95, 0.2, 0.2) # Uncanny glaring eyes
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(0.8, 0.1, 0.1)
			eye_mat.emission_energy_multiplier = 0.8
			is_disturbed = true
			disturbance_intensity = 1.0
			certain_phase = FamiliarConstants.CertainPhase.EYE_CONTACT
			certain_phase_timer = 0.0

func set_current_action(action_name: String) -> void:
	current_action = action_name

func set_look_target(target_pos: Vector3) -> void:
	target_look_point = target_pos
	has_look_target = true

func clear_look_target() -> void:
	has_look_target = false

func _update_twitch(delta: float) -> void:
	if not is_disturbed:
		twitch_offset = Vector3.ZERO
		return
	
	twitch_timer += delta
	var twitch_rate: float = 3.2 if current_stage == FamiliarConstants.BehaviorStage.DOUBTFUL else 0.8
	if twitch_timer >= twitch_rate:
		twitch_timer = 0.0
		var jitter: float = 0.04 * disturbance_intensity
		twitch_offset = Vector3(
			randf_range(-jitter, jitter),
			randf_range(-jitter * 0.5, jitter * 0.5),
			randf_range(-jitter, jitter)
		)
	else:
		twitch_offset = twitch_offset.lerp(Vector3.ZERO, delta * 8.0)

func _update_procedural_pose(delta: float) -> void:
	if not hips or not left_arm_pivot or not right_arm_pivot:
		return
	
	if current_action == FamiliarConstants.ACTION_UNNATURAL_PAUSE:
		return
	
	var bob_speed: float = 2.0 if current_stage == FamiliarConstants.BehaviorStage.NORMAL else 0.8
	var bob_amount: float = 0.02 if current_stage == FamiliarConstants.BehaviorStage.NORMAL else 0.005
	hips.position.y = 0.85 + sin(anim_time * bob_speed) * bob_amount + twitch_offset.y
	
	match current_action:
		FamiliarConstants.ACTION_IDLE, FamiliarConstants.ACTION_DISTURBED_IDLE:
			var arm_swing: float = sin(anim_time * bob_speed) * 0.05
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, arm_swing, delta * 5.0)
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, -arm_swing, delta * 5.0)
			left_arm_pivot.rotation.z = lerp_angle(left_arm_pivot.rotation.z, deg_to_rad(5.0), delta * 5.0)
			right_arm_pivot.rotation.z = lerp_angle(right_arm_pivot.rotation.z, deg_to_rad(-5.0), delta * 5.0)
		
		FamiliarConstants.ACTION_GREET:
			var wave: float = sin(anim_time * 8.0) * deg_to_rad(15.0)
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, deg_to_rad(-80.0), delta * 6.0)
			right_arm_pivot.rotation.z = lerp_angle(right_arm_pivot.rotation.z, deg_to_rad(-35.0) + wave, delta * 8.0)
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, 0.0, delta * 4.0)
			left_arm_pivot.rotation.z = lerp_angle(left_arm_pivot.rotation.z, deg_to_rad(5.0), delta * 4.0)
		
		FamiliarConstants.ACTION_COOKING:
			var stir_left: float = sin(anim_time * 4.0) * deg_to_rad(15.0)
			var stir_right: float = cos(anim_time * 4.0) * deg_to_rad(20.0)
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, deg_to_rad(-50.0) + stir_left, delta * 6.0)
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, deg_to_rad(-55.0) + stir_right, delta * 6.0)
			left_arm_pivot.rotation.z = lerp_angle(left_arm_pivot.rotation.z, deg_to_rad(15.0), delta * 5.0)
			right_arm_pivot.rotation.z = lerp_angle(right_arm_pivot.rotation.z, deg_to_rad(-15.0), delta * 5.0)
		
		FamiliarConstants.ACTION_CLEANING:
			var wipe: float = sin(anim_time * 5.0) * deg_to_rad(30.0)
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, deg_to_rad(-45.0), delta * 6.0)
			right_arm_pivot.rotation.y = lerp_angle(right_arm_pivot.rotation.y, wipe, delta * 8.0)
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, deg_to_rad(-20.0), delta * 4.0)
		
		FamiliarConstants.ACTION_READING:
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, deg_to_rad(-60.0), delta * 5.0)
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, deg_to_rad(-60.0), delta * 5.0)
			left_arm_pivot.rotation.z = lerp_angle(left_arm_pivot.rotation.z, deg_to_rad(25.0), delta * 5.0)
			right_arm_pivot.rotation.z = lerp_angle(right_arm_pivot.rotation.z, deg_to_rad(-25.0), delta * 5.0)
		
		FamiliarConstants.ACTION_CHECKING_PANTRY:
			right_arm_pivot.rotation.x = lerp_angle(right_arm_pivot.rotation.x, deg_to_rad(-110.0), delta * 4.0)
			left_arm_pivot.rotation.x = lerp_angle(left_arm_pivot.rotation.x, deg_to_rad(-20.0), delta * 4.0)
		
		FamiliarConstants.ACTION_REPEATING_CHORE:
			var glitch_speed: float = 12.0
			var glitch_wipe: float = sin(anim_time * glitch_speed) * deg_to_rad(45.0)
			right_arm_pivot.rotation.x = deg_to_rad(-60.0) + glitch_wipe
			right_arm_pivot.rotation.y = sin(anim_time * 6.0) * deg_to_rad(20.0)
			left_arm_pivot.rotation.x = deg_to_rad(-40.0) - (glitch_wipe * 0.5)
		
		FamiliarConstants.ACTION_STARING:
			left_arm_pivot.rotation = Vector3(0.0, 0.0, deg_to_rad(4.0))
			right_arm_pivot.rotation = Vector3(0.0, 0.0, deg_to_rad(-4.0))

func _update_certain_sequence(delta: float) -> void:
	if not hips or not left_arm_pivot or not right_arm_pivot or not torso:
		return
	
	certain_phase_timer += delta
	var phase_duration: float = 2.0
	match certain_phase:
		FamiliarConstants.CertainPhase.EYE_CONTACT: phase_duration = 2.0
		FamiliarConstants.CertainPhase.NECK_TWIST: phase_duration = 1.0
		FamiliarConstants.CertainPhase.TORSO_BEND: phase_duration = 1.2
		FamiliarConstants.CertainPhase.SHOULDER_ASYMMETRY: phase_duration = 0.9
		FamiliarConstants.CertainPhase.ARMS_JERK: phase_duration = 1.0
		FamiliarConstants.CertainPhase.CONTORTED_FREEZE: phase_duration = 2.8
		FamiliarConstants.CertainPhase.SLOW_RECOVERY: phase_duration = 2.2
	
	if certain_phase_timer >= phase_duration:
		certain_phase_timer = 0.0
		certain_phase = (certain_phase + 1) % 7
		if certain_phase == FamiliarConstants.CertainPhase.EYE_CONTACT:
			certain_cycle_count += 1
	
	var dir_mult: float = 1.0 if (certain_cycle_count % 2 == 0) else -1.0
	hips.position.y = 0.85
	
	match certain_phase:
		FamiliarConstants.CertainPhase.EYE_CONTACT:
			head_pivot.rotation.z = lerp_angle(head_pivot.rotation.z, 0.0, delta * 4.0)
			torso.rotation = torso.rotation.lerp(Vector3.ZERO, delta * 4.0)
			left_arm_pivot.rotation = left_arm_pivot.rotation.lerp(Vector3(0, 0, deg_to_rad(4.0)), delta * 4.0)
			right_arm_pivot.rotation = right_arm_pivot.rotation.lerp(Vector3(0, 0, deg_to_rad(-4.0)), delta * 4.0)
		
		FamiliarConstants.CertainPhase.NECK_TWIST:
			head_pivot.rotation.z = lerp_angle(head_pivot.rotation.z, deg_to_rad(25.0 * dir_mult), delta * 8.0)
		
		FamiliarConstants.CertainPhase.TORSO_BEND:
			head_pivot.rotation.z = deg_to_rad(25.0 * dir_mult)
			torso.rotation.z = lerp_angle(torso.rotation.z, deg_to_rad(15.0 * dir_mult), delta * 6.0)
			torso.rotation.x = lerp_angle(torso.rotation.x, deg_to_rad(-8.0), delta * 6.0)
		
		FamiliarConstants.CertainPhase.SHOULDER_ASYMMETRY:
			right_arm_pivot.position.y = lerpf(right_arm_pivot.position.y, 0.62, delta * 8.0)
			left_arm_pivot.position.y = lerpf(left_arm_pivot.position.y, 0.50, delta * 8.0)
		
		FamiliarConstants.CertainPhase.ARMS_JERK, FamiliarConstants.CertainPhase.CONTORTED_FREEZE:
			head_pivot.rotation.z = deg_to_rad(25.0 * dir_mult)
			torso.rotation.z = deg_to_rad(15.0 * dir_mult)
			torso.rotation.x = deg_to_rad(-8.0)
			right_arm_pivot.rotation.x = deg_to_rad(-45.0)
			right_arm_pivot.rotation.z = deg_to_rad(-35.0)
			left_arm_pivot.rotation.x = deg_to_rad(20.0)
			left_arm_pivot.rotation.z = deg_to_rad(30.0)
		
		FamiliarConstants.CertainPhase.SLOW_RECOVERY:
			var t: float = clampf(certain_phase_timer / 2.0, 0.0, 1.0)
			head_pivot.rotation.z = lerp_angle(deg_to_rad(25.0 * dir_mult), 0.0, t)
			torso.rotation.z = lerp_angle(deg_to_rad(15.0 * dir_mult), 0.0, t)
			torso.rotation.x = lerp_angle(deg_to_rad(-8.0), 0.0, t)
			right_arm_pivot.position.y = lerpf(0.62, 0.55, t)
			left_arm_pivot.position.y = lerpf(0.50, 0.55, t)
			right_arm_pivot.rotation = right_arm_pivot.rotation.lerp(Vector3(0, 0, deg_to_rad(-4.0)), delta * 3.0)
			left_arm_pivot.rotation = left_arm_pivot.rotation.lerp(Vector3(0, 0, deg_to_rad(4.0)), delta * 3.0)

func _update_look_at(delta: float) -> void:
	if not head_pivot:
		return
	
	if has_look_target:
		var local_target: Vector3 = to_local(target_look_point)
		var angle_y: float = atan2(-local_target.x, -local_target.z)
		angle_y = clampf(angle_y, deg_to_rad(-75.0), deg_to_rad(75.0))
		
		var turn_speed: float = 3.5 if current_stage == FamiliarConstants.BehaviorStage.NORMAL else (0.9 if current_stage == FamiliarConstants.BehaviorStage.DOUBTFUL else 6.0)
		head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, angle_y, delta * turn_speed)
	else:
		head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, 0.0, delta * 3.0)
