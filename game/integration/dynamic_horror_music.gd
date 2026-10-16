extends Node
## State-driven score plus non-looping encounter/ending cues.

const MonsterController = preload("res://systems/monster/monster_controller.gd")
const SILENT_DB := -60.0
const LOOP_TRACKS := ["exploration", "investigation", "chase", "hiding"]
const CUE_TRACKS := ["qte_sting", "escape_ending", "capture_ending"]
const EXTENSIONS := ["ogg", "mp3", "wav"]

@export_range(0.5, 8.0, 0.1) var crossfade_seconds := 2.5
@export_range(-36.0, 0.0, 0.5) var target_volume_db := -14.0
@export_range(1.0, 40.0, 0.5) var hiding_threat_distance := 14.0

var monster: Node
var current_mood := ""
var active_track_name := ""
var exploration_track: AudioStream
var investigation_track: AudioStream
var chase_track: AudioStream
var hiding_track: AudioStream
var qte_sting_track: AudioStream
var escape_ending_track: AudioStream
var capture_ending_track: AudioStream
var detected_assets: Dictionary = {}
var missing_assets: Array[String] = []
var cue_play_counts: Dictionary = {"qte_sting": 0, "escape_ending": 0, "capture_ending": 0}
var _players: Dictionary = {}
var _active_player: AudioStreamPlayer
var _cue_player: AudioStreamPlayer
var _hiding_requested := false
var _ending_locked := false

func setup(monster_node: Node, exploration: AudioStream = null, investigation: AudioStream = null, chase: AudioStream = null) -> void:
	monster = monster_node
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_discover_tracks()
	# Explicitly assigned legacy tracks remain supported and take precedence.
	if exploration != null: exploration_track = exploration
	if investigation != null: investigation_track = investigation
	if chase != null: chase_track = chase
	for mood in LOOP_TRACKS:
		_create_player(mood, _track_for_mood(mood))
	_cue_player = AudioStreamPlayer.new()
	_cue_player.name = "HorrorMusicCue"
	_cue_player.bus = "Music"
	_cue_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_cue_player.volume_db = target_volume_db
	add_child(_cue_player)
	if is_instance_valid(monster) and monster.has_signal("state_changed"):
		monster.state_changed.connect(_on_monster_state_changed)
		set_monster_state(int(monster.get("monster_state")))

func _discover_tracks() -> void:
	var found: Dictionary = {}
	var directory := DirAccess.open("res://assets/audio/music")
	if directory != null:
		for file_name in directory.get_files():
			var lower := file_name.to_lower()
			var extension := lower.get_extension()
			if extension not in EXTENSIONS:
				continue
			var stem := lower.get_basename()
			if stem in LOOP_TRACKS or stem in CUE_TRACKS:
				if not found.has(stem):
					found[stem] = "res://assets/audio/music/" + file_name
	for stem in LOOP_TRACKS + CUE_TRACKS:
		var stream: AudioStream
		if found.has(stem):
			stream = load(found[stem]) as AudioStream
			if stream == null:
				missing_assets.append(stem)
				push_warning("Horror music asset could not be loaded: " + str(found[stem]))
			else:
				detected_assets[stem] = found[stem]
		else:
			missing_assets.append(stem)
		match stem:
			"exploration": exploration_track = stream
			"investigation": investigation_track = stream
			"chase": chase_track = stream
			"hiding": hiding_track = stream
			"qte_sting": qte_sting_track = stream
			"escape_ending": escape_ending_track = stream
			"capture_ending": capture_ending_track = stream
		if stem in LOOP_TRACKS and stream != null:
			_configure_loop(stream)
		elif stem in CUE_TRACKS and stream != null:
			_configure_one_shot(stream)
	print("Horror music assets detected: ", detected_assets)
	if not missing_assets.is_empty():
		push_warning("Horror music assets missing: " + ", ".join(missing_assets))

func _configure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func _configure_one_shot(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED

func configure_tracks(exploration: AudioStream, investigation: AudioStream, chase: AudioStream) -> void:
	exploration_track = exploration
	investigation_track = investigation
	chase_track = chase
	for mood in ["exploration", "investigation", "chase"]:
		var stream := _track_for_mood(mood)
		if stream != null: _configure_loop(stream)
		_set_player_stream(mood, stream)
	active_track_name = ""
	_active_player = null
	if is_instance_valid(monster): set_monster_state(int(monster.get("monster_state")))

func set_monster_state(state: int) -> void:
	var mood := "exploration"
	if state == MonsterController.State.CAPTURED:
		mood = "silence"
	elif state == MonsterController.State.PURSUING:
		mood = "chase"
	elif state in [MonsterController.State.STALKING, MonsterController.State.SEARCHING, MonsterController.State.LOST_TARGET, MonsterController.State.INTERCEPTING, MonsterController.State.REVEALING]:
		mood = "investigation"
	current_mood = mood
	_select_gameplay_music()

func set_hiding_context(is_hidden: bool, threat_nearby: bool) -> void:
	_hiding_requested = is_hidden and threat_nearby
	_select_gameplay_music()

func play_qte_sting() -> void:
	_play_event_cue("qte_sting")

func play_ending_cue(escaped: bool) -> void:
	if _ending_locked: return
	_ending_locked = true
	_hiding_requested = false
	current_mood = "silence"
	_select_gameplay_music()
	_play_event_cue("escape_ending" if escaped else "capture_ending", true)

func reset_run() -> void:
	_ending_locked = false
	_hiding_requested = false
	if is_instance_valid(_cue_player): _cue_player.stop()
	if is_instance_valid(monster): set_monster_state(int(monster.get("monster_state")))

func cleanup() -> void:
	_ending_locked = true
	_hiding_requested = false
	for player in _players.values():
		if is_instance_valid(player): player.stop()
	if is_instance_valid(_cue_player): _cue_player.stop()
	_active_player = null
	active_track_name = ""

func has_track_for_state(state: int) -> bool:
	var mood := "exploration"
	if state == MonsterController.State.CAPTURED: return false
	if state == MonsterController.State.PURSUING: mood = "chase"
	elif state in [MonsterController.State.STALKING, MonsterController.State.SEARCHING, MonsterController.State.LOST_TARGET, MonsterController.State.INTERCEPTING, MonsterController.State.REVEALING]: mood = "investigation"
	return _track_for_mood(mood) != null

func has_asset(stem: String) -> bool:
	return detected_assets.has(stem)

func _create_player(mood: String, stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.name = mood.capitalize() + "Music"
	player.bus = "Music"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.volume_db = SILENT_DB
	player.stream = stream
	player.finished.connect(_on_track_finished.bind(player))
	add_child(player)
	_players[mood] = player

func _set_player_stream(mood: String, stream: AudioStream) -> void:
	var player := _players.get(mood) as AudioStreamPlayer
	if not is_instance_valid(player): return
	if player.playing: player.stop()
	player.stream = stream
	player.volume_db = SILENT_DB

func _select_gameplay_music() -> void:
	if _ending_locked:
		_active_player = null
		active_track_name = ""
		return
	var mood := "silence"
	if _hiding_requested and hiding_track != null:
		mood = "hiding"
	elif current_mood != "silence":
		mood = current_mood
	active_track_name = mood if _track_for_mood(mood) != null else ""
	_active_player = _players.get(mood) as AudioStreamPlayer if not active_track_name.is_empty() else null
	if is_instance_valid(_active_player) and not _active_player.playing:
		_active_player.volume_db = SILENT_DB
		_active_player.play()

func _play_event_cue(stem: String, ending := false) -> void:
	if not is_instance_valid(_cue_player): return
	var stream: AudioStream
	match stem:
		"qte_sting": stream = qte_sting_track
		"escape_ending": stream = escape_ending_track
		"capture_ending": stream = capture_ending_track
	if stream == null:
		if ending: return
		return
	cue_play_counts[stem] = int(cue_play_counts.get(stem, 0)) + 1
	_cue_player.stop()
	_cue_player.stream = stream
	_cue_player.volume_db = target_volume_db
	_cue_player.play()

func _on_monster_state_changed(_previous: int, next: int) -> void:
	set_monster_state(next)

func _process(delta: float) -> void:
	var fade_rate := 60.0 / maxf(crossfade_seconds, 0.05)
	for mood in _players:
		var player := _players[mood] as AudioStreamPlayer
		if not is_instance_valid(player): continue
		if player == _active_player:
			player.volume_db = move_toward(player.volume_db, target_volume_db, fade_rate * delta)
		elif player.playing:
			player.volume_db = move_toward(player.volume_db, SILENT_DB, fade_rate * delta)
			if player.volume_db <= SILENT_DB + 0.05: player.stop()

func _on_track_finished(player: AudioStreamPlayer) -> void:
	if player == _active_player and player.stream != null and not _ending_locked:
		player.play()

func _track_for_mood(mood: String) -> AudioStream:
	match mood:
		"silence": return null
		"investigation": return investigation_track
		"chase": return chase_track
		"hiding": return hiding_track
		_: return exploration_track
