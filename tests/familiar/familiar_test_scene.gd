extends Node3D

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")
const FamiliarController = preload("res://systems/familiar/familiar_controller.gd")
## Interactive test scene controller for the Familiar Behavior System.
## Allows manual tuning of suspicion level and demonstration of all three stages.

@onready var familiar: FamiliarController = $Familiar
@onready var player_dummy: Node3D = $PlayerDummy
@onready var camera: Camera3D = $Camera3D

# UI Nodes
@onready var suspicion_slider: HSlider = %SuspicionSlider
@onready var suspicion_val_label: Label = %SuspicionValueLabel
@onready var stage_label: Label = %StageLabel
@onready var trust_label: Label = %TrustLabel
@onready var action_label: Label = %ActionLabel
@onready var normal_label: Label = %NormalLabel
@onready var cue_label: Label = %CueLabel
@onready var distance_label: Label = %DistanceLabel

# Stations
@onready var station_kitchen: Node3D = $Stations/KitchenStation
@onready var station_dining: Node3D = $Stations/DiningStation
@onready var station_bookshelf: Node3D = $Stations/BookshelfStation
@onready var station_pantry: Node3D = $Stations/PantryStation

func _ready() -> void:
	_setup_stations()
	_connect_familiar_signals()
	_connect_ui_signals()
	_update_ui_state()

func _setup_stations() -> void:
	if familiar:
		var stations: Array[Node3D] = [
			station_kitchen,
			station_dining,
			station_bookshelf,
			station_pantry
		]
		familiar.routine_stations = stations
		familiar.player_target = player_dummy

func _connect_familiar_signals() -> void:
	if not familiar:
		return
	familiar.behavior_stage_changed.connect(_on_behavior_stage_changed)
	familiar.action_changed.connect(_on_action_changed)
	familiar.acting_normal_changed.connect(_on_acting_normal_changed)
	familiar.trust_level_changed.connect(_on_trust_level_changed)
	familiar.cue_emitted.connect(_on_cue_emitted)
	familiar.greeting_emitted.connect(_on_greeting_emitted)

func _connect_ui_signals() -> void:
	if suspicion_slider:
		suspicion_slider.value_changed.connect(_on_suspicion_slider_changed)
	
	var btn_normal: Button = %BtnNormal
	var btn_doubtful: Button = %BtnDoubtful
	var btn_certain: Button = %BtnCertain
	var btn_near: Button = %BtnPlayerNear
	var btn_far: Button = %BtnPlayerFar
	var btn_next: Button = %BtnNextRoutine
	var btn_pause: Button = %BtnForcePause
	
	if btn_normal:
		btn_normal.pressed.connect(func(): _set_suspicion(10.0))
	if btn_doubtful:
		btn_doubtful.pressed.connect(func(): _set_suspicion(50.0))
	if btn_certain:
		btn_certain.pressed.connect(func(): _set_suspicion(85.0))
	if btn_near:
		btn_near.pressed.connect(_move_player_near)
	if btn_far:
		btn_far.pressed.connect(_move_player_far)
	if btn_next:
		btn_next.pressed.connect(func(): familiar.force_next_station())
	if btn_pause:
		btn_pause.pressed.connect(func(): familiar.force_pause())

func _process(_delta: float) -> void:
	_update_ui_state()

func _on_suspicion_slider_changed(value: float) -> void:
	if familiar:
		familiar.set_suspicion_level(value)
	_update_ui_state()

func _set_suspicion(value: float) -> void:
	if suspicion_slider:
		suspicion_slider.value = value
	if familiar:
		familiar.set_suspicion_level(value)
	_update_ui_state()

func _move_player_near() -> void:
	if player_dummy and familiar:
		# Place player 2 meters in front of familiar
		var f_pos: Vector3 = familiar.global_position
		player_dummy.global_position = f_pos + Vector3(0.0, 0.0, 2.0)

func _move_player_far() -> void:
	if player_dummy:
		player_dummy.global_position = Vector3(0.0, 0.0, 7.0)

func _update_ui_state() -> void:
	if not familiar:
		return
	
	var snapshot := familiar.get_observation_snapshot()
	
	if suspicion_val_label:
		suspicion_val_label.text = "%.0f%%" % snapshot["suspicion_level"]
	
	if stage_label:
		var stage_text: String = snapshot["stage_name"]
		stage_label.text = stage_text
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
	
	if distance_label and player_dummy and familiar:
		var dist: float = familiar.global_position.distance_to(player_dummy.global_position)
		distance_label.text = "%.2f m" % dist

func _on_behavior_stage_changed(_prev: int, new_stage: int) -> void:
	_update_ui_state()

func _on_action_changed(_prev: String, _new_action: String) -> void:
	_update_ui_state()

func _on_acting_normal_changed(_is_normal: bool) -> void:
	_update_ui_state()

func _on_trust_level_changed(_new_trust: float) -> void:
	_update_ui_state()

func _on_cue_emitted(cue_text: String) -> void:
	if cue_label:
		cue_label.text = '"%s"' % cue_text

func _on_greeting_emitted(msg: String) -> void:
	if cue_label:
		cue_label.text = 'Greeting: "%s"' % msg
