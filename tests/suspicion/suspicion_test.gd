extends Node3D
## Standalone Phase 3A lab. Buttons exercise the real components; no shared UI.
const CoordinatorScene = preload("res://scripts/observation/scenes/observation_system.tscn")
const Definitions = preload("res://scripts/ItemDefinitions.gd")
const Collectible = preload("res://scripts/CollectibleItem.gd")
const Interaction = preload("res://scripts/PlayerInteractionComponent.gd")
const ExistingObservation = preload("res://game/integration/test_observation.gd")
const MEMORIES = [
	preload("res://scripts/observation/scenes/mom_recipe_card.tscn"),
	preload("res://scripts/observation/scenes/mom_unfinished_letter.tscn"),
	preload("res://scripts/observation/scenes/mimic_rehearsal_notes.tscn"),
	preload("res://scripts/observation/scenes/mimic_family_photograph.tscn")
]

var coordinator: Node = CoordinatorScene.instantiate()
var detection := ExistingObservation.new()
var interaction := Interaction.new()
var origin := Node3D.new()
var memories: Array[Node] = []
var tools: Array[Node] = []
var status: Label
var story: Label
var story_id := ""

func _ready() -> void:
	add_child(coordinator)
	add_child(detection)
	coordinator.observation.bind_alertness_source(detection)
	add_child(origin)
	interaction.interaction_origin = origin
	interaction.player = origin
	add_child(interaction)
	for index in MEMORIES.size():
		var prop: Node3D = MEMORIES[index].instantiate()
		prop.position = Vector3(index * 6.0, 0, 0)
		add_child(prop)
		var item: Node = prop.get_node("Interaction")
		coordinator.bind_item(item)
		memories.append(item)
	for index in 3:
		var tool := Collectible.new()
		tool.item_type = ["basement_key", "crowbar", "room_key"][index]
		tool.room_id = "attic_window" if index == 2 else ""
		tool.position = Vector3(30 + index * 6, 0, 0)
		coordinator.bind_item(tool)
		add_child(tool)
		tools.append(tool)
	_build_ui()
	coordinator.story_revealed.connect(_show_story)
	coordinator.observation.evidence_changed.connect(func(_stage, _score, _clues): _refresh())
	coordinator.observation.suspicion_changed.connect(func(_level): _refresh())
	coordinator.inventory.item_collected.connect(func(_id): _refresh())
	coordinator.session_reset.connect(_clear_story)
	_refresh()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(850, 600)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := Label.new()
	title.text = "PHASE 3A — ISOLATED SUSPICION LAB\nCollect alone adds no evidence. Inspect three unique items to reach CERTAIN."
	box.add_child(title)
	status = Label.new()
	box.add_child(status)
	for item in memories:
		var row := HBoxContainer.new()
		box.add_child(row)
		var definition := Definitions.get_definition(item.item_id)
		_button(row, "Collect: " + str(definition.display_name), func(): item.collect(); _refresh())
		_button(row, "Inspect / reread", func(): item.inspect())
		_button(row, "Interact (collect + inspect)", func(): interact_with(item))
	for tool in tools:
		_button(box, "Collect " + str(tool.get_definition().display_name), func(): interact_with(tool))
	var alert_row := HBoxContainer.new()
	box.add_child(alert_row)
	for value in [0.0, 50.0, 100.0]:
		_button(alert_row, "Detection alertness %d" % value, func(): detection.set_test_suspicion(value))
	_button(box, "Reset evidence + inventory (keep alertness)", func(): coordinator.reset_session())
	_button(box, "Reset lab including detection", func(): detection.set_test_suspicion(0); coordinator.reset_session())
	story = Label.new()
	story.custom_minimum_size = Vector2(800, 150)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(story)
	_clear_story()

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

## Move only the lab's interaction origin; exercise the unchanged proximity
## component with one target in range, rather than bypassing its dispatch.
func interact_with(item: Node) -> Variant:
	origin.global_position = item.get_interaction_position()
	return interaction.interact()

func _show_story(id: String, text: String) -> void:
	story_id = id
	story.text = str(Definitions.get_definition(id).get("display_name", id)) + "\n\n" + text
	_refresh()

func _clear_story() -> void:
	story_id = ""
	story.text = "Select Inspect to read a memory. Repeat inspections are safe."
	_refresh()

func _refresh() -> void:
	if status == null:
		return
	var manager: Node = coordinator.manager
	status.text = "Evidence: %s | %d clues | score %.0f\nTemporary monster alertness: %.0f\nInventory: %s" % [
		["UNAWARE", "DOUBTFUL", "CERTAIN"][manager.suspicion_level], manager.clues_found,
		coordinator.observation.evidence_score, coordinator.observation.temporary_alertness,
		", ".join(coordinator.inventory.get_items().keys())]
