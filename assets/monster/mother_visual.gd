extends Node3D
## Reusable appearance-only mother. Behavior and movement belong to gameplay code.
@export_enum("Ordinary", "Doubtful", "Uncanny", "Revealed") var appearance: String = "Ordinary"
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
	apply_appearance()

func apply_appearance() -> void:
	var strength: float = {"Ordinary": 0.0, "Doubtful": 0.3, "Uncanny": 0.65, "Revealed": 1.0}[appearance]
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		for shape in mesh_node.get_blend_shape_count():
			var shape_name: String = mesh_node.mesh.get_blend_shape_name(shape)
			mesh_node.set_blend_shape_value(shape, 1.0 - strength if shape_name == "RevealStrength" else strength)
