extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _wait_for(predicate: Callable, seconds: float = 30.0) -> bool:
	var timer := 0.0
	while timer < seconds:
		if predicate.call(): return true
		await get_tree().create_timer(0.1, true, false, true).timeout
		timer += 0.1
	return bool(predicate.call())

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _save_preview(filename: String) -> void:
	# Let menu and ending fades finish so previews show the rendered interface.
	await get_tree().create_timer(0.9, true, false, true).timeout
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/" + filename)

func run(menu: Node) -> void:
	await get_tree().process_frame
	var buttons: Array[Node] = menu.get("_main_options").get_children()
	var continue_disabled := false
	for node in buttons:
		if node is Button and node.text == "CONTINUE":
			continue_disabled = node.disabled and not node.tooltip_text.is_empty()
	_check(menu.get("_game") == null and continue_disabled, "main menu is shown before gameplay and Continue explains that progress saves are unavailable")
	var menu_music: AudioStreamPlayer = menu.get("_menu_music")
	_check(menu_music != null and menu_music.stream is AudioStreamMP3 and menu_music.bus == "Music", "main menu assigns the existing exploration track to the Music bus")
	menu.call("_unlock_menu_audio")
	_check(menu_music.playing and bool(menu.get("_audio_unlocked")), "first player input activates menu music through the browser gesture path")
	var backdrop := menu.get("_backdrop") as SubViewportContainer
	var rendered_house: Node = backdrop.get_node_or_null("HouseRender/MenuHouse") if backdrop != null else null
	var menu_camera: Node = backdrop.get_node_or_null("HouseRender/MenuCamera") if backdrop != null else null
	_check(is_instance_valid(rendered_house) and is_instance_valid(menu_camera) and not rendered_house.find_children("*", "MeshInstance3D", true, false).is_empty(), "main menu renders the existing house shell through its own camera without starting gameplay")
	await _save_preview("ui_main_menu_preview.png")
	var menu_body := menu.get("_body") as VBoxContainer
	var title_fade_completed := await _wait_for(func() -> bool: return menu_body != null and menu_body.modulate.a >= 0.99, 2.0)
	var wordmark: Node = menu_body.find_child("FamiliarWordmark", true, false) if menu_body != null else null
	var title_prefix: Node = menu_body.find_child("TitlePrefix", true, false) if menu_body != null else null
	_check(title_fade_completed and is_instance_valid(wordmark) and is_instance_valid(title_prefix) and (title_prefix as Label).text == "THE" and not menu.get("_main_options").get_children().is_empty(), "complete THE FAMILIAR title lockup and menu controls remain visible")
	var old_viewport: Vector2i = get_viewport().size
	var shell_fits := true
	for dimensions in [Vector2i(960,720), Vector2i(1280,720), Vector2i(1920,1080)]:
		get_viewport().size = dimensions
		await get_tree().process_frame
		var shell_rect: Rect2 = menu.get("_shell_panel").get_global_rect()
		shell_fits = shell_fits and shell_rect.position.x >= 0 and shell_rect.position.y >= 0 and shell_rect.end.x <= dimensions.x and shell_rect.end.y <= dimensions.y
	_check(shell_fits, "cinematic main menu panel remains within 960x720, 1280x720 and 1920x1080 viewports")
	get_viewport().size = old_viewport
	menu.call("_show_page", "CONTROLS")
	await _save_preview("ui_controls_preview.png")
	var forward_keys := str(menu.call("_action_keys", "move_forward")).to_upper()
	_check(forward_keys.contains("W") and forward_keys.contains("UP"), "Controls reads the real WASD and arrow bindings from InputMap")
	menu.call("_show_page", "CREDITS")
	await _save_preview("ui_credits_preview.png")
	_check(menu.get("_main_options").get_child_count() >= 2, "Credits page presents project and attribution sections")
	menu.call("_show_page", "SETTINGS")
	await _save_preview("ui_settings_preview.png")
	var sliders: Array = menu.get("_main_options").find_children("*", "HSlider", true, false)
	_check(sliders.size() >= 6, "main menu Settings exposes shared gameplay and audio preferences")
	_check(menu.theme.default_font is SystemFont, "main menu uses the shared serif horror typography theme")
	if not sliders.is_empty():
		var sensitivity_slider := sliders[0] as HSlider
		var original_setting := sensitivity_slider.value
		sensitivity_slider.value = minf(sensitivity_slider.max_value, original_setting + 0.1)
		var saved_settings := ConfigFile.new()
		var settings_saved := saved_settings.load(str(menu.get("settings_path"))) == OK and saved_settings.has_section_key("gameplay", "sensitivity")
		sensitivity_slider.value = original_setting
		_check(settings_saved, "main menu settings persist through the same gameplay ConfigFile")
	menu.call("_show_home")
	for node in menu.get("_main_options").get_children():
		if node is Button and node.text == "NEW GAME":
			node.pressed.emit()
			break
	var initializing_run: Node = menu.get("_game")
	_check(is_instance_valid(initializing_run) and not bool(initializing_run.get("visible")) and menu.visible, "New Game keeps gameplay hidden and the menu visible while the world and instructions initialize")
	var loaded := await _wait_for(func() -> bool:
		var current: Node = menu.get("_game")
		return is_instance_valid(current) and current.get("navigation_is_ready") and current.game_ui.get("intro_active")
	)
	_check(loaded, "New Game creates a fresh house run and displays the existing story introduction")
	if not loaded:
		get_tree().quit(1)
		return
	var game: Node = menu.get("_game")
	_check(game.visible and not menu.visible and not game.music_manager.get("gameplay_enabled") and not game.music_manager.get("active_track_name"), "story instructions are the first visible run layer and gameplay music waits for the opening sequence")
	var environment: Node = game.environment
	_check(environment.get("player_location") == "your_room" and environment.objective_text() == "Leave your bedroom.", "new-game spawn and initial objective place the player in their bedroom")
	_check(not bool(environment.builder.doors.player_bedroom.open) and int(environment.builder.doors.player_bedroom.body.collision_layer) == 8, "bedroom door starts closed with blocking collision")
	for _page in range(3):
		game.game_ui.call("_input", _key(KEY_ENTER))
	var woke := await _wait_for(func() -> bool: return game.game_ui.get("wake_up_active"))
	_check(woke and bool(game.player.get("_qte_locked")) and not game.monster.is_physics_processing(), "story flows into a wake-up cinematic with player and Familiar disabled")
	if woke:
		var wake_camera: Camera3D = game.player.get_node("PlayerCamera")
		var lying_height := wake_camera.position.y
		await get_tree().create_timer(4.4, true, false, true).timeout
		_check(lying_height < 0.6 and wake_camera.position.y > lying_height + 0.1 and wake_camera.position.y < 1.05, "wake-up camera moves through a staged bed-level rise before the final standing pose")
	if woke:
		game.game_ui.call("_skip_wake_up")
	await get_tree().process_frame
	var settled_camera: Camera3D = game.player.get_node("PlayerCamera")
	_check(not get_tree().paused and not bool(game.player.get("_qte_locked")) and game.familiar.is_physics_processing() and settled_camera.position.is_equal_approx(Vector3(0,1.05,0)) and settled_camera.rotation.is_equal_approx(Vector3(deg_to_rad(10),0,0)), "skipping wake-up restores the low upward camera, gameplay, and Familiar exactly once")
	_check(game.music_manager.get("gameplay_enabled") and game.music_manager.get("active_track_name") == "exploration", "exploration music starts after the introduction and wake-up")
	var player_door: Dictionary = environment.builder.doors.player_bedroom
	environment.call("_set_room_door", "player_bedroom", true)
	_check(bool(player_door.open) and int(player_door.body.collision_layer) == 0, "E door action opens the bedroom leaf and clears its collision")
	game.player.global_position = Vector3(0.0, 3.6, -2.0)
	environment.call("_on_player_moved")
	_check(not bool(environment.get("bedroom_departure_pending")) and environment.objective_text() != "Leave your bedroom.", "crossing the bedroom threshold hands off to existing escape objectives")
	environment.call("_set_room_door", "player_bedroom", false)
	_check(not bool(player_door.open) and int(player_door.body.collision_layer) == 8, "E door action closes the bedroom leaf and restores collision")
	game.player.global_position = Vector3(-3.0, 3.6, -3.5)
	var door_blocks_player: bool = game.player.test_move(game.player.global_transform, Vector3(2.0, 0.0, 0.0))
	_check(door_blocks_player, "closed bedroom door blocks the player capsule")
	environment.call("_set_room_door", "player_bedroom", true)
	game.player.global_position = Vector3(-1.2, 3.6, -3.5)
	environment.call("interact", {"kind":"door", "door_id":"player_bedroom", "position":player_door.position})
	_check(bool(player_door.open), "door refuses to close while the player occupies its swing area")
	game.player.global_position = Vector3(-3.0, 3.6, -3.5)
	environment.call("_set_room_door", "player_bedroom", false)
	var previous_monster_position: Vector3 = game.monster.global_position
	var previous_monster_state: int = game.monster.monster_state
	game.monster.global_position = Vector3(-1.2, 0.05, -9.5)
	game.monster.monster_state = MonsterController.State.PURSUING
	game.call("_update_monster_doors", 0.2)
	_check(bool(environment.builder.doors.ground_bathroom.open), "Familiar opens an ordinary closed door while pursuing")
	environment.call("_set_room_door", "ground_bathroom", false)
	game.monster.global_position = previous_monster_position
	game.monster.monster_state = previous_monster_state
	var front: Dictionary = environment.builder.doors.front_door
	environment.call("interact", {"kind":"door", "door_id":"front_door", "position":front.position})
	_check(not bool(front.open) and environment.door_state.front_door == "closed", "jammed front entrance remains restricted by the existing escape design")
	game.game_ui.call("_input", _key(KEY_R))
	_check(menu.get("_game") == game, "R during normal gameplay does not immediately restart")
	game.game_ui.call("open_menu", "OBJECTIVE")
	game.game_ui.call("_input", _key(KEY_R))
	_check(bool(game.game_ui.get("confirmation_active")) and get_tree().paused, "R while paused opens an explicit restart confirmation")
	game.game_ui.call("_input", _key(KEY_ESCAPE))
	_check(not bool(game.game_ui.get("confirmation_active")) and get_tree().paused and menu.get("_game") == game, "Escape cancels restart confirmation without changing the run")
	game.game_ui.call("_input", _key(KEY_R))
	game.game_ui.call("_confirm_action")
	var original_run_id: int = game.get_instance_id()
	var restarted := await _wait_for(func() -> bool:
		var current: Node = menu.get("_game")
		return is_instance_valid(current) and current.get_instance_id() != original_run_id and current.get("navigation_is_ready") and current.game_ui.get("wake_up_active")
	)
	_check(restarted, "explicit restart confirmation creates a clean new run and repeats the bedroom wake-up")
	if not restarted:
		get_tree().quit(1)
		return
	game = menu.get("_game")
	game.game_ui.call("_show_ending", false)
	await _save_preview("ui_capture_ending_preview.png")
	var capture_buttons: Array = game.game_ui.get("_ending_panel").find_children("*", "Button", true, false)
	_check(bool(game.game_ui.get("ending_active")) and game.game_ui.get("_ending_retry_button").visible and game.game_ui.get("_ending_label").text == "GAME OVER" and capture_buttons.size() == 3, "capture ending provides a cinematic GAME OVER screen with Try Again, Main Menu and Quit actions")
	game.game_ui.get("_ending_retry_button").pressed.emit()
	var captured_run_id: int = game.get_instance_id()
	var retried := await _wait_for(func() -> bool:
		var current: Node = menu.get("_game")
		return is_instance_valid(current) and current.get_instance_id() != captured_run_id and current.get("navigation_is_ready") and current.game_ui.get("wake_up_active")
	)
	_check(retried, "Try Again starts a fresh run without another confirmation")
	if not retried:
		get_tree().quit(1)
		return
	game = menu.get("_game")
	game.game_ui.call("open_menu", "OBJECTIVE")
	game.game_ui.call("_show_confirmation", "main_menu")
	game.game_ui.call("_confirm_action")
	await get_tree().process_frame
	_check(menu.get("_game") == null and menu.visible and not get_tree().paused, "confirmed Main Menu return stops and frees the active gameplay session")
	menu.call("_start_run", false)
	var escape_run := await _wait_for(func() -> bool:
		var current: Node = menu.get("_game")
		return is_instance_valid(current) and current.get("navigation_is_ready") and current.game_ui.get("wake_up_active")
	)
	_check(escape_run, "fresh run is available for escape-ending menu review")
	if escape_run:
		game = menu.get("_game")
		game.game_ui.call("_show_ending", true)
		await _save_preview("ui_escape_ending_preview.png")
		var ending_buttons: Array = game.game_ui.get("_ending_panel").find_children("*", "Button", true, false)
		var main_menu_button: Button
		for node in ending_buttons:
			if (node as Button).text == "MAIN MENU": main_menu_button = node as Button
		_check(main_menu_button != null and game.game_ui.get("_ending_retry_button").text == "PLAY AGAIN", "escape ending offers Play Again and Main Menu actions")
		if main_menu_button != null: main_menu_button.pressed.emit()
		await get_tree().process_frame
		_check(menu.get("_game") == null and menu.visible, "ending Main Menu action returns directly without a loss confirmation")
	print("FRONTEND CHECKS: ", checks, " / failures: ", failures)
	get_tree().quit(0 if failures == 0 else 1)
