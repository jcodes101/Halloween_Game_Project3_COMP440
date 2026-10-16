extends CanvasLayer
## Nonmodal journal: J dismisses/reopens the last story. It never pauses, locks
## movement, changes mouse capture, or consumes E / flashlight / QTE keys.
var game: Node
var coordinator: Node
var current_clue_id := ""
var requested_open := false
var panel: PanelContainer
var heading: Label
var body: Label
var evidence: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 2
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 24
	margin.offset_top = 145
	margin.offset_right = 420
	margin.offset_bottom = 490
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.03, 0.025, 0.94)
	style.border_color = Color(0.58, 0.43, 0.25)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	heading = _label(column, 18)
	evidence = _label(column, 13)
	body = _label(column, 16)
	body.custom_minimum_size.x = 350
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := _label(column, 13)
	hint.text = "J — close / reopen this memory\nReading does not pause the house."
	panel.hide()

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.92, 0.87, 0.75))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func setup(system: Node, owner_game: Node) -> void:
	coordinator = system
	game = owner_game
	coordinator.story_revealed.connect(show_story)
	coordinator.session_reset.connect(clear_story)

func show_story(id: String, text: String) -> void:
	current_clue_id = id
	heading.text = str(preload("res://scripts/ItemDefinitions.gd").get_definition(id).get("display_name", id))
	body.text = text
	requested_open = true
	_refresh_visibility()

func close_story() -> void:
	requested_open = false
	panel.hide()

func clear_story() -> void:
	current_clue_id = ""
	body.text = ""
	close_story()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_J:
		return
	if not is_instance_valid(game) or not game.environment.observation_interaction_allowed() or current_clue_id.is_empty():
		return
	requested_open = not requested_open
	_refresh_visibility()
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_refresh_visibility()

func _refresh_visibility() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(game):
		return
	panel.visible = requested_open and game.environment.observation_interaction_allowed()
	var stage: int = coordinator.observation.evidence_stage
	evidence.text = "%s — %d clues" % [["UNAWARE", "DOUBTFUL", "CERTAIN"][stage], coordinator.manager.clues_found]
