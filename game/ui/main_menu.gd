extends Control
## Front-end shell. Gameplay is instantiated only after the player chooses New Game.

const GAME_SCENE: PackedScene = preload("res://game/main.tscn")
const TYPOGRAPHY = preload("res://game/ui/horror_typography.gd")
const UI_STYLE = preload("res://game/ui/horror_ui_style.gd")
const HOUSE_BACKDROP = preload("res://game/ui/menu_house_backdrop.gd")
const VIGNETTE_SHADER = preload("res://game/ui/cinematic_vignette.gdshader")
var settings_path := "user://familiar_settings.cfg"
const PAPER := Color("e8e0d1")
const MUTED := Color("aaa397")
const AMBER := Color("bd9860")
const CRIMSON := Color("912d33")
const PANEL := Color(0.012, 0.013, 0.017, 0.80)

var _settings := ConfigFile.new()
var _game: Node
var _body: VBoxContainer
var _shell_panel: PanelContainer
var _main_options: VBoxContainer
var _subtitle: Label
var _focus_return: Button
var _active_page := ""
var _backdrop: SubViewportContainer
var _body_fade_active := false
var _content_fade_active := false

func _ready() -> void:
	name = "MainMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	theme = TYPOGRAPHY.theme()
	var verify_frontend := "--verify-frontend" in OS.get_cmdline_user_args()
	if verify_frontend:
		settings_path = "res://.godot/frontend_verification.cfg"
	_ensure_audio_buses()
	_settings.load(settings_path)
	_apply_global_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_shell()
	_show_home()
	if verify_frontend:
		var suite := preload("res://tests/ui/verify_frontend.gd").new()
		suite.name = "FrontEndVerification"
		add_child(suite)
		suite.call_deferred("run", self)

func _input(event: InputEvent) -> void:
	if _game != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not _active_page.is_empty():
			_show_home()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and _active_page == "":
			_start_new_game()
			get_viewport().set_input_as_handled()

func _build_shell() -> void:
	_backdrop = HOUSE_BACKDROP.new()
	add_child(_backdrop)
	var vignette := ColorRect.new()
	vignette.name = "CinematicVignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = VIGNETTE_SHADER
	vignette_material.set_shader_parameter("strength", 0.80)
	vignette_material.set_shader_parameter("left_fade", 0.76)
	vignette.material = vignette_material
	add_child(vignette)
	var panel := PanelContainer.new()
	_shell_panel = panel
	panel.name = "MainMenuEditorialPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(0.35, 0.13, 0.15, 0.60)
	style.border_width_right = 1
	style.content_margin_left = 38
	style.content_margin_right = 30
	style.content_margin_top = 32
	style.content_margin_bottom = 27
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margins := MarginContainer.new()
	panel.add_child(margins)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 9)
	margins.add_child(_body)
	var title_group := VBoxContainer.new()
	title_group.add_theme_constant_override("separation", 0)
	_body.add_child(title_group)
	var title := Label.new()
	title.name = "TitlePrefix"
	title.text = "THE"
	title.custom_minimum_size.y = 34
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", PAPER)
	title.add_theme_constant_override("outline_size", 1)
	title_group.add_child(title)
	var wordmark := Label.new()
	wordmark.name = "FamiliarWordmark"
	wordmark.text = "FAMILIAR"
	wordmark.add_theme_font_size_override("font_size", 51)
	wordmark.add_theme_color_override("font_color", Color("a7353a"))
	wordmark.add_theme_constant_override("outline_size", 1)
	wordmark.add_theme_color_override("font_outline_color", Color("180c0d"))
	title_group.add_child(wordmark)
	var title_rule := ColorRect.new()
	title_rule.custom_minimum_size = Vector2(236, 2)
	title_rule.color = CRIMSON
	title_group.add_child(title_rule)
	_subtitle = Label.new()
	_subtitle.text = "SOME PRESENCES NEVER LEAVE..."
	_subtitle.add_theme_font_size_override("font_size", 10)
	_subtitle.add_theme_color_override("font_color", Color("aaa397"))
	_subtitle.add_theme_constant_override("outline_size", 0)
	_body.add_child(_subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	_body.add_child(spacer)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.36, 0.15, 0.17, 0.55)
	_body.add_child(divider)
	_main_options = VBoxContainer.new()
	_main_options.add_theme_constant_override("separation", 5)
	_main_options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_main_options)
	var footer := Label.new()
	footer.text = "SURVIVE.   HIDE.   ESCAPE."
	footer.add_theme_font_size_override("font_size", 9)
	footer.add_theme_color_override("font_color", Color("89837a"))
	_body.add_child(footer)
	_layout_shell()
	resized.connect(_layout_shell)
	_body.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_body_fade_active = true

func _process(delta: float) -> void:
	if not visible:
		return
	if _body_fade_active and is_instance_valid(_body):
		var body_alpha := minf(1.0, _body.modulate.a + delta * 3.0)
		_body.modulate = Color(1.0, 1.0, 1.0, body_alpha)
		_body_fade_active = body_alpha < 1.0
	if _content_fade_active and is_instance_valid(_main_options):
		var content_alpha := minf(1.0, _main_options.modulate.a + delta * 3.0)
		_main_options.modulate = Color(1.0, 1.0, 1.0, content_alpha)
		_content_fade_active = content_alpha < 1.0

func _layout_shell() -> void:
	if _shell_panel == null or size.x < 100.0 or size.y < 100.0:
		return
	var viewport_size := size
	var panel_width := clampf(viewport_size.x * 0.45, 380.0, 540.0)
	var margin_x := maxf(24.0, viewport_size.x * 0.055)
	var margin_y := maxf(18.0, viewport_size.y * 0.055)
	_shell_panel.position = Vector2(margin_x, margin_y)
	_shell_panel.size = Vector2(minf(panel_width, viewport_size.x - margin_x * 2.0), maxf(400.0, viewport_size.y - margin_y * 2.0))

func _show_home() -> void:
	_active_page = ""
	_subtitle.text = "SOME PRESENCES NEVER LEAVE..."
	_clear_main_options()
	_add_menu_button("NEW GAME", _start_new_game)
	var continue_button := _add_menu_button("CONTINUE", Callable())
	continue_button.disabled = true
	continue_button.tooltip_text = "Continue is unavailable because this game has no progress save system."
	continue_button.add_theme_color_override("font_disabled_color", Color("625f59"))
	_add_menu_button("SETTINGS", func(): _show_page("SETTINGS"))
	_add_menu_button("CONTROLS", func(): _show_page("CONTROLS"))
	_add_menu_button("CREDITS", func(): _show_page("CREDITS"))
	_add_menu_button("QUIT GAME", func(): get_tree().quit())
	var first := _main_options.get_child(0) as Button
	first.grab_focus()
	_fade_main_content()

func _show_page(page: String) -> void:
	_active_page = page
	_clear_main_options()
	_subtitle.text = page
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI_STYLE.style_scroll_container(scroll)
	_main_options.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	match page:
		"SETTINGS": _populate_settings(content)
		"CONTROLS": _populate_controls(content)
		"CREDITS": _populate_credits(content)
	var back := _add_menu_button("BACK", _show_home)
	back.grab_focus()
	_fade_main_content()

func _fade_main_content() -> void:
	if not is_instance_valid(_main_options):
		return
	_main_options.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_content_fade_active = true

func _populate_settings(box: VBoxContainer) -> void:
	_add_section(box, "GAMEPLAY")
	_add_slider(box, "Mouse sensitivity", "gameplay", "sensitivity", 0.5, 4.0, 0.01, float(_settings.get_value("gameplay", "sensitivity", 1.0)), "×")
	_add_slider(box, "VHS intensity", "gameplay", "vhs", 0.0, 1.5, 0.01, float(_settings.get_value("gameplay", "vhs", 1.0)), "×")
	_add_slider(box, "Camera motion", "gameplay", "camera_motion", 0.0, 1.0, 0.01, float(_settings.get_value("gameplay", "camera_motion", 1.0)), "%", 100.0)
	_add_section(box, "DISPLAY")
	var full := CheckButton.new()
	full.text = "Fullscreen"
	full.button_pressed = bool(_settings.get_value("display", "fullscreen", false))
	full.toggled.connect(func(on: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
		_settings.set_value("display", "fullscreen", on)
		_save_settings()
	)
	_style_control(full)
	box.add_child(full)
	_add_section(box, "AUDIO")
	for bus in ["Master", "Music", "Ambience", "SFX"]:
		_add_slider(box, bus, "audio", bus, 0.0, 100.0, 1.0, _bus_percent(bus), "%")

func _populate_controls(box: VBoxContainer) -> void:
	_add_section(box, "MOVEMENT")
	for binding in [["move_forward","Move forward"],["move_backward","Move backward"],["move_left","Move left"],["move_right","Move right"],["sprint","Sprint"]]:
		_add_control_row(box, _action_keys(binding[0]), binding[1])
	_add_control_row(box, "Mouse", "Look around")
	_add_control_row(box, "Space", "Jump when available")
	_add_section(box, "INTERACTION")
	_add_control_row(box, "E", "Interact / hide / leave")
	_add_control_row(box, _action_keys("flashlight_toggle"), "Toggle flashlight")
	_add_control_row(box, "Tab", "Pause menu")
	_add_control_row(box, "H", "Open Controls")
	_add_control_row(box, "On-screen keys", "Follow the sequence during a capture")

func _populate_credits(box: VBoxContainer) -> void:
	_add_section(box, "PROJECT")
	_add_copy(box, "The Familiar\nCOMP440 Game Design class project\nGodot 4.7.2")
	_add_section(box, "ASSET ATTRIBUTION")
	_add_copy(box, "The environment and furniture asset manifest identifies Kenney Building Kit and Furniture Kit assets as CC0. See assets/environment/manifest.json for the itemized source information.")
	_add_section(box, "AUDIO & MUSIC")
	_add_copy(box, "Existing sound assets are included with the project. The dynamic soundtrack accepts original or properly licensed tracks; no soundtrack is bundled. See assets/audio/music/README.md for setup details.")
	_add_copy(box, "Contributor names and additional licenses are not recorded in the project files reviewed for this menu.", MUTED)

func _add_slider(box: VBoxContainer, title: String, section: String, key: String, low: float, high: float, step: float, initial: float, suffix: String, multiplier: float = 1.0) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var top := HBoxContainer.new()
	var label := Label.new()
	label.text = title.to_upper()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", PAPER)
	top.add_child(label)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 58
	value.add_theme_color_override("font_color", AMBER)
	top.add_child(value)
	row.add_child(top)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = initial
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size.y = 24
	_style_control(slider)
	UI_STYLE.style_slider(slider)
	row.add_child(slider)
	box.add_child(row)
	var update := func(raw: float) -> void:
		value.text = ("%d" % roundi(raw * multiplier) if multiplier != 1.0 else "%.2f" % raw) + suffix
		_settings.set_value(section, key, raw)
		_apply_one_setting(section, key, raw)
		_save_settings()
	slider.value_changed.connect(update)
	update.call(initial)

func _apply_one_setting(section: String, key: String, value: float) -> void:
	if section == "audio":
		var index := AudioServer.get_bus_index(key)
		if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.0001)))
	elif section == "gameplay":
		# The active run reads these same persisted values when its scene is created.
		pass

func _apply_global_settings() -> void:
	for bus in ["Master", "Music", "Ambience", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		var value := float(_settings.get_value("audio", bus, 100.0))
		if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.0001)))
	if bool(_settings.get_value("display", "fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _ensure_audio_buses() -> void:
	for bus in ["Music", "Ambience", "SFX"]:
		if AudioServer.get_bus_index(bus) >= 0: continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")

func _bus_percent(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	return float(_settings.get_value("audio", bus, 100.0)) if index < 0 else db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0

func _save_settings() -> void:
	_settings.save(settings_path)

func _start_new_game() -> void:
	_start_run(true)

func _start_run(show_story: bool) -> void:
	if _backdrop != null:
		_backdrop.set_active(false)
	if is_instance_valid(_game):
		_game.queue_free()
	_game = GAME_SCENE.instantiate()
	_game.set("show_story_intro", show_story)
	_game.set("embedded_in_menu", true)
	_game.name = "ActiveGameplayRun"
	add_child(_game)
	_main_options.get_parent().visible = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func restart_embedded_game() -> void:
	get_tree().paused = false
	_start_run(false)

func return_to_menu() -> void:
	_return_to_menu()

func _return_to_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(_game):
		_game.queue_free()
	_game = null
	if _backdrop != null:
		_backdrop.set_active(true)
	visible = true
	_main_options.get_parent().visible = true
	_show_home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _clear_main_options() -> void:
	for child in _main_options.get_children():
		_main_options.remove_child(child)
		child.queue_free()

func _add_menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 43)
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_focus_color", PAPER)
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02,0.015,0.017,0.12)
	normal.border_color = Color(0.30,0.11,0.13,0.48)
	normal.border_width_bottom = 1
	normal.content_margin_left = 13
	normal.content_margin_right = 13
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(0.20,0.025,0.035,0.52)
	selected.border_color = CRIMSON
	selected.border_width_left = 2
	selected.border_width_bottom = 1
	selected.content_margin_left = 13
	selected.content_margin_right = 13
	selected.content_margin_top = 7
	selected.content_margin_bottom = 7
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", selected)
	button.add_theme_stylebox_override("focus", selected)
	button.add_theme_stylebox_override("pressed", selected)
	button.mouse_entered.connect(_animate_button.bind(button, true))
	button.mouse_exited.connect(_animate_button.bind(button, false))
	if callback.is_valid(): button.pressed.connect(callback)
	_main_options.add_child(button)
	return button

func _animate_button(button: Button, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var tween := create_tween()
	tween.tween_property(button, "modulate", Color(1.0, 0.88, 0.86) if hovered else Color.WHITE, 0.12).set_trans(Tween.TRANS_SINE)

func _add_section(box: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", AMBER)
	box.add_child(label)

func _add_copy(box: VBoxContainer, text_value: String, color: Color = PAPER) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	box.add_child(label)

func _add_control_row(box: VBoxContainer, keys: String, action: String) -> void:
	var row := HBoxContainer.new()
	var key_label := Label.new()
	key_label.text = keys
	key_label.custom_minimum_size.x = 112
	key_label.add_theme_color_override("font_color", AMBER)
	row.add_child(key_label)
	var action_label := Label.new()
	action_label.text = action
	action_label.add_theme_color_override("font_color", PAPER)
	row.add_child(action_label)
	box.add_child(row)

func _action_keys(action: String) -> String:
	if not InputMap.has_action(action): return "—"
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var label := OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
			if not names.has(label): names.append(label)
	return " / ".join(names) if not names.is_empty() else "—"

func _style_control(control: Control) -> void:
	control.add_theme_color_override("font_color", PAPER)
	control.add_theme_color_override("font_hover_color", AMBER)
	control.add_theme_color_override("font_focus_color", AMBER)
