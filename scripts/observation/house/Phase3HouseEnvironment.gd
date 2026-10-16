extends "res://game/house/house_environment.gd"
## Register components in the house's existing selector; never add an E handler.
const Placements = preload("res://scripts/observation/house/house_memorabilia.tscn")
var memorabilia: Array[Node] = []
var _observation_game: Node
var _coordinator: Node

func _physics_process(_delta: float) -> void:
	# The inherited idle check can miss the brief airborne window crossing.
	# Latch the same eligibility at movement cadence; the parent still owns
	# ground-landing detection, escape_completed, controls and the ending UI.
	if escape_progress in [EscapeProgress.ESCAPED, EscapeProgress.CAPTURED]:
		return
	var at: Vector3 = _player.global_position
	if window_open and at.z > 12.3 and absf(at.x) < 1.5 and at.y > 7.4 and _player.jump_count > _window_jump_count:
		crossed_window = true

func _complete_escape() -> void:
	# Completion may be requested by more than one observer. Preserve terminal
	# outcomes and forward the first success to the original implementation only.
	if escape_progress in [EscapeProgress.ESCAPED, EscapeProgress.CAPTURED]:
		return
	super()

func _build_world() -> void:
	super()
	var props := Placements.instantiate()
	add_child(props)
	for prop in props.get_children():
		var component: Node = prop.get_node("Interaction")
		memorabilia.append(component)
		var definition: Dictionary = component.Definitions.get_definition(component.item_id)
		_interactables.append({
			"title": str(definition.display_name), "kind": "memorabilia",
			"position": component.get_interaction_position(),
			"prompt": "[E] Inspect " + str(definition.display_name),
			"component": component
		})

func configure_observation(coordinator: Node, game: Node) -> void:
	_coordinator = coordinator
	_observation_game = game
	for component in memorabilia:
		_coordinator.bind_item(component)

func observation_interaction_allowed() -> bool:
	if not is_instance_valid(_observation_game) or not _observation_game.navigation_is_ready:
		return false
	if get_tree().paused or _observation_game._opening_sequence_active or _observation_game.capture_started:
		return false
	if is_hidden or climb_in_progress or _player.is_transitioning() or _player._qte_locked:
		return false
	if escape_progress in [EscapeProgress.ESCAPED, EscapeProgress.CAPTURED]:
		return false
	var ui: Node = _observation_game.game_ui
	return is_instance_valid(ui) and not (ui.menu_open or ui.qte_active or ui.intro_active or ui.wake_up_active or ui.ending_active)

func _try_interact() -> void:
	if not observation_interaction_allowed():
		return
	super()

func interact(target: Dictionary) -> void:
	if str(target.get("kind", "")) != "memorabilia":
		super(target)
		return
	if not observation_interaction_allowed():
		return
	var component: Node = target.get("component")
	if is_instance_valid(component) and component.can_interact():
		component.interact(_player)
		# Quiet reading adds no detection noise. Existing pickup/door noise remains.
		environment_state_changed.emit()

func current_interaction_prompt() -> String:
	if is_hidden:
		return super()
	return super() if observation_interaction_allowed() else ""
