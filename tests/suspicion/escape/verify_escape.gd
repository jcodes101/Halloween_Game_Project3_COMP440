extends Node
## Run through the normal production menu, not a replacement ending fixture.
var menu: Node
var game: Node
var checks := 0
var failures := 0
var escape_events := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu = get_parent()
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		printerr("FAIL: " + message)

func wait_for(predicate: Callable, seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _count_escape() -> void:
	escape_events += 1

func settle_run() -> bool:
	var ready := await wait_for(func(): return is_instance_valid(menu._game) and menu._game.navigation_is_ready and menu._game.game_ui.wake_up_active)
	if not ready:
		check(false, "production game becomes ready")
		return false
	game = menu._game
	game.game_ui._skip_wake_up()
	game.set_physics_process(false)
	game.monster.set_physics_process(false)
	game.familiar.set_physics_process(false)
	escape_events = 0
	game.environment.escape_completed.connect(_count_escape)
	return true

func entry(kind: String) -> Dictionary:
	for value in game.environment._interactables:
		if value.kind == kind:
			return value
	return {}

func prepare_window() -> void:
	game.environment.interact(entry("crowbar"))
	game.environment.interact(entry("window_key"))
	game.environment.interact(entry("hatch"))
	game.environment.interact(entry("window"))
	game.player.global_position = Vector3(0, 7.25, 10.6)
	game.player.velocity = Vector3.ZERO
	game.player.rotation.y = PI
	game.player._camera.rotation = Vector3.ZERO

func check_memories() -> void:
	for index in 3:
		var item: Node = game.environment.memorabilia[index]
		item.interact(game.player)
		item.interact(game.player)
	check(game.observation_coordinator.manager.clues_found == 3 and game.observation_coordinator.observation.evidence_stage == 2, "memorabilia still progresses to CERTAIN without duplicate clues")
	check(game.story_panel.current_clue_id == game.environment.memorabilia[2].item_id and not game.story_panel.body.text.is_empty(), "existing story panel still receives memorabilia text")

func _run() -> void:
	await get_tree().process_frame
	menu._start_run(false)
	if not await settle_run():
		get_tree().quit(1)
		return
	check_memories()
	for missed_idle in [false, true]:
		var label := "missed render-frame sample" if missed_idle else "normal window jump"
		prepare_window()
		await get_tree().create_timer(0.2).timeout
		check(game.player.is_on_floor(), label + ": jump starts on actual attic floor")
		game.familiar.set_physics_process(true)
		# Test an actual physics jump while delaying only idle environment checks.
		# This reproduces a missed transient crossing without teleporting outside.
		game.environment.set_process(not missed_idle)
		key(KEY_SPACE, true)
		key(KEY_SPACE, false)
		key(KEY_W, true)
		await get_tree().create_timer(1.1).timeout
		check(game.player.global_position.z > 12.3 and game.player.global_position.y < 7.4, label + ": player physically crosses and descends below old detection gate")
		if missed_idle:
			game.familiar.hand_off_to_monster()
			game.familiar.set_physics_process(false)
			game.monster.set_physics_process(true)
		game.environment.set_process(true)
		var escaped := await wait_for(func(): return game.environment.escape_progress == game.environment.EscapeProgress.ESCAPED, 5.0)
		key(KEY_W, false)
		check(escaped, label + ": landing triggers existing escape state")
		check(escape_events == 1, label + ": house emits escape_completed once")
		check(game.game_ui.ending_active and game.game_ui._ending_panel.visible and game.game_ui._ending_label.text == "YOU ESCAPED", label + ": original victory UI appears")
		check(not game.player.is_physics_processing() and not game.player.is_processing_unhandled_input(), label + ": original ending disables player control")
		check(not game.monster.is_physics_processing() and not game.familiar.is_physics_processing(), label + ": original stop-actors callback keeps threat and routine stopped")
		check(not game.environment.observation_interaction_allowed() and not game.story_panel.panel.visible, label + ": memorabilia and journal stop during ending")
		if escaped:
			game.environment._complete_escape()
			game.environment._complete_escape()
			await get_tree().process_frame
			check(escape_events == 1 and game.music_manager.cue_play_counts.escape_ending == 1, label + ": repeated completion cannot repeat signal or ending cue")
			var previous_id: int = game.get_instance_id()
			game.game_ui._ending_retry_button.pressed.emit()
			if not await settle_run():
				get_tree().quit(1)
				return
			check(game.get_instance_id() != previous_id and game.observation_coordinator.manager.clues_found == 0 and game.observation_coordinator.inventory.get_items().is_empty(), label + ": original Play Again creates fresh gameplay and evidence state")
		else:
			print("REPRODUCTION: position=", game.player.global_position, " floor=", game.player.is_on_floor(), " crossed_window=", game.environment.crossed_window, " escape_connections=", game.environment.escape_completed.get_connections().size())
			menu.restart_embedded_game()
			if not await settle_run():
				get_tree().quit(1)
				return
	# The basement is intentionally a false exit, not a second victory route.
	game.environment.interact({"kind":"door", "door_id":"false_exit", "position":Vector3(0,-2.6,12)})
	check(game.environment.false_exit_attempted and game.environment.escape_progress != game.environment.EscapeProgress.ESCAPED and escape_events == 0, "basement false exit does not award victory")
	game.environment.mark_player_captured()
	game.environment._complete_escape()
	check(game.environment.escape_progress == game.environment.EscapeProgress.CAPTURED and game.game_ui._ending_label.text == "GAME OVER" and escape_events == 0, "capture cannot be overwritten by late escape completion")
	var ending_buttons: Array[Node] = game.game_ui._ending_panel.find_children("*", "Button", true, false)
	for button in ending_buttons:
		if button.text == "MAIN MENU":
			button.pressed.emit()
			break
	await get_tree().process_frame
	check(menu._game == null and menu.visible and not get_tree().paused, "original ending Main Menu action frees game and returns to menu")
	print("ESCAPE CHECKS: %d passed, %d failed (%d checks)" % [checks - failures, failures, checks])
	var tree := get_tree()
	for speaker in menu.find_children("*", "AudioStreamPlayer", true, false) + menu.find_children("*", "AudioStreamPlayer3D", true, false):
		speaker.stop()
		speaker.stream = null
	reparent(tree.root)
	menu.queue_free()
	await tree.process_frame
	await tree.create_timer(0.2).timeout
	tree.quit(0 if failures == 0 else 1)
