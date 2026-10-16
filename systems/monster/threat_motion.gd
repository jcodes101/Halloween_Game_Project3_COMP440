extends Node
## Small procedural performance on the existing model, layered over its walk.
## The Familiar adapter keeps exclusive control during household routines.
var actor: MonsterController
var phase := 0.0
var lean := 0.0
var bob := 0.0

func _ready() -> void:
	# MotherVisual constructs its imported character in the parent's _ready().
	call_deferred("_bind_rig")

func _bind_rig() -> void:
	var rigs := get_parent().find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		var pose := preload("res://systems/monster/threat_pose.gd").new()
		pose.actor = actor
		rigs[0].add_child(pose)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.visual):
		return
	var model := actor.visual.get("character") as Node3D
	if model == null:
		return
	if not actor.is_physics_processing():
		model.rotation = Vector3.ZERO
		model.position = Vector3.ZERO
		return
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var chasing := actor.monster_state in [MonsterController.State.PURSUING, MonsterController.State.RETREATING]
	var searching := actor.monster_state == MonsterController.State.SEARCHING
	var still_reveal := actor.monster_state in [MonsterController.State.REVEALING, MonsterController.State.CAPTURED]
	phase += delta * (speed * 3.5 if speed > 0.1 else 1.4)
	var target_lean := deg_to_rad(-7.0 if chasing else -2.0 if searching else 0.0)
	lean = lerpf(lean, target_lean, 1.0 - exp(-6.0 * delta))
	var target_bob := absf(sin(phase)) * minf(speed, 4.3) * 0.006 if speed > 0.1 else sin(phase) * 0.002
	bob = lerpf(bob, 0.0 if still_reveal else target_bob, 1.0 - exp(-10.0 * delta))
	model.position.y = bob
	model.rotation.x = 0.0 if still_reveal else lean
	model.rotation.z = sin(phase * 0.5) * deg_to_rad(0.8) if searching and speed < 0.1 else 0.0
