class_name MonsterTuning
extends Resource
## Approved prototype settings. Tune here without changing other systems.
@export var stalk_threshold := 30.0
@export var pursue_threshold := 70.0
@export var stalk_speed := 2.0
@export var chase_speed := 4.3
@export_range(2.0, 24.0, 0.5) var acceleration := 12.0
@export_range(2.0, 30.0, 0.5) var deceleration := 16.0
@export_range(0.1, 1.0, 0.05) var path_refresh_seconds := 0.25
@export var stalk_distance := 4.0
@export var capture_distance := 0.9
@export var hidden_still_seconds := 3.0
@export var reveal_pause_seconds := 1.0
@export var sight_range := 14.0
@export_range(10, 180) var sight_angle_degrees := 140.0
## Close visual contacts are confirmed quickly; distant sightings need a short, steady view.
@export_range(0.05, 0.5, 0.05) var close_sight_confirm_seconds := 0.15
@export_range(0.1, 1.5, 0.05) var distant_sight_confirm_seconds := 0.45
@export_range(2.0, 10.0, 0.5) var close_sight_pursuit_distance := 5.5
@export_range(0.1, 1.0, 0.05) var reachability_refresh_seconds := 0.3
@export var search_radius := 3.0
@export var arrival_distance := 0.45
@export_range(4.0, 24.0, 0.5) var hearing_distance := 13.0
@export_range(0.5, 5.0, 0.1) var sound_falloff_per_meter := 2.2
@export_range(1.5, 8.0, 0.1) var qte_window_seconds := 5.0
@export_range(0.5, 5.0, 0.1) var qte_stun_seconds := 1.1
@export_range(0.5, 6.0, 0.1) var qte_recoil_speed := 2.2
@export_range(1.0, 10.0, 0.1) var qte_success_cooldown := 5.5
@export_range(3.0, 14.0, 0.5) var qte_retreat_distance := 8.0
@export_range(2.0, 8.0, 0.1) var qte_retreat_speed := 5.5
@export_range(0.5, 5.0, 0.1) var qte_retreat_seconds := 2.5
@export_range(0.5, 4.0, 0.1) var qte_recovery_seconds := 1.5
@export_range(0.2, 2.0, 0.05) var qte_visual_reaction_seconds := 1.05
@export_range(1.0, 24.0, 0.5) var qte_visual_recoil_meters := 0.18
@export_range(2.0, 28.0, 0.5) var qte_visual_tilt_degrees := 12.0
@export_range(1, 6, 1) var qte_sequence_length := 3
@export var qte_key_pool: Array[int] = [KEY_Q, KEY_E, KEY_R, KEY_F]
## Zero uses a randomized seed. A non-zero value is useful for repeatable tests.
@export var qte_random_seed := 0
@export_range(0.2, 3.0, 0.1) var search_pause_seconds := 0.9
## Zero uses a randomized search-route order; set a non-zero value to reproduce it.
@export var search_random_seed := 0

## Acoustic loss in alert points per intersected solid collider (up to three).
@export var wall_sound_loss := 18.0
@export var closed_door_sound_loss := 10.0
@export var room_search_radius := 7.0
@export var search_point_timeout := 10.0
