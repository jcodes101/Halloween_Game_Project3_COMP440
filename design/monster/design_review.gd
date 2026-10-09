extends Node3D

const STAGES := ["Ordinary", "Doubtful", "Uncanny", "Revealed"]
var model: Node3D
var player: AnimationPlayer
var camera: Camera3D
var label: Label
var close_up := false
var current_stage := "Ordinary"

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 35.0
	add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	light.light_energy = 0.8
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 150, 0)
	fill.light_energy = 0.25
	add_child(fill)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.11, 0.13, 0.15)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.35
	add_child(world)
	var ui := CanvasLayer.new()
	add_child(ui)
	var controls := VBoxContainer.new()
	controls.position = Vector2(12, 12)
	ui.add_child(controls)
	label = Label.new()
	controls.add_child(label)
	for stage in STAGES:
		var button := Button.new()
		button.text = stage
		button.pressed.connect(_show_stage.bind(stage))
		controls.add_child(button)
	var view_button := Button.new()
	view_button.text = "Face / full body"
	view_button.pressed.connect(_toggle_view)
	controls.add_child(view_button)
	for angle in [0, 90, 180, 270]:
		var turn := Button.new()
		turn.text = "View " + str(angle) + "°"
		turn.pressed.connect(_rotate.bind(angle))
		controls.add_child(turn)
	var walk := Button.new()
	walk.text = "Walk / pause"
	walk.pressed.connect(_toggle_walk)
	controls.add_child(walk)
	_show_stage("Ordinary")
	if "--verify-model" in OS.get_cmdline_user_args():
		await _verify_design()

func _show_stage(stage: String) -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	current_stage = stage
	var scene := load("res://assets/monster/Mother" + stage + ".glb") as PackedScene
	if scene == null:
		push_error("Cannot load mother stage: " + stage)
		get_tree().quit(1)
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	player = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for animation_name in player.get_animation_list():
		if animation_name != "RESET":
			player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
			player.play(animation_name)
			player.advance(0.05)
			player.pause()
			break
	label.text = "Mother design — " + stage
	_frame_camera()

func _frame_camera() -> void:
	var target := Vector3(0, 1.455, 0) if close_up else Vector3(0, 0.82, 0)
	camera.position = target + Vector3(0, 0.015, 0.65 if close_up else 3.1)
	camera.look_at(target)

func _toggle_view() -> void:
	close_up = not close_up
	_frame_camera()

func _rotate(angle: int) -> void:
	model.rotation_degrees.y = angle

func _toggle_walk() -> void:
	if player.is_playing():
		player.pause()
	else:
		player.play()

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://design/monster/" + file_name + ".png")

func _verify_design() -> void:
	for stage in STAGES:
		_show_stage(stage)
		var morph_count := 0
		var skeleton_count := 0
		for node in model.find_children("*", "Skeleton3D", true, false):
			skeleton_count += 1
		for node in model.find_children("*", "MeshInstance3D", true, false):
			morph_count += (node as MeshInstance3D).get_blend_shape_count()
		if skeleton_count == 0 or morph_count < 3:
			push_error("Missing rig or facial shapes: " + stage)
			get_tree().quit(1)
			return
		player.play()
		var before := player.current_animation_position
		await get_tree().create_timer(0.4).timeout
		if player.current_animation_position == before:
			push_error("Walking did not advance: " + stage)
			get_tree().quit(1)
			return
		player.pause()
		player.seek(0.05, true)
		print("DESIGN PASS: ", stage, " / shapes=", morph_count, " / rig=", skeleton_count)
		if DisplayServer.get_name() != "headless":
			close_up = false
			_frame_camera()
			await _capture(stage.to_lower() + "_body")
			close_up = true
			_frame_camera()
			await _capture(stage.to_lower() + "_face")
			if stage in ["Ordinary", "Revealed"]:
				_rotate(90)
				await _capture(stage.to_lower() + "_side")
				_rotate(180)
				await _capture(stage.to_lower() + "_back")
				_rotate(0)
	print("ALL MOTHER DESIGN TESTS PASSED")
	get_tree().quit()
