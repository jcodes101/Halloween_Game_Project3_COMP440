extends Node3D
## Dedicated test scene demonstrating Familiar Behavior System with the actual Mother character.
## Features both First-Person POV and Overhead Camera perspectives, Skeleton3D procedural
## posing, behavior stages, the 9-step Certain contortion sequence, and Monster System handoff.

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")
const FamiliarController = preload("res://systems/familiar/familiar_controller.gd")
const MotherVisualAdapter = preload("res://systems/familiar/mother_visual_adapter.gd")
const TestFirstPersonPlayer = preload("res://tests/familiar/test_first_person_player.gd")

@onready var familiar: FamiliarController = $Familiar
@onready var mother_adapter: MotherVisualAdapter = $Familiar/MotherVisualAdapter
@onready var fp_player: TestFirstPersonPlayer = $TestPlayer
@onready var overhead_camera: Camera3D = $OverheadCamera3D

# UI Controls
@onready var suspicion_slider: HSlider = %SuspicionSlider
@onready var suspicion_val_label: Label = %SuspicionValueLabel
@onready var stage_label: Label = %StageLabel
@onready var trust_label: Label = %TrustLabel
@onready var action_label: Label = %ActionLabel
@onready var normal_label: Label = %NormalLabel
@onready var cue_label: Label = %CueLabel
@onready var distance_label: Label = %DistanceLabel
@onready var handoff_label: Label = %HandoffLabel
@onready var camera_mode_label: Label = %CameraModeLabel

# Stations
@onready var station_kitchen: Node3D = $Stations/KitchenStation
@onready var station_dining: Node3D = $Stations/DiningStation
@onready var station_bookshelf: Node3D = $Stations/BookshelfStation
@onready var station_pantry: Node3D = $Stations/PantryStation

var is_first_person: bool = true

func _ready() -> void:
	_setup_stations()
	_setup_camera_mode()
	_connect_signals()
	_update_ui()

func _setup_stations() -> void:
	if familiar:
		familiar.routine_stations = [
			station_kitchen,
			station_dining,
			station_bookshelf,
			station_pantry
		]
		familiar.player_target = fp_player

func _setup_camera_mode() -> void:
	if is_first_person:
		if fp_player:
			fp_player.set_active(true)
		if overhead_camera:
			overhead_camera.current = false
	else:
		if fp_player:
			fp_player.set_active(false)
		if overhead_camera:
			overhead_camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_V:
			_toggle_camera_mode()

func _toggle_camera_mode() -> void:
	is_first_person = not is_first_person
	_setup_camera_mode()
	_update_ui()

func _connect_signals() -> void:
	if not familiar:
		return
	
	familiar.behavior_stage_changed.connect(func(_p, _n): _update_ui())
	familiar.action_changed.connect(func(_p, _n): _update_ui())
	familiar.acting_normal_changed.connect(func(_n): _update_ui())
	familiar.trust_level_changed.connect(func(_t): _update_ui())
	familiar.cue_emitted.connect(func(txt): if cue_label: cue_label.text = '"%s"' % txt)
	familiar.greeting_emitted.connect(func(msg): if cue_label: cue_label.text = 'Greeting: "%s"' % msg)
	familiar.monster_handoff_started.connect(_update_ui)
	familiar.monster_handoff_ended.connect(_update_ui)
	
	if suspicion_slider:
		suspicion_slider.value_changed.connect(_on_suspicion_changed)
	
	var btn_normal: Button = %BtnNormal
	var btn_doubtful: Button = %BtnDoubtful
	var btn_certain: Button = %BtnCertain
	var btn_near: Button = %BtnPlayerNear
	var btn_far: Button = %BtnPlayerFar
	var btn_next: Button = %BtnNextRoutine
	var btn_pause: Button = %BtnForcePause
	var btn_handoff: Button = %BtnToggleHandoff
	var btn_camera: Button = %BtnToggleCamera
	var btn_capture: Button = %BtnCaptureMouse
	
	if btn_normal: btn_normal.pressed.connect(func(): _set_suspicion(10.0))
	if btn_doubtful: btn_doubtful.pressed.connect(func(): _set_suspicion(50.0))
	if btn_certain: btn_certain.pressed.connect(func(): _set_suspicion(85.0))
	if btn_near: btn_near.pressed.connect(_teleport_player_near)
	if btn_far: btn_far.pressed.connect(_teleport_player_far)
	if btn_next: btn_next.pressed.connect(func(): familiar.force_next_station())
	if btn_pause: btn_pause.pressed.connect(func(): familiar.force_pause())
	if btn_handoff: btn_handoff.pressed.connect(_toggle_monster_handoff)
	if btn_camera: btn_camera.pressed.connect(_toggle_camera_mode)
	if btn_capture: btn_capture.pressed.connect(func(): if fp_player and is_first_person: fp_player.capture_mouse())

func _process(_delta: float) -> void:
	_update_ui()

func _on_suspicion_changed(val: float) -> void:
	if familiar:
		familiar.set_suspicion_level(val)
	_update_ui()

func _set_suspicion(val: float) -> void:
	if suspicion_slider:
		suspicion_slider.value = val
	if familiar:
		familiar.set_suspicion_level(val)
	_update_ui()

func _teleport_player_near() -> void:
	if fp_player and familiar:
		# Place player 2 meters in front of familiar
		var forward_dir := -familiar.global_transform.basis.z.normalized()
		fp_player.global_position = familiar.global_position + (forward_dir * 2.0)
		fp_player.look_at(familiar.global_position + Vector3(0, 1.5, 0))

func _teleport_player_far() -> void:
	if fp_player:
		fp_player.global_position = Vector3(0.0, 0.0, 6.5)

func _toggle_monster_handoff() -> void:
	if not familiar:
		return
	if familiar.is_monster_controlled:
		familiar.reclaim_from_monster()
	else:
		familiar.hand_off_to_monster()
	_update_ui()

func _update_ui() -> void:
	if not familiar:
		return
	
	var snapshot := familiar.get_observation_snapshot()
	
	if suspicion_val_label:
		suspicion_val_label.text = "%.0f%%" % snapshot["suspicion_level"]
	
	if stage_label:
		stage_label.text = snapshot["stage_name"]
		match snapshot["behavior_stage"]:
			FamiliarConstants.BehaviorStage.NORMAL:
				stage_label.modulate = Color(0.2, 0.9, 0.3)
			FamiliarConstants.BehaviorStage.DOUBTFUL:
				stage_label.modulate = Color(0.95, 0.8, 0.2)
			FamiliarConstants.BehaviorStage.CERTAIN:
				stage_label.modulate = Color(0.95, 0.2, 0.2)
	
	if trust_label:
		trust_label.text = "%.1f%%" % snapshot["trust_level"]
	
	if action_label:
		action_label.text = snapshot["current_action"]
	
	if normal_label:
		var is_normal: bool = snapshot["is_acting_normal"]
		normal_label.text = "YES (Natural)" if is_normal else "NO (Abnormal / Glitched)"
		normal_label.modulate = Color(0.2, 0.9, 0.3) if is_normal else Color(0.95, 0.3, 0.2)
	
	if distance_label and fp_player and familiar:
		var dist: float = familiar.global_position.distance_to(fp_player.global_position)
		distance_label.text = "%.2f m" % dist
	
	if handoff_label:
		if familiar.is_monster_controlled:
			handoff_label.text = "CONTROL: MONSTER SYSTEM (Overrides Released)"
			handoff_label.modulate = Color(0.95, 0.2, 0.2)
		else:
			handoff_label.text = "CONTROL: FAMILIAR SYSTEM (Procedural Bones Active)"
			handoff_label.modulate = Color(0.3, 0.8, 0.95)
	
	if camera_mode_label:
		if is_first_person:
			camera_mode_label.text = "POV: FIRST-PERSON ([Esc] free mouse | [V] toggle view)"
			camera_mode_label.modulate = Color(0.4, 0.9, 0.4)
		else:
			camera_mode_label.text = "POV: OVERHEAD CAMERA ([V] toggle view)"
			camera_mode_label.modulate = Color(0.9, 0.8, 0.3)
