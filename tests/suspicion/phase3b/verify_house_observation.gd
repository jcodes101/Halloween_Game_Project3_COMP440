extends Node
const Definitions = preload("res://scripts/ItemDefinitions.gd")
var game: Node
var checks := 0
var failures := 0

func _ready() -> void:
	game = get_parent()
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		printerr("FAIL: " + description)

func key(code: int) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func fixture(at: Vector3, target: Vector3) -> void:
	game.player.global_position = at
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player._camera.rotation = Vector3.ZERO
	game.player._camera.look_at(target)

func entry(kind: String) -> Dictionary:
	for value in game.environment._interactables:
		if value.kind == kind:
			return value
	return {}

func _run() -> void:
	var frames := 0
	while not game.navigation_is_ready and frames < 600:
		await get_tree().physics_frame
		frames += 1
	check(game.navigation_is_ready, "preview builds original house and bakes navigation")
	if not game.navigation_is_ready:
		print("NAV DIAGNOSTIC polygons=", game.region.navigation_mesh.get_polygon_count(), " agent_ready=", game.monster.navigation_ready(), " map_active=", NavigationServer3D.map_is_active(game.monster.agent.get_navigation_map()), " world=", game.get_world_3d())
		print("NAV POSITION=", game.monster.global_position, " goal=", game.environment.builder.room_points["Reading Nook"], " path=", NavigationServer3D.map_get_path(game.monster.agent.get_navigation_map(), game.monster.global_position, game.environment.builder.room_points["Reading Nook"], true), " iteration=", NavigationServer3D.map_get_iteration_id(game.monster.agent.get_navigation_map()))
		get_tree().quit(1)
		return
	game.set_physics_process(false)
	game.monster.set_physics_process(false)
	game.familiar.set_physics_process(false)
	game.player.set_physics_process(false)
	var environment: Node = game.environment
	var system: Node = game.observation_coordinator
	var journal: Node = game.story_panel
	check(system.manager.clues_found == 0 and game.familiar.suspicion_level == 0, "preview begins UNAWARE")
	check(environment.memorabilia.size() == 4, "all four memorabilia instantiate in playable house")
	check(game.player.interact_requested.get_connections().size() == 1, "E has exactly one interaction signal receiver")
	var positions: Array[Vector3] = [Vector3(-8.25, 0.05, -2.1), Vector3(8.15, 3.65, -3.8), Vector3(7.1, 3.65, -7.9), Vector3(-7, -3.55, -13.2)]
	for index in 4:
		var item: Node = environment.memorabilia[index]
		var definition := Definitions.get_definition(item.item_id)
		fixture(positions[index], item.get_interaction_position())
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = game.player._capsule_shape
		query.transform = game.player.global_transform * game.player._capsule_node.transform
		query.collision_mask = game.player.collision_mask
		query.exclude = [game.player.get_rid()]
		check(game.player.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "standing inspection position is physically clear: " + item.item_id)
		check(item.get_parent().get_node("Visual").is_visible_in_tree(), "memorabilia visual is visible: " + item.item_id)
		var selected: Dictionary = environment._nearest_interactable()
		check(selected.get("component") == item, "existing aiming/range/obstruction selector reaches: " + item.item_id)
		check(environment.current_interaction_prompt().contains(str(definition.display_name)), "existing prompt names selected memorabilia")
		var pickup_count: int = game.audio.events.get("item_pickup", 0)
		key(KEY_E)
		check(system.manager.clues_found == index + 1, "E awards one new clue: " + item.item_id)
		check(system.inventory.has_item(item.item_id), "E collects memorabilia into shared inventory")
		check(journal.current_clue_id == item.item_id and journal.body.text == str(definition.story_text) and journal.panel.visible, "journal displays exact catalog story")
		check(int(game.audio.events.get("item_pickup", 0)) == pickup_count, "reading triggers no second pickup/noise action")
		var expected_stage := 1 if index < 2 else 2
		check(system.observation.evidence_stage == expected_stage and game.familiar.suspicion_level == system.observation.evidence_score, "clues set correct evidence and familiar stage")
		for _repeat in 3:
			key(KEY_E)
		check(system.manager.clues_found == index + 1, "repeated E never awards duplicate clue")
		key(KEY_J)
		check(not journal.panel.visible and not get_tree().paused and not game.player._qte_locked, "J closes story without locking or pausing gameplay")
		key(KEY_J)
		check(journal.panel.visible, "J reopens the latest story without another inspection")
	game.observation.set_test_suspicion(68)
	check(system.observation.temporary_alertness == 68 and system.observation.evidence_score == 100, "temporary detection updates remain separate from permanent evidence")
	game.observation.set_test_suspicion(0)
	check(system.manager.clues_found == 4 and game.familiar.suspicion_level == 100, "temporary decay cannot lower familiar evidence suspicion")
	game.familiar.hand_off_to_monster()
	game.familiar.reclaim_from_monster()
	check(game.familiar.suspicion_level == 100 and game.familiar.behavior_stage == 2, "familiar reclaim preserves evidence stage")
	# Verify independent blockers before awarding the first clue of a fresh session.
	system.reset_session()
	var first: Node = environment.memorabilia[0]
	fixture(positions[0], first.get_interaction_position())
	game.player.set_qte_locked(true)
	environment._try_interact()
	game.player.set_qte_locked(false)
	check(system.manager.clues_found == 0, "QTE/player lock blocks memorabilia interaction")
	environment.climb_in_progress = true
	environment._try_interact()
	environment.climb_in_progress = false
	check(system.manager.clues_found == 0, "ladder transition blocks memorabilia interaction")
	game._opening_sequence_active = true
	environment._try_interact()
	game._opening_sequence_active = false
	check(system.manager.clues_found == 0, "opening sequence blocks memorabilia interaction")
	game.capture_started = true
	environment._try_interact()
	game.capture_started = false
	check(system.manager.clues_found == 0, "capture blocks memorabilia interaction")
	game.game_ui.open_menu()
	environment._try_interact()
	journal._process(0)
	check(system.manager.clues_found == 0 and not journal.panel.visible, "pause menu blocks inspection and suppresses journal")
	game.game_ui.close_menu()
	fixture(Vector3(-8.25, 0.05, -2.1), Vector3(-7, 1, -2.1))
	check(environment._nearest_interactable().get("component") != first, "looking away cannot inspect memorabilia")
	fixture(Vector3(-4, 0.05, -2.1), first.get_interaction_position())
	key(KEY_E)
	check(system.manager.clues_found == 0, "distant memorabilia cannot be inspected")
	fixture(Vector3(-11.6, 0.05, -2.1), first.get_interaction_position())
	check(environment._nearest_interactable().get("component") != first, "nearby memorabilia cannot be selected through exterior wall/window collision")
	# Native pickups use real selection + E, and escape state stays authoritative.
	fixture(Vector3(5, -3.55, -6.7), entry("crowbar").position)
	key(KEY_E)
	check(environment.has_crowbar and system.inventory.has_crowbar() and not environment.builder.crowbar.visible, "native crowbar pickup mirrors inventory and preserves visual/escape state")
	fixture(Vector3(2.5, 3.65, -5.5), entry("window_key").position)
	key(KEY_E)
	check(environment.has_window_key and system.inventory.has_room_key("attic_window"), "native window key mirrors canonical room-key inventory")
	check(system.manager.clues_found == 0, "escape item pickups award no evidence")
	var door: Dictionary = {"kind": "door", "door_id": "mother_room", "position": environment.builder.doors.mother_room.position}
	var was_open: bool = environment.builder.doors.mother_room.open
	fixture(Vector3(0, 3.65, -3.5), door.position)
	key(KEY_E)
	check(environment.builder.doors.mother_room.open != was_open and system.manager.clues_found == 0, "native door E action does not inspect another item")
	var flashlight: Node = game.player.flashlight
	flashlight.call("_set_battery", 20.0)
	flashlight.call("_set_flashlight_enabled", false)
	key(KEY_F)
	check(flashlight.flashlight_is_on, "flashlight F input still works")
	flashlight.call("_set_flashlight_enabled", false)
	var battery := entry("battery")
	environment.interact(battery)
	check(is_equal_approx(float(flashlight.battery_percent), 55.0), "native battery collection still recharges flashlight")
	environment.interact(entry("hatch"))
	check(environment.attic_open and environment.builder.ladder.visible, "native crowbar still opens hatch and deploys ladder")
	environment.interact(entry("window"))
	check(environment.window_open and environment.builder.window_barrier.collision_layer == 0, "native key still unlocks escape window")
	# A real QTE consumes E without dispatching a world interaction.
	fixture(positions[0], first.get_interaction_position())
	game._start_survival_qte(game.player, 5)
	var qte_keys: Array[int] = [KEY_E]
	game.game_ui._qte_sequence = qte_keys
	game.game_ui._qte_index = 0
	key(KEY_E)
	check(not game.game_ui.qte_active and system.manager.clues_found == 0 and not game.player._qte_locked, "QTE E resolves without inspecting nearby memorabilia")
	print("PHASE 3B CHECKS: %d passed, %d failed (%d checks)" % [checks - failures, failures, checks])
	game.environment.builder.atmosphere.stop_ambience()
	for speaker in game.find_children("*", "AudioStreamPlayer", true, false) + game.find_children("*", "AudioStreamPlayer3D", true, false):
		speaker.stop()
		speaker.stream = null
	var tree := get_tree()
	# Keep the verifier alive while the inherited game's exit cleanup runs.
	reparent(tree.root)
	game.queue_free()
	await tree.process_frame
	await tree.process_frame
	await tree.create_timer(0.2).timeout
	tree.quit(0 if failures == 0 else 1)
