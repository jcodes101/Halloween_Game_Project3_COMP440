class_name MonsterTuning
extends Resource
## Approved prototype settings. Tune here without changing other systems.
@export var stalk_threshold := 30.0
@export var pursue_threshold := 70.0
@export var stalk_speed := 2.0
@export var chase_speed := 4.3
@export var stalk_distance := 4.0
@export var capture_distance := 0.9
@export var hidden_still_seconds := 3.0
@export var reveal_pause_seconds := 1.0
@export var sight_range := 14.0
@export_range(10, 180) var sight_angle_degrees := 140.0
@export var search_radius := 3.0
@export var arrival_distance := 0.45

