extends Node3D

var player: AnimationPlayer
var status: Label

func _ready() -> void:
	var model_scene := load("res://assets/monster/Casual.gltf") as PackedScene
	if model_scene == null:
		push_error("Could not import Casual.gltf")
		get_tree().quit(1)
		return
	var model := model_scene.instantiate()
	add_child(model)
	for node in model.find_children("*", "AnimationPlayer", true, false):
		player = node as AnimationPlayer
		break
	if player == null:
		push_error("Model has no AnimationPlayer")
		get_tree().quit(1)
		return
	print("Imported animations: ", player.get_animation_list())
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	print("Model bounds: ", bounds)
	var center := bounds.get_center()
	var height := maxf(bounds.size.y, 1.0)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = center + Vector3(0, height * 0.1, height * 2.0)
	camera.look_at(center)
	camera.current = true
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.5
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.16, 0.18, 0.2)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	var ui := CanvasLayer.new()
	add_child(ui)
	var column := VBoxContainer.new()
	column.position = Vector2(16, 16)
	ui.add_child(column)
	status = Label.new()
	column.add_child(status)
	for animation_name in ["Idle", "Walk", "Run", "Wave"]:
		if not player.has_animation(animation_name):
			push_error("Missing animation: " + animation_name)
			get_tree().quit(1)
			return
		var button := Button.new()
		button.text = animation_name
		button.pressed.connect(_play.bind(animation_name))
		column.add_child(button)
	_play("Idle")
	if "--verify-model" in OS.get_cmdline_user_args():
		for animation_name in ["Idle", "Walk", "Run", "Wave"]:
			_play(animation_name)
			await get_tree().create_timer(0.3).timeout
			if player.current_animation_position <= 0.0:
				push_error("Animation did not advance: " + animation_name)
				get_tree().quit(1)
				return
			print("PLAYBACK PASS: ", animation_name)
		_play("Idle")
		player.advance(0.5)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://design/monster/preview.png")
		print("MODEL PREVIEW PASS")
		get_tree().quit()

func _play(animation_name: String) -> void:
	player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	player.play(animation_name)
	status.text = "Mother base model - " + animation_name + " (appearance unmodified)"
