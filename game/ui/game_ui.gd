extends CanvasLayer
## Shared gameplay HUD, pause menu, settings and ending presentation.

signal survival_qte_finished(escaped: bool)
signal survival_qte_started
signal wake_up_requested
signal wake_up_finished
signal restart_requested
signal main_menu_requested

var settings_path := "user://familiar_settings.cfg"
const INK := Color("171716")
const PANEL := Color(0.08, 0.08, 0.075, 0.97)
const PAPER := Color("e8e0d1")
const MUTED := Color("aaa397")
const AMBER := Color("bd9860")
const RED := Color("a53b42")
const CRIMSON := Color("84262d")
const HORROR_TYPOGRAPHY = preload("res://game/ui/horror_typography.gd")
const UI_STYLE = preload("res://game/ui/horror_ui_style.gd")

var game: Node
var environment: Node
var player: CharacterBody3D
var flashlight: Node
var vhs: Node
var menu_open := false
var ending_active := false
var intro_active := false
var wake_up_active := false
var confirmation_active := false
var _confirmation_action := ""
var _intro_page := 0
var _intro_layer: Control
var _intro_title: Label
var _intro_copy: Label
var _intro_continue: Button
var _intro_fade: Tween
var _wake_layer: Control
var _wake_overlay: ColorRect
var _wake_skip_button: Button
var _wake_tween: Tween
var selected_tab := "OBJECTIVE"
var debug_enabled := false
var location_seen := ""
var location_timer := 0.0
var _notification_timer: SceneTreeTimer
var _notification_serial := 0
var _root: Control
var _gameplay_hud: Control
var _menu: Control
var _menu_content: VBoxContainer
var _menu_scroll: ScrollContainer
var _menu_panel: PanelContainer
var _menu_title: Label
var _menu_dim: ColorRect
var _menu_tween: Tween
var _menu_tabs: HBoxContainer
var _menu_footer: HBoxContainer
var _qte_layer: Control
var _qte_prompt: Label
var _qte_feedback: Label
var _qte_timer_label: Label
var _qte_progress: ProgressBar
var qte_active := false
var _qte_remaining := 0.0
var _qte_duration := 0.0
@export_group("Capture QTE")
@export_range(1, 6, 1) var qte_sequence_length := 3
@export var qte_key_pool: Array[int] = [KEY_Q, KEY_E, KEY_R, KEY_F]
@export var qte_random_seed := 0
var _qte_sequence: Array[int] = []
var _previous_qte_sequence: Array[int] = []
var _qte_rng := RandomNumberGenerator.new()
var _qte_index := 0
var _battery_bar: ProgressBar
var _battery_text: Label
var _location_label: Label
var _objective_label: Label
var _interaction_label: Label
var _hide_panel: VBoxContainer
var _hide_bar: ProgressBar
var _notification: PanelContainer
var _notification_label: Label
var _ending_panel: Control
var _ending_label: Label
var _ending_subtitle: Label
var _ending_retry_button: Button
var _confirmation_layer: Control
var _confirmation_title: Label
var _confirmation_message: Label
var _confirmation_cancel: Button
var debug_label: Label
var _setting_rows: Array[Dictionary] = []
var _settings := ConfigFile.new()

func setup(owner: Node) -> void:
	game = owner
	environment = owner.environment
	player = owner.player
	flashlight = player.get_node_or_null("FlashlightController")
	vhs = owner.vhs_effect
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_settings.load(settings_path)
	_apply_saved_settings()
	_build_ui()
	_initialize_qte_rng()
	if environment.has_signal("hud_notification"):
		environment.hud_notification.connect(show_notification)
	if environment.has_signal("environment_state_changed"):
		environment.environment_state_changed.connect(_refresh_menu_data)
	if environment.has_signal("escape_completed"):
		environment.escape_completed.connect(func(): _show_ending(true))
	if environment.has_signal("player_captured"):
		environment.player_captured.connect(func(): _show_ending(false))
	if flashlight != null:
		flashlight.battery_level_changed.connect(_refresh_battery)
		flashlight.flashlight_switched_on.connect(_refresh_battery)
		flashlight.flashlight_switched_off.connect(_refresh_battery)
	_refresh_battery()
	_refresh_hud()

func _process(delta: float) -> void:
	if not menu_open and not ending_active:
		_refresh_hud()
	if location_timer > 0.0:
		location_timer = maxf(0.0, location_timer - delta)
		_location_label.modulate.a = minf(1.0, location_timer * 1.2)
	if debug_enabled and game != null:
		_update_debug_panel()
	if qte_active and not menu_open and not get_tree().paused:
		_qte_remaining = maxf(0.0, _qte_remaining - delta)
		_qte_progress.value = 100.0 * _qte_remaining / maxf(0.01, _qte_duration)
		_qte_timer_label.text = "%.1f SECONDS" % _qte_remaining
		if _qte_remaining <= 0.0:
			_finish_survival_qte(false)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if ending_active:
		get_viewport().set_input_as_handled()
		return
	if wake_up_active:
		if key.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			_skip_wake_up()
		get_viewport().set_input_as_handled()
		return
	if intro_active:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_advance_intro()
		elif key.keycode == KEY_ESCAPE:
			_finish_intro()
		get_viewport().set_input_as_handled()
		return
	if menu_open and key.keycode == KEY_ESCAPE:
		if confirmation_active:
			_cancel_confirmation()
		else:
			close_menu()
		get_viewport().set_input_as_handled()
		return
	if menu_open and key.keycode == KEY_R:
		if not confirmation_active and not qte_active:
			_show_confirmation("restart")
		get_viewport().set_input_as_handled()
		return
	if qte_active and not menu_open and key.keycode in [KEY_TAB, KEY_ESCAPE]:
		open_menu("OBJECTIVE")
		get_viewport().set_input_as_handled()
		return
	if qte_active and not menu_open:
		if key.keycode == _qte_sequence[_qte_index]:
			_qte_index += 1
			_qte_feedback.text = "GOOD — KEEP GOING"
			if _qte_index >= _qte_sequence.size():
				_finish_survival_qte(true)
			else:
				_update_qte_prompt()
		else:
			_qte_feedback.text = "WRONG KEY — FOLLOW THE SEQUENCE"
		get_viewport().set_input_as_handled()
		return
	if qte_active and menu_open and key.keycode in qte_key_pool:
		get_viewport().set_input_as_handled()
		return
	if menu_open:
		if confirmation_active:
			if key.keycode == KEY_ESCAPE:
				_cancel_confirmation()
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_R:
			_show_confirmation("restart")
		elif key.keycode in [KEY_TAB, KEY_ESCAPE] or (key.keycode == KEY_H and selected_tab == "CONTROLS"):
			close_menu()
		elif key.keycode == KEY_H:
			_select_tab("CONTROLS")
		get_viewport().set_input_as_handled()
		return
	if key.keycode in [KEY_TAB, KEY_ESCAPE]:
		open_menu("OBJECTIVE")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_H:
		open_menu("CONTROLS")
		get_viewport().set_input_as_handled()

func open_menu(tab: String = "OBJECTIVE") -> void:
	if ending_active or menu_open:
		return
	menu_open = true
	get_tree().paused = true
	_gameplay_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu.visible = true
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _menu_tween != null and _menu_tween.is_running(): _menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_property(_menu, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_select_tab(tab)

func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	confirmation_active = false
	_confirmation_layer.visible = false
	get_tree().paused = false
	_gameplay_hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player != null:
		player.velocity = Vector3.ZERO
	if _menu_tween != null and _menu_tween.is_running(): _menu_tween.kill()
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_tween = create_tween()
	_menu_tween.tween_property(_menu, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_menu_tween.tween_callback(func():
		if not menu_open:
			_menu.visible = false
			_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	)

func show_notification(text: String) -> void:
	if _notification == null or ending_active:
		return
	_notification_serial += 1
	var serial := _notification_serial
	_notification_label.text = text
	_notification.visible = true
	_notification.modulate = Color.WHITE
	_notification_timer = get_tree().create_timer(3.0, true, false, true)
	_notification_timer.timeout.connect(func():
		if serial == _notification_serial and is_instance_valid(_notification):
			var tween := create_tween()
			tween.tween_property(_notification, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
			tween.tween_callback(func(): _notification.visible = false)
	)

func show_caption(text: String) -> void:
	show_notification(text)

func _refresh_battery(_value: float = 0.0) -> void:
	if _battery_bar == null or flashlight == null:
		return
	var charge := float(flashlight.get("battery_percent"))
	var active := bool(flashlight.get("flashlight_is_on"))
	_battery_bar.value = charge
	_battery_text.text = "%02d%%  %s" % [roundi(charge), "ON" if active else "OFF"]
	var tone := AMBER if charge <= 25.0 else PAPER
	if charge <= 10.0: tone = RED
	_battery_bar.add_theme_stylebox_override("fill", _style(tone, 5, 0))
	_battery_text.add_theme_color_override("font_color", tone if active else MUTED)
	_battery_bar.modulate.a = 1.0 if active else 0.58

func _refresh_hud() -> void:
	if not is_instance_valid(environment): return
	var location := str(environment.get("player_location"))
	if location != location_seen:
		location_seen = location
		_location_label.text = _human_location(location)
		location_timer = 3.2
		_location_label.modulate.a = 1.0
	var prompt := str(environment.call("current_interaction_prompt")) if environment.has_method("current_interaction_prompt") else ""
	var hidden := bool(environment.get("is_hidden"))
	_hide_panel.visible = hidden
	if hidden:
		_objective_label.visible = false
		_interaction_label.text = "[E]  LEAVE HIDING PLACE"
		_hide_bar.value = float(environment.call("stillness_progress")) * 100.0
	else:
		var objective := str(environment.call("objective_text")) if environment.has_method("objective_text") else ""
		if prompt != "":
			_interaction_label.text = prompt.to_upper()
			_objective_label.visible = false
		else:
			_objective_label.text = "CURRENT OBJECTIVE\n" + objective
			_objective_label.visible = true
			_interaction_label.text = ""
	_refresh_battery()
	var state: int = int(environment.get("escape_progress"))
	if state in [3,4] and not ending_active:
		_show_ending(state == 3)

func _show_ending(escaped: bool) -> void:
	if ending_active: return
	ending_active = true
	intro_active = false
	wake_up_active = false
	confirmation_active = false
	qte_active = false
	_intro_layer.visible = false
	_qte_layer.visible = false
	_wake_layer.visible = false
	_confirmation_layer.visible = false
	menu_open = false
	get_tree().paused = false
	_menu.visible = false
	for child in _root.get_children():
		if child != _ending_panel:
			child.visible = false
	_ending_panel.visible = true
	_ending_label.text = "YOU ESCAPED" if escaped else "GAME OVER"
	_ending_label.add_theme_color_override("font_color", AMBER if escaped else RED)
	_ending_subtitle.text = "The house falls quiet. For now." if escaped else "The Familiar has found you..."
	_ending_retry_button.text = "PLAY AGAIN" if escaped else "TRY AGAIN"
	_ending_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_ending_retry_button.grab_focus()
	var ending_fade := create_tween()
	ending_fade.tween_property(_ending_panel, "modulate", Color.WHITE, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SharedGameUI"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = HORROR_TYPOGRAPHY.theme()
	add_child(_root)
	_build_game_hud()
	_build_qte()
	_build_intro()
	_build_menu()
	_build_ending()
	_build_wake_up()
	_qte_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_layer.focus_mode = Control.FOCUS_NONE
	_qte_layer.show_behind_parent = false
	_qte_layer.z_index = 20
	if debug_enabled:
		debug_label = _label("", 11, AMBER)
		debug_label.position = Vector2(28, 100)
		_gameplay_hud.add_child(debug_label)

func _build_qte() -> void:
	_qte_layer = Control.new()
	_qte_layer.name = "SurvivalEncounterOverlay"
	_qte_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_qte_layer.visible = false
	_qte_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_layer.focus_mode = Control.FOCUS_NONE
	_root.add_child(_qte_layer)
	var encounter_dim := ColorRect.new()
	encounter_dim.name = "EncounterScrim"
	encounter_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_dim.color = Color(0.018, 0.006, 0.009, 0.34)
	encounter_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_layer.add_child(encounter_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_layer.add_child(center)
	var card := _panel()
	card.custom_minimum_size = Vector2(430, 190)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _style(Color(0.015, 0.012, 0.015, 0.96), 4, 1, CRIMSON))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var title := _label("BREAK FREE", 14, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color("070506"))
	content.add_child(title)
	_qte_timer_label = _label("5.0 SECONDS", 12, RED)
	_qte_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_qte_timer_label)
	_qte_prompt = _label("", 25, PAPER)
	_qte_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_qte_prompt)
	_qte_feedback = _label("FOLLOW THE KEYS", 10, MUTED)
	_qte_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_qte_feedback)
	_qte_progress = ProgressBar.new()
	_qte_progress.custom_minimum_size = Vector2(0, 9)
	_qte_progress.max_value = 100
	_qte_progress.show_percentage = false
	_qte_progress.add_theme_stylebox_override("background", _style(Color("45423c"), 4, 0))
	_qte_progress.add_theme_stylebox_override("fill", _style(AMBER, 4, 0))
	content.add_child(_qte_progress)

func _build_intro() -> void:
	_intro_layer = Control.new()
	_intro_layer.name = "StoryIntroduction"
	_intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_layer.visible = false
	_intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_intro_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.016, 0.018, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(center)
	var card := _panel()
	card.custom_minimum_size = Vector2(580, 350)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", 32)
	margins.add_theme_constant_override("margin_right", 32)
	margins.add_theme_constant_override("margin_top", 28)
	margins.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margins.add_child(content)
	_intro_title = _label("THE FAMILIAR", 22, PAPER)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_intro_title)
	var divider := HSeparator.new()
	content.add_child(divider)
	_intro_copy = _label("", 16, PAPER)
	_intro_copy.custom_minimum_size.y = 150
	_intro_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_intro_copy)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	content.add_child(actions)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(100, 38)
	_style_button(skip, false)
	skip.pressed.connect(_finish_intro)
	actions.add_child(skip)
	_intro_continue = Button.new()
	_intro_continue.text = "CONTINUE"
	_intro_continue.custom_minimum_size = Vector2(150, 38)
	_style_button(_intro_continue, true)
	_intro_continue.pressed.connect(_advance_intro)
	actions.add_child(_intro_continue)
	var hint := _label("ENTER — CONTINUE", 10, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

func show_intro_if_new(force: bool = false) -> bool:
	if (bool(_settings.get_value("story", "intro_seen", false)) and not force) or ending_active:
		return false
	intro_active = true
	_intro_page = 0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_intro_layer.visible = true
	_show_intro_page()
	return true

func _show_intro_page() -> void:
	var pages := [
		["THE HOUSE", "You know this house. Every hallway. Every room. Every sound.\n\nBut tonight, something feels different."],
		["THE FAMILIAR", "She looks like someone you know.\nShe sounds like someone you trust.\n\nBut something about her isn't right."],
		["GET OUT", "Find a way out of the house.\nStay quiet. Stay hidden.\n\nAnd whatever happens, don't let her find you."]
	]
	_intro_title.text = "THE FAMILIAR  /  " + str(pages[_intro_page][0])
	_intro_copy.text = str(pages[_intro_page][1])
	_intro_continue.text = "BEGIN GAME" if _intro_page == pages.size() - 1 else "CONTINUE"
	_intro_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_intro_copy.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _intro_fade and _intro_fade.is_running():
		_intro_fade.kill()
	_intro_fade = create_tween()
	_intro_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_fade.tween_property(_intro_title, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	_intro_fade.parallel().tween_property(_intro_copy, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)

func _advance_intro() -> void:
	if _intro_page < 2:
		_intro_page += 1
		_show_intro_page()
	else:
		_finish_intro()

func _finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	_intro_layer.visible = false
	_settings.set_value("story", "intro_seen", true)
	_settings.save(settings_path)
	wake_up_requested.emit()

func begin_wake_up_sequence(waking_player: Node) -> void:
	if wake_up_active or ending_active:
		return
	wake_up_active = true
	_wake_layer.visible = true
	_wake_overlay.color.a = 1.0
	_wake_skip_button.visible = true
	var camera := waking_player.get_node_or_null("PlayerCamera") as Camera3D
	var motion := float(waking_player.get("camera_motion_intensity"))
	_wake_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_wake_tween.tween_interval(0.35)
	_wake_tween.tween_property(_wake_overlay, "color:a", 0.0, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_wake_tween.tween_interval(0.52)
	_wake_tween.tween_property(_wake_overlay, "color:a", 0.82, 0.10)
	_wake_tween.tween_property(_wake_overlay, "color:a", 0.0, 0.26)
	_wake_tween.tween_interval(0.55)
	_wake_tween.tween_property(_wake_overlay, "color:a", 0.70, 0.10)
	_wake_tween.tween_property(_wake_overlay, "color:a", 0.0, 0.25)
	if camera != null:
		var motion_scale := clampf(motion, 0.0, 1.0)
		_wake_tween.tween_interval(0.28)
		_wake_tween.tween_property(camera, "position", Vector3(-0.045 * motion_scale, 0.82, 0.015 * motion_scale), 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_wake_tween.parallel().tween_property(camera, "rotation", Vector3(deg_to_rad(-2.0), deg_to_rad(7.0) * motion_scale, deg_to_rad(-1.2) * motion_scale), 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_wake_tween.tween_property(camera, "position", Vector3(-0.12 * motion_scale, 0.70, 0.17 * motion_scale), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_wake_tween.parallel().tween_property(camera, "rotation", Vector3(deg_to_rad(-1.0), deg_to_rad(12.0) * motion_scale, deg_to_rad(1.4) * motion_scale), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_wake_tween.tween_property(camera, "position", Vector3(0.0, 1.05, 0.0), 1.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_wake_tween.parallel().tween_property(camera, "rotation", waking_player.call("standing_camera_rotation"), 1.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_wake_tween.tween_interval(3.55)
	_wake_tween.tween_property(_wake_overlay, "color:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_wake_tween.tween_interval(0.35)
	_wake_tween.tween_callback(_finish_wake_up)

func _skip_wake_up() -> void:
	if not wake_up_active:
		return
	if _wake_tween and _wake_tween.is_running():
		_wake_tween.kill()
	if player != null:
		player.call("reset_opening_camera_pose")
	_finish_wake_up()

func _finish_wake_up() -> void:
	if not wake_up_active:
		return
	wake_up_active = false
	_wake_layer.visible = false
	wake_up_finished.emit()

func start_survival_qte(duration: float = 5.0, configured_sequence: Array[int] = []) -> void:
	if qte_active or ending_active:
		return
	if not configured_sequence.is_empty():
		_qte_sequence = configured_sequence.duplicate()
	else:
		_qte_sequence = _generate_qte_sequence()
	_previous_qte_sequence = _qte_sequence.duplicate()
	qte_active = true
	_qte_duration = maxf(0.1, duration)
	_qte_remaining = _qte_duration
	_qte_index = 0
	_qte_timer_label.text = "%.1f SECONDS" % _qte_remaining
	_qte_progress.value = 100.0
	_qte_feedback.text = "FOLLOW THE KEYS"
	_qte_layer.visible = true
	_update_qte_prompt()
	survival_qte_started.emit()

func _initialize_qte_rng() -> void:
	if qte_random_seed == 0:
		_qte_rng.randomize()
	else:
		_qte_rng.seed = qte_random_seed

func _generate_qte_sequence() -> Array[int]:
	var pool: Array[int] = []
	for code in qte_key_pool:
		if code in [KEY_Q, KEY_E, KEY_R, KEY_F] and code not in pool:
			pool.append(code)
	if pool.is_empty():
		pool = [KEY_Q, KEY_E, KEY_R, KEY_F]
	var count := maxi(1, qte_sequence_length)
	var generated: Array[int] = []
	for _attempt in 8:
		generated.clear()
		for _index in count:
			generated.append(int(pool[_qte_rng.randi_range(0, pool.size() - 1)]))
		if generated != _previous_qte_sequence:
			break
	if generated == _previous_qte_sequence and pool.size() > 1:
		var alternatives: Array[int] = []
		for code in pool:
			if code != generated[-1]:
				alternatives.append(code)
		generated[-1] = alternatives[_qte_rng.randi_range(0, alternatives.size() - 1)]
	return generated.duplicate()

func _update_qte_prompt() -> void:
	var text := ""
	for index in _qte_sequence.size():
		var key_name := OS.get_keycode_string(_qte_sequence[index])
		text += ("[ " + key_name + " ]" if index == _qte_index else key_name)
		if index < _qte_sequence.size() - 1:
			text += "     "
	_qte_prompt.text = text

func _finish_survival_qte(escaped: bool) -> void:
	if not qte_active:
		return
	qte_active = false
	_qte_layer.visible = false
	survival_qte_finished.emit(escaped)

func _build_game_hud() -> void:
	_gameplay_hud = Control.new()
	_gameplay_hud.name = "GameplayHUD"
	_gameplay_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gameplay_hud)
	var title := _label("THE FAMILIAR", 17, PAPER)
	title.position = Vector2(28, 22)
	_gameplay_hud.add_child(title)
	_location_label = _label("", 12, MUTED)
	_location_label.position = Vector2(28, 48)
	_gameplay_hud.add_child(_location_label)
	var battery_panel := _panel()
	battery_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	battery_panel.offset_left = -222
	battery_panel.offset_top = 20
	battery_panel.offset_right = -26
	battery_panel.offset_bottom = 76
	_gameplay_hud.add_child(battery_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 5)
	battery_panel.add_child(vb)
	var battery_head := _label("FLASHLIGHT", 11, MUTED)
	vb.add_child(battery_head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	vb.add_child(row)
	_battery_bar = ProgressBar.new()
	_battery_bar.custom_minimum_size = Vector2(115, 10)
	_battery_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_battery_bar.max_value = 100
	_battery_bar.show_percentage = false
	_battery_bar.add_theme_stylebox_override("background", _style(Color("45423c"), 5, 0))
	row.add_child(_battery_bar)
	_battery_text = _label("100% OFF", 11, MUTED)
	row.add_child(_battery_text)
	var crosshair := Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-3, -3)
	crosshair.custom_minimum_size = Vector2(6, 6)
	var dot := ColorRect.new()
	dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dot.color = Color(0.91, 0.87, 0.78, 0.68)
	crosshair.add_child(dot)
	_gameplay_hud.add_child(crosshair)
	var bottom_plate := PanelContainer.new()
	bottom_plate.name = "ContextualHUDPlate"
	bottom_plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_plate.anchor_left = 0.5
	bottom_plate.anchor_right = 0.5
	bottom_plate.anchor_top = 1.0
	bottom_plate.anchor_bottom = 1.0
	bottom_plate.offset_left = -260
	bottom_plate.offset_right = 260
	bottom_plate.offset_top = -132
	bottom_plate.offset_bottom = -20
	bottom_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_plate.add_theme_stylebox_override("panel", _style(Color(0.008, 0.008, 0.01, 0.58), 3, 1, Color(0.32, 0.13, 0.15, 0.46)))
	_gameplay_hud.add_child(bottom_plate)
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 7)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_plate.add_child(bottom)
	_objective_label = _label("", 12, MUTED)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_objective_label)
	_interaction_label = _label("", 14, PAPER)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_interaction_label)
	_hide_panel = VBoxContainer.new()
	_hide_panel.visible = false
	_hide_panel.add_theme_constant_override("separation", 6)
	bottom.add_child(_hide_panel)
	var stay := _label("STAY STILL", 12, AMBER)
	stay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hide_panel.add_child(stay)
	_hide_bar = ProgressBar.new()
	_hide_bar.custom_minimum_size = Vector2(180, 8)
	_hide_bar.max_value = 100
	_hide_bar.show_percentage = false
	_hide_bar.add_theme_stylebox_override("background", _style(Color("45423c"), 4, 0))
	_hide_bar.add_theme_stylebox_override("fill", _style(AMBER, 4, 0))
	_hide_panel.add_child(_hide_bar)
	_notification = _panel()
	_notification.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification.anchor_left = 0.5
	_notification.anchor_right = 0.5
	_notification.offset_left = -240
	_notification.offset_right = 240
	_notification.offset_top = 94
	_notification.offset_bottom = 146
	_notification.visible = false
	_gameplay_hud.add_child(_notification)
	_notification_label = _label("", 13, PAPER)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notification_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notification.add_child(_notification_label)
	_set_mouse_passthrough(_root)

func _build_menu() -> void:
	_menu = Control.new()
	_menu.name = "PauseMenu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_menu)
	_menu_dim = ColorRect.new()
	_menu_dim.name = "PauseSceneScrim"
	_menu_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_dim.color = Color(0.008, 0.006, 0.009, 0.67)
	_menu_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_menu_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 24)
	center.add_theme_constant_override("margin_right", 24)
	center.add_theme_constant_override("margin_top", 15)
	center.add_theme_constant_override("margin_bottom", 15)
	_menu.add_child(center)
	_menu_panel = _panel()
	_menu_panel.name = "PauseMenuCard"
	_menu_panel.custom_minimum_size = Vector2(610, 560)
	_menu_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_panel.add_theme_stylebox_override("panel", _style(Color(0.014, 0.013, 0.016, 0.92), 4, 1, Color(0.34, 0.13, 0.15, 0.72)))
	center.add_child(_menu_panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_menu_panel.add_child(margin)
	_menu_content = VBoxContainer.new()
	_menu_content.add_theme_constant_override("separation", 9)
	margin.add_child(_menu_content)
	var header := VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 1)
	_menu_content.add_child(header)
	var brand := _label("THE FAMILIAR", 9, CRIMSON)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(brand)
	_menu_title = _label("GAME PAUSED", 25, PAPER)
	_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_menu_title)
	var paused := _label("TAB / ESC  /  RESUME", 9, MUTED)
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(paused)
	var title_rule := ColorRect.new()
	title_rule.name = "PauseTitleRule"
	title_rule.color = CRIMSON
	title_rule.custom_minimum_size = Vector2(0, 1)
	_menu_content.add_child(title_rule)
	_menu_tabs = HBoxContainer.new()
	_menu_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_tabs.add_theme_constant_override("separation", 4)
	_menu_content.add_child(_menu_tabs)
	for tab in ["OBJECTIVE", "CONTROLS", "SETTINGS", "AUDIO"]:
		var button := Button.new()
		button.text = tab
		button.custom_minimum_size = Vector2(108, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		_style_button(button, false)
		button.pressed.connect(_select_tab.bind(tab))
		_menu_tabs.add_child(button)
	var sep := ColorRect.new()
	sep.custom_minimum_size.y = 1
	sep.color = Color(0.35, 0.15, 0.17, 0.62)
	_menu_content.add_child(sep)
	_menu_scroll = ScrollContainer.new()
	_menu_scroll.name = "MenuContentScroll"
	_menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_scroll.custom_minimum_size.y = 245
	_menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI_STYLE.style_scroll_container(_menu_scroll)
	_menu_content.add_child(_menu_scroll)
	var footer := HBoxContainer.new()
	_menu_footer = footer
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 6)
	_menu_content.add_child(footer)
	var resume := Button.new()
	resume.text = "RESUME"
	resume.custom_minimum_size = Vector2(136, 40)
	resume.focus_mode = Control.FOCUS_ALL
	_style_button(resume, true)
	resume.pressed.connect(close_menu)
	footer.add_child(resume)
	var restart := Button.new()
	restart.text = "RESTART"
	restart.custom_minimum_size = Vector2(95, 40)
	restart.focus_mode = Control.FOCUS_ALL
	_style_button(restart, false)
	restart.pressed.connect(_show_confirmation.bind("restart"))
	footer.add_child(restart)
	var main_menu := Button.new()
	main_menu.text = "MAIN MENU"
	main_menu.custom_minimum_size = Vector2(102, 40)
	main_menu.focus_mode = Control.FOCUS_ALL
	_style_button(main_menu, false)
	main_menu.pressed.connect(_show_confirmation.bind("main_menu"))
	footer.add_child(main_menu)
	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(76, 40)
	quit.focus_mode = Control.FOCUS_ALL
	_style_button(quit, false)
	quit.pressed.connect(func(): get_tree().quit())
	footer.add_child(quit)
	var hint := _label("TAB / ESC — RESUME    R — RESTART OPTIONS", 9, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_content.add_child(hint)
	_build_confirmation()

func _build_confirmation() -> void:
	_confirmation_layer = Control.new()
	_confirmation_layer.name = "RunConfirmation"
	_confirmation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation_layer.visible = false
	_confirmation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirmation_layer.z_index = 5
	_menu.add_child(_confirmation_layer)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.01, 0.01, 0.72)
	_confirmation_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmation_layer.add_child(center)
	var panel := _panel()
	panel.custom_minimum_size = Vector2(390, 205)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	panel.add_child(content)
	_confirmation_title = _label("Restart Game?", 20, PAPER)
	content.add_child(_confirmation_title)
	_confirmation_message = _label("Your current progress will be lost. Are you sure you want to start over?", 13, MUTED)
	_confirmation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_confirmation_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	_confirmation_cancel = Button.new()
	_confirmation_cancel.text = "CANCEL"
	_confirmation_cancel.custom_minimum_size = Vector2(120, 38)
	_confirmation_cancel.focus_mode = Control.FOCUS_ALL
	_style_button(_confirmation_cancel, false)
	_confirmation_cancel.pressed.connect(_cancel_confirmation)
	actions.add_child(_confirmation_cancel)
	var confirm := Button.new()
	confirm.text = "RESTART"
	confirm.custom_minimum_size = Vector2(120, 38)
	confirm.focus_mode = Control.FOCUS_ALL
	_style_button(confirm, true)
	confirm.pressed.connect(_confirm_action)
	actions.add_child(confirm)

func _show_confirmation(action: String) -> void:
	if not menu_open or confirmation_active:
		return
	_confirmation_action = action
	confirmation_active = true
	_confirmation_title.text = "Restart Game?" if action == "restart" else "Return to Main Menu?"
	_confirmation_message.text = "Your current progress will be lost. Are you sure you want to start over?" if action == "restart" else "Your current progress will be lost. Return to the main menu?"
	_confirmation_layer.visible = true
	_confirmation_cancel.grab_focus()

func _cancel_confirmation() -> void:
	confirmation_active = false
	_confirmation_action = ""
	_confirmation_layer.visible = false

func _confirm_action() -> void:
	if not confirmation_active:
		return
	var action := _confirmation_action
	_cancel_confirmation()
	menu_open = false
	_menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if action == "restart":
		restart_requested.emit()
	else:
		main_menu_requested.emit()

func _select_tab(tab: String) -> void:
	selected_tab = tab
	for child in _menu_tabs.get_children():
		var button := child as Button
		var selected := button.text == selected_tab
		button.add_theme_color_override("font_color", AMBER if selected else MUTED)
		button.add_theme_color_override("font_hover_color", PAPER)
		var tab_style := _style(Color("302b24") if selected else Color("292827"), 4, 1, AMBER if selected else Color("45423c"))
		tab_style.border_width_bottom = 2 if selected else 1
		button.add_theme_stylebox_override("normal", tab_style)
		button.add_theme_stylebox_override("hover", _style(Color("363128"), 4, 1, AMBER))
		button.add_theme_stylebox_override("pressed", _style(Color("211f1c"), 4, 1, AMBER))
	for child in _menu_scroll.get_children():
		_menu_scroll.remove_child(child)
		child.queue_free()
	var content := VBoxContainer.new()
	content.name = "TabContent_" + tab
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 11)
	content.custom_minimum_size.x = 470
	_menu_scroll.add_child(content)
	match tab:
		"OBJECTIVE": _populate_objective(content)
		"CONTROLS": _populate_controls(content)
		"SETTINGS": _populate_settings(content)
		"AUDIO": _populate_audio(content)

func _populate_objective(box: VBoxContainer) -> void:
	var objective := str(environment.call("objective_text")) if environment.has_method("objective_text") else ""
	_add_heading(box, "CURRENT OBJECTIVE")
	var objective_title := _label(objective, 17, PAPER)
	objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(objective_title)
	_add_heading(box, "CURRENT LOCATION")
	_add_body(box, _human_location(str(environment.get("player_location"))), MUTED)
	_add_section_rule(box)
	_add_heading(box, "ESCAPE ITEMS")
	if _has_property("has_crowbar"):
		_add_status_row(box, "Crowbar", bool(environment.get("has_crowbar")))
		_add_status_row(box, "Attic window key", bool(environment.get("has_window_key")))
	else:
		_add_status_row(box, "Basement key", bool(environment.get("has_basement_key")))
	_add_section_rule(box)
	_add_heading(box, "PROGRESS")
	var phases: Array[Dictionary] = []
	if _has_property("has_crowbar"):
		if not bool(environment.get("has_crowbar")):
			phases = [{"text":"Find crowbar", "state":"current"}, {"text":"Find Mother's window key", "state":"current"}]
		elif not bool(environment.get("attic_open")):
			phases = [{"text":"Crowbar acquired", "state":"done"}, {"text":"Open attic access", "state":"current"}]
			if not bool(environment.get("has_window_key")): phases.append({"text":"Find Mother's window key", "state":"known"})
		elif not bool(environment.get("has_window_key")):
			phases = [{"text":"Crowbar acquired", "state":"done"}, {"text":"Attic access opened", "state":"done"}, {"text":"Find Mother's window key", "state":"current"}]
		elif not bool(environment.get("window_open")):
			phases = [{"text":"Crowbar acquired", "state":"done"}, {"text":"Attic access opened", "state":"done"}, {"text":"Window key acquired", "state":"done"}, {"text":"Unlock attic window", "state":"current"}]
		else:
			phases = [{"text":"Crowbar acquired", "state":"done"}, {"text":"Attic access opened", "state":"done"}, {"text":"Window key acquired", "state":"done"}, {"text":"Attic window unlocked", "state":"done"}, {"text":"Escape", "state":"current"}]
		for phase in phases:
			_add_milestone(box, str(phase.text), str(phase.state))
	else:
		phases = [{"text":"Find basement key", "state":"current"}, {"text":"Unlock basement", "state":"known"}, {"text":"Reach basement exit", "state":"known"}]
		var stage := int(environment.get("escape_progress"))
		if stage >= 1:
			phases[0]["state"] = "done"
			phases[1]["state"] = "current"
		if stage >= 2:
			phases[1]["state"] = "done"
			phases[2]["state"] = "current"
		if stage >= 3:
			phases[2]["state"] = "done"
			phases.append({"text":"Escaped", "state":"done"})
		for phase in phases:
			_add_milestone(box, str(phase.text), str(phase.state))

func _populate_controls(box: VBoxContainer) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var movement := VBoxContainer.new()
	movement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	movement.add_theme_constant_override("separation", 8)
	columns.add_child(movement)
	var interaction := VBoxContainer.new()
	interaction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction.add_theme_constant_override("separation", 8)
	columns.add_child(interaction)
	_add_heading(movement, "MOVEMENT")
	_add_control_row(movement, _input_action_display("move_forward", "W / ↑"), "Move forward")
	_add_control_row(movement, _input_action_display("move_backward", "S / ↓"), "Move backward")
	_add_control_row(movement, _input_action_display("move_left", "A / ←"), "Move left")
	_add_control_row(movement, _input_action_display("move_right", "D / →"), "Move right")
	_add_control_row(movement, "Mouse", "Look around")
	_add_control_row(movement, _input_action_display("sprint", "Shift"), "Sprint")
	if bool(player.get("allow_jump")):
		_add_control_row(movement, "Space", "Jump")
	_add_heading(interaction, "INTERACTION")
	_add_control_row(interaction, "E", "Interact / hide / leave")
	_add_control_row(interaction, _input_action_display("flashlight_toggle", "F"), "Flashlight")
	_add_control_row(interaction, "Tab", "Menu")
	_add_control_row(interaction, "H", "Controls shortcut")
	_add_control_row(interaction, "Esc", "Pause / resume")
	_add_control_row(interaction, "R", "Restart options while paused")

func _populate_settings(box: VBoxContainer) -> void:
	_add_heading(box, "GAMEPLAY DISPLAY")
	_add_slider(box, "Mouse sensitivity", "sensitivity", 0.5, 4.0, 0.01, float(player.get("mouse_sensitivity")) / 0.0022, "×")
	_add_slider(box, "VHS intensity", "vhs", 0.0, 1.5, 0.01, float(vhs.get("user_intensity_scale")), "×")
	_add_slider(box, "Camera motion", "camera_motion", 0.0, 100.0, 1.0, float(player.get("camera_motion_intensity")) * 100.0, "%")
	_add_heading(box, "DISPLAY")
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.custom_minimum_size.y = 34
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.add_theme_color_override("font_color", PAPER)
	fullscreen.add_theme_color_override("font_hover_color", AMBER)
	fullscreen.add_theme_color_override("font_pressed_color", AMBER)
	fullscreen.add_theme_color_override("font_focus_color", AMBER)
	fullscreen.add_theme_icon_override("checked", _toggle_icon(true))
	fullscreen.add_theme_icon_override("unchecked", _toggle_icon(false))
	fullscreen.toggled.connect(_set_fullscreen)
	box.add_child(fullscreen)

func _populate_audio(box: VBoxContainer) -> void:
	_add_heading(box, "AUDIO LEVELS")
	_add_slider(box, "Master", "bus_Master", 0, 100, 1, _bus_percent("Master"), "%")
	_add_slider(box, "Music", "bus_Music", 0, 100, 1, _bus_percent("Music"), "%")
	_add_slider(box, "Ambience", "bus_Ambience", 0, 100, 1, _bus_percent("Ambience"), "%")
	_add_slider(box, "Sound effects", "bus_SFX", 0, 100, 1, _bus_percent("SFX"), "%")

func _add_slider(box: VBoxContainer, title: String, setting: String, minimum: float, maximum: float, step: float, value: float, suffix: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	var line := HBoxContainer.new()
	row.add_child(line)
	var name_label := _label(title.to_upper(), 11, PAPER)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var value_label := _label("", 11, AMBER)
	value_label.custom_minimum_size.x = 66
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	UI_STYLE.style_slider(slider)
	row.add_child(slider)
	slider.value_changed.connect(func(v: float):
		value_label.text = _slider_display(v, minimum, maximum, suffix)
		_apply_setting(setting, v)
		_save_settings()
	)
	value_label.text = _slider_display(value, minimum, maximum, suffix)

func _slider_display(value: float, minimum: float, maximum: float, suffix: String) -> String:
	if suffix == "%": return "%d%%" % roundi(value)
	if suffix == "×": return "%d%%" % roundi(inverse_lerp(minimum, maximum, value) * 100.0)
	return "%.2f" % value

func _toggle_icon(checked: bool) -> Texture2D:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(2, 16):
		for x in range(2, 16):
			var edge := x == 2 or x == 15 or y == 2 or y == 15
			image.set_pixel(x, y, Color("544a3b") if edge else Color("282725"))
	if checked:
		for point in [Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11), Vector2i(8, 10), Vector2i(9, 9), Vector2i(10, 8), Vector2i(11, 7), Vector2i(12, 6)]:
			image.set_pixel(point.x, point.y, AMBER)
	return ImageTexture.create_from_image(image)

func _apply_setting(setting: String, value: float) -> void:
	match setting:
		"sensitivity": player.set("mouse_sensitivity", 0.0022 * value)
		"vhs": vhs.set("user_intensity_scale", value)
		"camera_motion": player.set("camera_motion_intensity", clampf(value / 100.0, 0.0, 1.0))
		"bus_Master", "bus_Music", "bus_Ambience", "bus_SFX":
			var bus := setting.trim_prefix("bus_")
			var index := AudioServer.get_bus_index(bus)
			if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.0001)))

func _apply_saved_settings() -> void:
	player.set("mouse_sensitivity", float(_settings.get_value("gameplay", "sensitivity", 1.0)) * 0.0022)
	vhs.set("user_intensity_scale", float(_settings.get_value("gameplay", "vhs", 1.0)))
	player.set("camera_motion_intensity", clampf(float(_settings.get_value("gameplay", "camera_motion", 1.0)), 0.0, 1.0))
	for bus in ["Master", "Music", "Ambience", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		var value := float(_settings.get_value("audio", bus, 100.0))
		if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value / 100.0, 0.0001)))
	if bool(_settings.get_value("display", "fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_setting_persist_only(setting: String, value: Variant) -> void:
	if setting == "sensitivity" or setting == "vhs" or setting == "camera_motion": _settings.set_value("gameplay", setting, value)
	elif setting.begins_with("bus_"): _settings.set_value("audio", setting.trim_prefix("bus_"), value)

func _save_settings() -> void:
	_settings.set_value("gameplay", "sensitivity", float(player.get("mouse_sensitivity")) / 0.0022)
	_settings.set_value("gameplay", "vhs", float(vhs.get("user_intensity_scale")))
	_settings.set_value("gameplay", "camera_motion", float(player.get("camera_motion_intensity")))
	for bus in ["Master", "Music", "Ambience", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0: _settings.set_value("audio", bus, db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0)
	_settings.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_settings.save(settings_path)

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _ensure_buses() -> void:
	for name in ["Music", "Ambience", "SFX"]:
		if AudioServer.get_bus_index(name) >= 0: continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, "Master")
	var atmosphere: Node = environment.builder.get_node_or_null("FurnishingsAndGameplayProps/HouseAtmosphere") if environment.has_method("climb_ladder") else null
	if atmosphere != null:
		for speaker in atmosphere.television_players: speaker.bus = "Ambience"

func _has_property(property_name: String) -> bool:
	for property in environment.get_property_list():
		if str(property.name) == property_name:
			return true
	return false

func _bus_percent(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0 if index >= 0 else 100.0

func _refresh_menu_data() -> void:
	if menu_open:
		_select_tab(selected_tab)

func _update_debug_panel() -> void:
	if debug_label == null: return
	debug_label.text = "TEST ONLY  |  Suspicion %.0f  |  Familiar: %s  |  Mother: %s  |  1/2/3 set suspicion" % [game.observation.suspicion_level, game.familiar.current_action, "Household routine" if game._routine_active else game.monster.state_name()]

func _human_location(value: String) -> String:
	var names := {
		"ground_floor_hall": "GROUND FLOOR / FOYER", "foyer": "GROUND FLOOR / FOYER",
		"living_room": "GROUND FLOOR / LIVING ROOM", "kitchen": "GROUND FLOOR / KITCHEN",
		"pantry": "GROUND FLOOR / PANTRY", "dining_room": "GROUND FLOOR / DINING ROOM",
		"family_room": "GROUND FLOOR / FAMILY ROOM", "sunroom": "GROUND FLOOR / SUNROOM",
		"downstairs_bathroom": "GROUND FLOOR / BATHROOM", "second_floor_hall": "SECOND FLOOR / HALL",
		"mothers_room": "SECOND FLOOR / MOTHER'S ROOM", "your_room": "SECOND FLOOR / BEDROOM",
		"guest_room": "SECOND FLOOR / GUEST ROOM", "upstairs_reading_room": "SECOND FLOOR / READING ROOM",
		"upstairs_bathroom": "SECOND FLOOR / BATHROOM", "upstairs_study": "SECOND FLOOR / STUDY",
		"attic": "ATTIC", "basement_archive": "BASEMENT / ARCHIVE",
		"basement_utility": "BASEMENT / UTILITY ROOM", "basement_storage": "BASEMENT / STORAGE",
		"evening_neighborhood": "OUTSIDE / EVENING NEIGHBORHOOD"
	}
	if names.has(value): return names[value]
	var pretty := value.replace("_", " ").to_upper()
	if pretty.contains("SECOND FLOOR") or pretty.contains("ATTIC") or pretty.contains("UPSTAIRS") or pretty.contains("MOTHER") or pretty.contains("GUEST") or pretty.contains("YOUR ROOM"):
		return "SECOND FLOOR / " + pretty.replace("SECOND FLOOR HALL", "HALL")
	if pretty.contains("BASEMENT"): return "BASEMENT / " + pretty.replace("BASEMENT ", "")
	if pretty.contains("EVENING NEIGHBORHOOD"): return "OUTSIDE / EVENING NEIGHBORHOOD"
	return "GROUND FLOOR / " + pretty.replace("GROUND FLOOR HALL", "HALL")

func _add_control_row(box: VBoxContainer, key: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 28
	box.add_child(row)
	var key_chip := PanelContainer.new()
	key_chip.custom_minimum_size = Vector2(72, 26)
	key_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_chip.add_theme_stylebox_override("panel", _style(Color("302c26"), 3, 1, Color("4c4438")))
	row.add_child(key_chip)
	var key_label := _label(key, 10, AMBER)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	key_chip.add_child(key_label)
	var action_label := _label(description, 11, PAPER)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(action_label)

func _input_action_display(action: String, fallback: String) -> String:
	if not InputMap.has_action(action): return fallback
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is not InputEventKey: continue
		var code := (event as InputEventKey).physical_keycode
		var display := ""
		match code:
			KEY_W: display = "W"
			KEY_A: display = "A"
			KEY_S: display = "S"
			KEY_D: display = "D"
			KEY_UP: display = "↑"
			KEY_DOWN: display = "↓"
			KEY_LEFT: display = "←"
			KEY_RIGHT: display = "→"
			KEY_SHIFT: display = "Shift"
			KEY_F: display = "F"
		if display != "" and not names.has(display): names.append(display)
	return " / ".join(names) if not names.is_empty() else fallback

func _add_status_row(box: VBoxContainer, item: String, acquired: bool) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var item_label := _label(item, 12, PAPER)
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(item_label)
	var state := _label("ACQUIRED" if acquired else "NOT ACQUIRED", 10, AMBER if acquired else MUTED)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(state)

func _add_milestone(box: VBoxContainer, text: String, state: String) -> void:
	var marker := "✓" if state == "done" else ("›" if state == "current" else "·")
	var color := AMBER if state == "current" else (PAPER if state == "done" else MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	box.add_child(row)
	var marker_label := _label(marker, 12, color)
	marker_label.custom_minimum_size.x = 12
	row.add_child(marker_label)
	row.add_child(_label(text, 11, color))

func _add_section_rule(box: VBoxContainer) -> void:
	var rule := HSeparator.new()
	box.add_child(rule)

func _style_button(button: Button, primary: bool) -> void:
	var base := Color(0.17, 0.015, 0.027, 0.50) if primary else Color(0.04, 0.035, 0.04, 0.32)
	var hover := Color(0.26, 0.025, 0.043, 0.68) if primary else Color(0.15, 0.018, 0.03, 0.52)
	var edge := CRIMSON if primary else Color(0.36, 0.20, 0.21, 0.62)
	button.add_theme_stylebox_override("normal", _style(base, 3, 1, edge))
	button.add_theme_stylebox_override("hover", _style(hover, 3, 1, Color("b3474e")))
	button.add_theme_stylebox_override("pressed", _style(Color(0.25,0.018,0.03,0.78), 3, 1, Color("b3474e")))
	button.add_theme_stylebox_override("focus", _style(Color(0.12,0.012,0.022,0.62), 3, 1, Color("b3474e")))
	button.add_theme_color_override("font_color", PAPER if primary else MUTED)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)

func _add_heading(box: VBoxContainer, value: String) -> void:
	var label := _label(value, 10, AMBER)
	label.add_theme_constant_override("outline_size", 0)
	box.add_child(label)

func _add_body(box: VBoxContainer, value: String, color: Color = PAPER) -> void:
	var label := _label(value, 13, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)

func _build_ending() -> void:
	_ending_panel = Control.new()
	_ending_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending_panel.visible = false
	_ending_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ending_panel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), 0, 0))
	_root.add_child(_ending_panel)
	var ending_scrim := ColorRect.new()
	ending_scrim.name = "EndingAtmosphere"
	ending_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_scrim.color = Color(0.013, 0.006, 0.009, 0.92)
	ending_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_panel.add_child(ending_scrim)
	var red_undertone := ColorRect.new()
	red_undertone.name = "EndingRedUndertone"
	red_undertone.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	red_undertone.anchor_left = 0.0
	red_undertone.anchor_right = 1.0
	red_undertone.anchor_top = 0.78
	red_undertone.anchor_bottom = 1.0
	red_undertone.color = Color(0.19, 0.012, 0.025, 0.14)
	red_undertone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_panel.add_child(red_undertone)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending_panel.add_child(center)
	var card := _panel()
	card.custom_minimum_size = Vector2(470, 390)
	card.add_theme_stylebox_override("panel", _style(Color(0.012, 0.009, 0.013, 0.94), 4, 1, CRIMSON))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	var brand := _label("THE FAMILIAR", 10, MUTED)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(brand)
	_ending_label = _label("", 39, RED)
	_ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_label.add_theme_constant_override("outline_size", 2)
	_ending_label.add_theme_color_override("font_outline_color", Color("080506"))
	content.add_child(_ending_label)
	var title_rule := ColorRect.new()
	title_rule.custom_minimum_size = Vector2(220, 1)
	title_rule.color = CRIMSON
	title_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(title_rule)
	_ending_subtitle = _label("", 13, MUTED)
	_ending_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_ending_subtitle)
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 7)
	content.add_child(actions)
	_ending_retry_button = Button.new()
	_ending_retry_button.text = "TRY AGAIN"
	_ending_retry_button.custom_minimum_size = Vector2(230, 42)
	_ending_retry_button.focus_mode = Control.FOCUS_ALL
	_style_button(_ending_retry_button, true)
	_ending_retry_button.pressed.connect(func(): restart_requested.emit())
	actions.add_child(_ending_retry_button)
	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.custom_minimum_size = Vector2(230, 42)
	menu_button.focus_mode = Control.FOCUS_ALL
	_style_button(menu_button, false)
	menu_button.pressed.connect(func(): main_menu_requested.emit())
	actions.add_child(menu_button)
	var quit_button := Button.new()
	quit_button.text = "QUIT GAME"
	quit_button.custom_minimum_size = Vector2(230, 42)
	quit_button.focus_mode = Control.FOCUS_ALL
	_style_button(quit_button, false)
	quit_button.pressed.connect(func(): get_tree().quit())
	actions.add_child(quit_button)
	var hint := _label("R  /  TRY AGAIN", 9, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	_ending_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _build_wake_up() -> void:
	_wake_layer = Control.new()
	_wake_layer.name = "BedroomWakeUp"
	_wake_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wake_layer.visible = false
	_wake_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_wake_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_wake_layer.z_index = 40
	_root.add_child(_wake_layer)
	_wake_overlay = ColorRect.new()
	_wake_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wake_overlay.color = Color(0.008, 0.009, 0.011, 1.0)
	_wake_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_wake_layer.add_child(_wake_overlay)
	var title := _label("SHE'S IN THE HOUSE", 16, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 1.0
	title.anchor_bottom = 1.0
	title.offset_left = -190
	title.offset_right = 190
	title.offset_top = -96
	title.offset_bottom = -68
	_wake_layer.add_child(title)
	_wake_skip_button = Button.new()
	_wake_skip_button.text = "SKIP  ·  SPACE"
	_wake_skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_wake_skip_button.anchor_left = 1.0
	_wake_skip_button.anchor_right = 1.0
	_wake_skip_button.anchor_top = 1.0
	_wake_skip_button.anchor_bottom = 1.0
	_wake_skip_button.offset_left = -190
	_wake_skip_button.offset_right = -24
	_wake_skip_button.offset_top = -58
	_wake_skip_button.offset_bottom = -20
	_wake_skip_button.focus_mode = Control.FOCUS_ALL
	_style_button(_wake_skip_button, false)
	_wake_skip_button.pressed.connect(_skip_wake_up)
	_wake_layer.add_child(_wake_skip_button)

func _set_mouse_passthrough(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_mouse_passthrough(child)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL, 6, 1, Color("4a4640")))
	return panel

func _style(color: Color, radius: int, border: int, border_color: Color = Color("45423c")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = border_color
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
