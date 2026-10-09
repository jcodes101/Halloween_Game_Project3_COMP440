extends Node3D
## Prototype Escape / Environment system for The Familiar.
## Owns door_state, player_location, escape_progress, is_hidden, and player_is_still.
## The Mimic system should read these values and must not write them.

signal environment_state_changed
signal basement_reveal_requested
signal escape_completed
signal player_captured

enum EscapeProgress { FIND_KEY, BASEMENT_READY, BASEMENT_ENTERED, ESCAPED, CAPTURED }

const STILLNESS_TO_LOSE_TARGET := 3.0
const INTERACTION_RANGE := 2.6
const PLAYER_SCENE := preload("res://game/environment/first_person_player.tscn")

var door_state: Dictionary = {"basement_door": "locked"}
var player_location: String = "living_room"
var escape_progress: EscapeProgress = EscapeProgress.FIND_KEY
var is_hidden := false
var player_is_still := false
var has_basement_key := false

var _stillness_time := 0.0
var _interactables: Array[Dictionary] = []
var _prompt: Label
var _status: Label
var _overlay: ColorRect
var _player: CharacterBody3D
var _key_mesh: Node3D
var _basement_door_mesh: Node3D
var _hide_label: Label
var _message_timer: Timer

func _ready() -> void:
	_build_world()
	_build_interface()
	_player = PLAYER_SCENE.instantiate() as CharacterBody3D
	add_child(_player)
	_player.position = Vector3(0, 0.1, 7)
	_player.connect("moved", Callable(self, "_on_player_moved"))
	_player.connect("interact_requested", Callable(self, "_try_interact"))
	_player.connect("escape_requested", Callable(self, "_escape_from_hide"))
	_player.connect("hiding_transition_finished", Callable(self, "_on_hiding_transition_finished"))
	_refresh_state()

func _process(delta: float) -> void:
	if is_hidden and escape_progress != EscapeProgress.ESCAPED and escape_progress != EscapeProgress.CAPTURED:
		if _player.call("is_moving"):
			_stillness_time = 0.0
			_set_still(false)
		else:
			_stillness_time += delta
			_set_still(_stillness_time >= STILLNESS_TO_LOSE_TARGET)
	_update_prompt()

func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11171a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9c2c5")
	environment.ambient_light_energy = 0.48
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52, -28, 0)
	key_light.light_energy = 0.8
	add_child(key_light)

	# Ground floor and basement blockout. The open central passage is the stair route.
	_add_box("GroundFloor", Vector3(0, -0.2, 4), Vector3(18, 0.4, 12), Color("5e5143"))
	_add_box("BasementFloor", Vector3(0, -0.2, -6), Vector3(18, 0.4, 10), Color("383b3b"))
	_add_box("LivingRoomRug", Vector3(-3.5, 0.015, 5), Vector3(5, 0.03, 4), Color("75614d"), false)
	_add_box("BasementStep1", Vector3(0, -0.1, -1.0), Vector3(4.0, 0.25, 1.1), Color("574638"))
	_add_box("BasementStep2", Vector3(0, -0.3, -2.0), Vector3(4.0, 0.25, 1.1), Color("514333"))
	_add_box("BasementStep3", Vector3(0, -0.5, -3.0), Vector3(4.0, 0.25, 1.1), Color("493e32"))

	# Perimeter walls; the player remains inside a compact house footprint.
	_add_box("WestWall", Vector3(-9, 1.5, 0), Vector3(0.4, 3, 21), Color("887c68"))
	_add_box("EastWall", Vector3(9, 1.5, 0), Vector3(0.4, 3, 21), Color("887c68"))
	_add_box("SouthWall", Vector3(0, 1.5, 10.5), Vector3(18, 3, 0.4), Color("887c68"))
	_add_box("NorthWall", Vector3(0, 1.5, -10.5), Vector3(18, 3, 0.4), Color("504f4b"))
	# Short partitions create readable room boundaries but leave broad walkable openings.
	_add_box("LivingPartitionWest", Vector3(-5.5, 1.5, 0), Vector3(7, 3, 0.3), Color("766b5c"))
	_add_box("LivingPartitionEast", Vector3(5.5, 1.5, 0), Vector3(7, 3, 0.3), Color("766b5c"))
	_add_box("BasementPartitionWest", Vector3(-5.5, 1.5, -6), Vector3(7, 3, 0.3), Color("48494a"))
	_add_box("BasementPartitionEast", Vector3(5.5, 1.5, -6), Vector3(7, 3, 0.3), Color("48494a"))

	# Furniture makes the hiding affordances and pathing legible.
	_add_box("Sofa", Vector3(-5.1, 0.7, 5.4), Vector3(2.8, 1.4, 1.0), Color("53605c"))
	# Raised bed frame leaves a crawl space for the configured under-bed hiding spot.
	for leg_x in [-1.42, 1.42]:
		for leg_z in [-1.02, 1.02]:
			_add_box("BedLeg", Vector3(5.0 + leg_x, 0.43, 5.2 + leg_z), Vector3(0.18, 0.86, 0.18), Color("57483e"))
	_add_box("BedMattress", Vector3(5.0, 0.98, 5.2), Vector3(3.0, 0.2, 2.2), Color("b8aa8f"), false)
	_add_box("BasementCrates", Vector3(-5.1, 0.65, -6.2), Vector3(2.2, 1.3, 1.5), Color("594a37"))
	_add_box("BasementShelf", Vector3(5.3, 1.0, -6.4), Vector3(2.0, 2.0, 0.55), Color("51483b"))

	_key_mesh = _make_key(Vector3(-3.5, 1.0, 5.0))
	add_child(_key_mesh)
	_register_interactable("Basement key", "key", _key_mesh.global_position, "E  Pick up basement key")

	_basement_door_mesh = _make_door()
	add_child(_basement_door_mesh)
	_register_interactable("Basement door", "basement_door", Vector3(0, 1.0, 0.6), "E  Unlock basement door")

	_register_interactable("Hide behind sofa", "hide", Vector3(-3.0, 1.0, 5.4), "E  Hide behind sofa", {
		"entry": Vector3(-3.0, 0.0, 5.4),
		"path": [Vector3(-3.0, 0.0, 4.35), Vector3(-5.1, 0.0, 4.25)],
		"exit_yaw": PI,
		"hidden_yaw": -PI / 2.0,
		"crouch_height": 0.95,
		"crouch_camera_y": 0.78,
	})
	_register_interactable("Hide under bed", "hide", Vector3(5.0, 1.0, 6.9), "E  Hide under bed", {
		"entry": Vector3(5.0, 0.0, 6.9),
		"path": [Vector3(5.0, 0.0, 5.2)],
		"exit_yaw": 0.0,
		"hidden_yaw": 0.0,
		"crouch_height": 0.72,
		"crouch_camera_y": 0.53,
	})
	_register_interactable("Hide among crates", "hide", Vector3(-2.9, 1.0, -4.8), "E  Hide among crates", {
		"entry": Vector3(-2.9, 0.0, -4.8),
		"path": [Vector3(-3.3, 0.0, -4.8)],
		"exit_yaw": PI,
		"hidden_yaw": 0.0,
		"crouch_height": 0.95,
		"crouch_camera_y": 0.78,
	})
	_register_interactable("Basement exit", "exit", Vector3(0, 1.0, -9.1), "E  Escape")
	_add_box("ExitGlow", Vector3(0, 1.3, -9.65), Vector3(2.2, 2.4, 0.15), Color("627262"), false)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(18, 18)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color("f0e7d2"))
	layer.add_child(_status)
	_prompt = Label.new()
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 70
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color("fff4d8"))
	layer.add_child(_prompt)
	_hide_label = Label.new()
	_hide_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hide_label.position = Vector2(-100, 45)
	_hide_label.add_theme_font_size_override("font_size", 18)
	_hide_label.add_theme_color_override("font_color", Color("d3d9cc"))
	layer.add_child(_hide_label)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.025, 0.03, 0.82)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	var ending := Label.new()
	ending.name = "EndingText"
	ending.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ending.position = Vector2(-230, -75)
	ending.custom_minimum_size = Vector2(460, 150)
	ending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending.add_theme_font_size_override("font_size", 32)
	ending.add_theme_color_override("font_color", Color("f3e8d5"))
	ending.text = ""
	_overlay.add_child(ending)
	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(_clear_message)
	add_child(_message_timer)

func _make_door() -> Node3D:
	var door := Node3D.new()
	door.name = "BasementDoor"
	var frame_color := Color("49392e")
	var slab := _make_box_mesh(Vector3(3.8, 2.7, 0.28), Color("60462f"))
	slab.name = "DoorSlab"
	door.add_child(slab)
	slab.position = Vector3(0, 1.35, 0)
	var lintel := _make_box_mesh(Vector3(4.2, 0.25, 0.45), frame_color)
	door.add_child(lintel)
	lintel.position = Vector3(0, 2.85, 0)
	door.position = Vector3(0, 0, -0.1)
	door.set_meta("slab", slab)
	return door

func _make_key(at: Vector3) -> Node3D:
	var key_root := Node3D.new()
	key_root.name = "BasementKey"
	key_root.position = at
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.11
	torus.outer_radius = 0.16
	ring.mesh = torus
	ring.material_override = _material(Color("d2a845"))
	key_root.add_child(ring)
	var stem := _make_box_mesh(Vector3(0.42, 0.07, 0.07), Color("d2a845"), false)
	key_root.add_child(stem)
	stem.position = Vector3(0.27, 0, 0)
	return key_root

func _add_box(node_name: String, at: Vector3, size: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var box := _make_box_mesh(size, color, solid)
	box.name = node_name
	add_child(box)
	box.position = at
	return box

func _make_box_mesh(size: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.material_override = _material(color)
	if solid:
		var body := StaticBody3D.new()
		body.name = "CollisionBody"
		mesh_node.add_child(body)
		var collision := CollisionShape3D.new()
		var collision_shape := BoxShape3D.new()
		collision_shape.size = size
		collision.shape = collision_shape
		body.add_child(collision)
	return mesh_node

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material

func _register_interactable(title: String, kind: String, at: Vector3, prompt: String, hide_config: Dictionary = {}) -> void:
	_interactables.append({"title": title, "kind": kind, "position": at, "prompt": prompt, "hide_config": hide_config})

func _try_interact() -> void:
	if is_hidden:
		return
	var target := _nearest_interactable()
	if target.is_empty():
		return
	match str(target.kind):
		"key":
			if has_basement_key:
				return
			has_basement_key = true
			_key_mesh.visible = false
			escape_progress = EscapeProgress.BASEMENT_READY
			_show_message("Basement key collected. The stairs lead down.")
		"basement_door":
			if door_state["basement_door"] == "open":
				return
			if not has_basement_key:
				_show_message("Locked. Find the basement key.")
				return
			door_state["basement_door"] = "open"
			var slab: MeshInstance3D = _basement_door_mesh.get_meta("slab")
			slab.visible = false
			# Remove the panel's physics body as well as hiding its mesh. This makes
			# opening the route independent of deferred shape-disable timing.
			var door_body := slab.get_node("CollisionBody") as StaticBody3D
			door_body.collision_layer = 0
			door_body.collision_mask = 0
			door_body.queue_free()
			escape_progress = EscapeProgress.BASEMENT_ENTERED
			basement_reveal_requested.emit()
			_show_message("The basement door opens. Something moves below.")
		"hide":
			var hide_config: Dictionary = target.hide_config
			_player.call("begin_hiding", hide_config)
		"exit":
			if escape_progress != EscapeProgress.BASEMENT_ENTERED:
				_show_message("The exit is below. Unlock the basement door first.")
				return
			_complete_escape()
	_refresh_state()
	environment_state_changed.emit()

func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INTERACTION_RANGE
	for entry in _interactables:
		if entry.kind == "key" and has_basement_key:
			continue
		if entry.kind == "basement_door" and door_state["basement_door"] == "open":
			continue
		var distance: float = _player.global_position.distance_to(entry.position)
		if distance < best_distance:
			best = entry
			best_distance = distance
	return best

func _update_prompt() -> void:
	if is_hidden:
		_prompt.text = "E  Leave hiding place"
		_hide_label.text = "Stay still  %.1f / 3.0 s" % minf(_stillness_time, STILLNESS_TO_LOSE_TARGET)
		return
	_hide_label.text = ""
	var target := _nearest_interactable()
	_prompt.text = str(target.prompt) if not target.is_empty() else "WASD move   Mouse look   E interact"

func _escape_from_hide() -> void:
	if not is_hidden or _player.call("is_transitioning"):
		return
	_player.call("begin_unhiding")

func _on_hiding_transition_finished(entered: bool, succeeded: bool) -> void:
	if not succeeded:
		_show_message("No clear path into that hiding spot. Move closer and try again.")
		return
	if entered:
		is_hidden = true
		player_is_still = false
		_stillness_time = 0.0
		_player.call("set_hidden", true)
		_show_message("Hidden. Stay still to lose the mimic.")
	else:
		_leave_hide()

func _leave_hide() -> void:
	is_hidden = false
	player_is_still = false
	_stillness_time = 0.0
	_player.call("set_hidden", false)
	_refresh_state()
	environment_state_changed.emit()

func _on_player_moved() -> void:
	if is_hidden:
		_stillness_time = 0.0
		_set_still(false)
		_player.call("begin_unhiding")
		return
	var z := _player.global_position.z
	var x := _player.global_position.x
	var next_location := "living_room" if z > 1.0 else ("hallway" if z >= -0.8 else "basement")
	if absf(x) > 7.4:
		next_location = "hallway" if z > -0.8 else "basement"
	if next_location != player_location:
		player_location = next_location
		_refresh_state()
		environment_state_changed.emit()

func _set_still(value: bool) -> void:
	if player_is_still == value:
		return
	player_is_still = value
	environment_state_changed.emit()

func _refresh_state() -> void:
	if _status == null:
		return
	var progress_text := "Find the basement key"
	match escape_progress:
		EscapeProgress.BASEMENT_READY: progress_text = "Unlock the basement door"
		EscapeProgress.BASEMENT_ENTERED: progress_text = "Reach the basement exit"
		EscapeProgress.ESCAPED: progress_text = "Escaped"
		EscapeProgress.CAPTURED: progress_text = "Captured"
	_status.text = "THE FAMILIAR\nLocation: %s\nObjective: %s" % [player_location.replace("_", " ").capitalize(), progress_text]

func _show_message(text: String) -> void:
	if _status == null:
		return
	_status.text = "THE FAMILIAR\n" + text
	_message_timer.start(2.5)

func _clear_message() -> void:
	if escape_progress == EscapeProgress.ESCAPED or escape_progress == EscapeProgress.CAPTURED:
		return
	_refresh_state()

func _complete_escape() -> void:
	escape_progress = EscapeProgress.ESCAPED
	_overlay.visible = true
	var ending := _overlay.get_node("EndingText") as Label
	ending.text = "YOU ESCAPED\n\nPress R to play again"
	ending.add_theme_font_size_override("font_size", 34)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	escape_completed.emit()
	_refresh_state()

func mark_player_captured() -> void:
	if escape_progress == EscapeProgress.ESCAPED or escape_progress == EscapeProgress.CAPTURED:
		return
	escape_progress = EscapeProgress.CAPTURED
	_player.call("cancel_hiding_transition")
	_overlay.visible = true
	var ending := _overlay.get_node("EndingText") as Label
	ending.text = "THE MIMIC FOUND YOU\n\nPress R to try again"
	ending.add_theme_font_size_override("font_size", 34)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	player_captured.emit()
	_refresh_state()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
