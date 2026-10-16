extends Node3D
## Reusable appearance-only mother. Behavior and movement belong to gameplay code.
@export_enum("Ordinary", "Doubtful", "Uncanny", "Revealed") var appearance: String = "Ordinary"
@export_range(0.0, 2.0, 0.05) var appearance_blend_seconds := 0.65
var transition_from_strength := -1.0
var current_strength := 0.0
var _morph_meshes: Array[MeshInstance3D] = []
var _appearance_tween: Tween
var character: Node3D

func _ready() -> void:
	var source := load("res://assets/monster/Mother" + appearance + ".glb") as PackedScene
	character = source.instantiate() as Node3D
	add_child(character)
	var player := character.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in player.get_animation_list():
		if clip != "RESET":
			player.play(clip)
			player.advance(0.05)
			player.pause()
			break
	for node in character.find_children("*", "MeshInstance3D", true, false):
		_morph_meshes.append(node as MeshInstance3D)
	var target: float = {"Ordinary":0.0,"Doubtful":0.3,"Uncanny":0.65,"Revealed":1.0}[appearance]
	_set_strength(target if transition_from_strength < 0.0 else transition_from_strength)
	apply_appearance()

func apply_appearance() -> void:
	var strength: float = {"Ordinary": 0.0, "Doubtful": 0.3, "Uncanny": 0.65, "Revealed": 1.0}[appearance]
	if _appearance_tween != null and _appearance_tween.is_running():
		_appearance_tween.kill()
	if is_equal_approx(current_strength,strength) or appearance_blend_seconds <= 0.0:
		_set_strength(strength)
		return
	_appearance_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_appearance_tween.tween_method(_set_strength,current_strength,strength,appearance_blend_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_strength(strength: float) -> void:
	current_strength = clampf(strength,0.0,1.0)
	for mesh_node in _morph_meshes:
		for shape in mesh_node.get_blend_shape_count():
			var shape_name: String = mesh_node.mesh.get_blend_shape_name(shape)
			mesh_node.set_blend_shape_value(shape, 1.0 - current_strength if shape_name == "RevealStrength" else current_strength)
