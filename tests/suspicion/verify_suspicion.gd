extends SceneTree
## Exit code 0 = all checks passed; 1 = assertion failure.
const Lab = preload("res://tests/suspicion/suspicion_test.tscn")
const ExistingObservation = preload("res://game/integration/test_observation.gd")
var checks := 0
var failures := 0
var clue_events: Array[String] = []
var stages: Array[int] = []
var stories: Array[String] = []
var alert_events: Array[float] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		printerr("FAIL: " + description)

func _run() -> void:
	var lab: Node = Lab.instantiate()
	root.add_child(lab)
	await process_frame
	var system: Node = lab.coordinator
	var manager: Node = system.manager
	var inventory: Node = system.inventory
	var observation: Node = system.observation
	manager.clue_discovered.connect(func(id: String): clue_events.append(id))
	manager.suspicion_changed.connect(func(stage: int): stages.append(stage))
	system.story_revealed.connect(func(id: String, _story: String): stories.append(id))
	observation.suspicion_changed.connect(func(level: float): alert_events.append(level))
	check(manager.clues_found == 0 and observation.evidence_stage == 0, "fresh session is UNAWARE")
	check(observation.evidence_score == 0.0 and observation.temporary_alertness == 0.0, "both channels start at zero")
	check(lab.memories.size() == 4, "all four reusable scenes instantiate")
	for item in lab.memories:
		check(item.is_valid_memorabilia() and item.can_interact(), "catalog identity and dependencies: " + item.item_id)
		check(item.get_parent().get_node("Visual").mesh != null, "physical visual exists: " + item.item_id)
	lab.detection.set_test_suspicion(73.0)
	check(observation.suspicion_level == 73.0 and observation.temporary_alertness == 73.0, "existing observation source feeds temporary alertness")
	check(observation.evidence_score == 0.0, "detection does not award evidence")
	var first: Node = lab.memories[0]
	check(first.notice() and not first.notice(), "anomaly notice is deduplicated")
	check(manager.clues_found == 0 and inventory.get_items().is_empty(), "notice neither collects nor confirms")
	check(first.collect() and not first.collect(), "collection is unique")
	check(manager.clues_found == 0 and observation.evidence_stage == 0, "collection alone leaves UNAWARE")
	var expected: String = first.Definitions.get_definition(first.item_id).story_text
	check(first.inspect() == expected, "inspection returns catalog story")
	check(manager.clues_found == 1 and observation.evidence_stage == 1 and observation.evidence_score == 50.0, "first inspection reaches DOUBTFUL")
	check(lab.story_id == first.item_id and lab.story.text.contains(expected), "story is displayed in lab UI")
	for _index in 5:
		check(lab.interact_with(first) == expected, "repeated interaction returns story")
	check(manager.clues_found == 1 and clue_events.size() == 1, "repeated inspection awards exactly one clue event")
	check(stories.size() == 6, "rereading emits story on every inspection")
	check(observation.temporary_alertness == 73.0 and alert_events.size() == 1, "evidence never writes temporary alertness")
	var duplicate: Node3D = lab.MEMORIES[0].instantiate()
	duplicate.position = Vector3(-12, 0, 0)
	lab.add_child(duplicate)
	var duplicate_item: Node = duplicate.get_node("Interaction")
	system.bind_item(duplicate_item)
	system.bind_item(duplicate_item)
	var story_count := stories.size()
	duplicate_item.interact()
	check(manager.clues_found == 1 and clue_events.size() == 1, "duplicate physical instance cannot award another clue")
	check(stories.size() == story_count + 1, "binding twice does not duplicate story connections")
	lab.interact_with(lab.memories[1])
	check(manager.clues_found == 2 and observation.evidence_stage == 1, "second unique clue remains DOUBTFUL")
	lab.interact_with(lab.memories[2])
	check(manager.clues_found == 3 and observation.evidence_stage == 2 and observation.evidence_score == 100.0, "third unique clue reaches CERTAIN")
	lab.interact_with(lab.memories[3])
	check(manager.clues_found == 4 and clue_events.size() == 4, "all four unique clues count once")
	check(stages == [1, 2], "only expected stage transitions are emitted")
	lab.detection.set_test_suspicion(0.0)
	check(observation.evidence_stage == 2 and manager.clues_found == 4, "alertness decay cannot erase evidence")
	for tool in lab.tools:
		check(lab.interact_with(tool) == true, "tool/key can be collected through unchanged interaction component")
		check(lab.interact_with(tool) == null, "collected tool/key is no longer selectable")
	check(inventory.has_basement_key() and inventory.has_crowbar() and inventory.has_room_key("attic_window"), "existing inventory queries recognize keys and crowbar")
	check(manager.clues_found == 4, "keys and tools never award evidence")
	lab.origin.global_position = Vector3(500, 0, 0)
	check(lab.interaction.interact() == null, "out-of-range interaction does nothing")
	var copy: Dictionary = manager.get_collected_evidence()
	copy.clear()
	var bag_copy: Dictionary = inventory.get_items()
	bag_copy.clear()
	check(manager.clues_found == 4 and inventory.get_items().size() == 7, "external dictionary edits cannot mutate stored state")
	lab.detection.set_test_suspicion(62.0)
	system.reset_session()
	check(manager.clues_found == 0 and not manager.noticed_anomaly and observation.evidence_stage == 0, "reset clears evidence, anomalies and stage")
	check(inventory.get_items().is_empty() and lab.story_id.is_empty(), "reset clears inventory and displayed story")
	check(observation.temporary_alertness == 62.0 and lab.detection.suspicion_level == 62.0, "default reset preserves temporary source and mirror")
	check(first.notice(), "same anomaly can be noticed after reset")
	lab.interact_with(first)
	check(manager.clues_found == 1 and inventory.has_item(first.item_id), "same instance can collect and award evidence after reset")
	lab.interact_with(duplicate_item)
	check(manager.clues_found == 1, "duplicate remains deduplicated after reset")
	system.reset_session()
	system.reset_session()
	check(manager.clues_found == 0 and observation.evidence_score == 0.0, "repeated empty resets remain consistent")
	check(lab.tools[0].can_interact(), "reset restores tool availability")
	manager.doubtful_threshold = 2
	manager.certain_threshold = 4
	for index in 3:
		lab.interact_with(lab.memories[index])
	check(observation.evidence_stage == 1, "custom threshold keeps three clues DOUBTFUL")
	lab.interact_with(lab.memories[3])
	check(observation.evidence_stage == 2, "custom threshold reaches CERTAIN at four clues")
	manager.reset()
	check(observation.evidence_stage == 0, "direct manager reset updates adapter stage")
	var second_source := ExistingObservation.new()
	lab.add_child(second_source)
	second_source.set_test_suspicion(25.0)
	observation.bind_alertness_source(second_source)
	lab.detection.set_test_suspicion(99.0)
	check(observation.temporary_alertness == 25.0, "rebinding snapshots new source and disconnects old source")
	second_source.set_test_suspicion(45.0)
	check(observation.temporary_alertness == 45.0 and second_source.suspicion_level == 45.0, "new source drives mirror without feedback")
	observation.bind_alertness_source(null)
	second_source.set_test_suspicion(80.0)
	check(observation.temporary_alertness == 45.0, "unbinding stops source updates")
	observation.set_test_suspicion(150.0)
	check(observation.suspicion_level == 100.0, "compatibility setter clamps upper bound")
	observation.set_test_suspicion(-10.0)
	check(observation.suspicion_level == 0.0, "compatibility setter clamps lower bound")
	observation.set_test_suspicion(NAN)
	check(observation.suspicion_level == 0.0, "invalid numeric alertness is ignored")
	observation.set_test_suspicion(60.0)
	system.reset_session(true)
	check(observation.temporary_alertness == 0.0 and second_source.suspicion_level == 80.0, "explicit local alertness reset does not overwrite external source")
	manager.doubtful_threshold = 1
	manager.certain_threshold = 3
	var buttons: Array[Node] = lab.find_children("*", "Button", true, false)
	for index in 4:
		var item: Node = lab.memories[index]
		buttons[index * 3].pressed.emit()
		check(inventory.has_item(item.item_id) and manager.clues_found == index, "UI Collect button binds correct item without inspecting")
		buttons[index * 3 + 1].pressed.emit()
		check(lab.story_id == item.item_id and manager.clues_found == index + 1, "UI Inspect button displays correct item's story")
		buttons[index * 3 + 2].pressed.emit()
		check(manager.clues_found == index + 1, "UI Interact button safely rereads correct item")
	buttons[18].pressed.emit()
	check(inventory.get_items().is_empty() and manager.clues_found == 0, "UI Reset button clears session")
	buttons[17].pressed.emit()
	check(observation.temporary_alertness == 0.0 and lab.detection.suspicion_level == 100.0, "UI detection button targets source; unbound mirror stays independent")
	observation.bind_alertness_source(lab.detection)
	buttons[19].pressed.emit()
	check(observation.temporary_alertness == 0.0 and lab.detection.suspicion_level == 0.0, "UI full reset clears lab-owned detection source")
	print("SUSPICION TESTS: %d passed, %d failed (%d checks)" % [checks - failures, failures, checks])
	lab.free()
	quit(0 if failures == 0 else 1)
