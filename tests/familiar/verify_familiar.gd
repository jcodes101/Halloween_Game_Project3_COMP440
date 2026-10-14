extends SceneTree

const FamiliarConstants = preload("res://systems/familiar/familiar_constants.gd")
const FamiliarController = preload("res://systems/familiar/familiar_controller.gd")
const FamiliarVisualAdapter = preload("res://systems/familiar/familiar_visual_adapter.gd")
const MotherVisualAdapter = preload("res://systems/familiar/mother_visual_adapter.gd")
## Automated test suite for Familiar Behavior System.
## Run with: godot --headless -s tests/familiar/verify_familiar.gd

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("\n=======================================================")
	print(" RUNNING FAMILIAR BEHAVIOR SYSTEM VERIFICATION SUITE")
	print("=======================================================\n")
	
	run_tests()
	
	print("\n-------------------------------------------------------")
	print("TEST RESULTS: %d Passed, %d Failed, %d Total" % [passed_tests, failed_tests, total_tests])
	print("=======================================================\n")
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: Expected %s but got %s" % [test_name, str(expected), str(actual)])

func assert_approx(actual: float, expected: float, test_name: String) -> void:
	total_tests += 1
	if is_equal_approx(actual, expected):
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: Expected ~%f but got %f" % [test_name, expected, actual])

func run_tests() -> void:
	test_state_ownership_and_defaults()
	test_observation_system_api()
	test_stage_transitions()
	test_signals_emitted()
	test_visual_adapter_decoupling()
	test_stage_1_normal_routines_and_greeting()
	test_stage_2_doubtful_behaviors()
	test_stage_3_certain_behaviors()
	test_instantiate_test_scene()
	test_mother_skeletal_adapter()
	test_monster_handoff_mechanism()
	test_instantiate_mother_test_scene()

func test_state_ownership_and_defaults() -> void:
	print("--- Test Suite: State Ownership and Defaults ---")
	var controller := FamiliarController.new()
	
	assert_approx(controller.trust_level, 100.0, "Familiar owns trust_level and defaults to 100.0")
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.NORMAL, "Familiar owns behavior_stage and defaults to NORMAL")
	assert_eq(controller.current_action, FamiliarConstants.ACTION_IDLE, "Familiar owns current_action and defaults to idle")
	assert_true(controller.is_acting_normal, "Familiar owns is_acting_normal and defaults to true")
	
	controller.free()

func test_observation_system_api() -> void:
	print("\n--- Test Suite: Observation System Interface ---")
	var controller := FamiliarController.new()
	
	controller.set_suspicion_level(20.0)
	assert_approx(controller.get_trust_level(), 80.0, "trust_level correctly scales inversely with suspicion")
	assert_eq(controller.get_behavior_stage(), FamiliarConstants.BehaviorStage.NORMAL, "get_behavior_stage returns NORMAL at low suspicion")
	assert_true(controller.get_is_acting_normal(), "get_is_acting_normal returns true at low suspicion")
	
	var snapshot := controller.get_observation_snapshot()
	assert_eq(snapshot["behavior_stage"], FamiliarConstants.BehaviorStage.NORMAL, "Snapshot contains correct behavior_stage")
	assert_approx(snapshot["trust_level"], 80.0, "Snapshot contains correct trust_level")
	assert_approx(snapshot["suspicion_level"], 20.0, "Snapshot contains correct suspicion_level")
	assert_true(snapshot["is_acting_normal"], "Snapshot contains correct is_acting_normal")
	
	# Test receive_suspicion alias
	controller.receive_suspicion(60.0)
	assert_approx(controller.get_trust_level(), 40.0, "receive_suspicion updates trust_level")
	assert_eq(controller.get_behavior_stage(), FamiliarConstants.BehaviorStage.DOUBTFUL, "receive_suspicion updates stage to DOUBTFUL")
	
	# Test set_player and set_routine_stations
	var test_dummy := Node3D.new()
	controller.set_player(test_dummy)
	assert_eq(controller.player_target, test_dummy, "set_player correctly assigns player_target")
	
	var station_dummy := Node3D.new()
	controller.set_routine_stations([station_dummy])
	assert_eq(controller.routine_stations.size(), 1, "set_routine_stations populates routine_stations")
	assert_eq(controller.routine_stations[0], station_dummy, "set_routine_stations retains station reference")
	
	test_dummy.free()
	station_dummy.free()
	controller.free()


func test_stage_transitions() -> void:
	print("\n--- Test Suite: Stage Transitions via Suspicion Thresholds ---")
	var controller := FamiliarController.new()
	
	# Normal stage (< 35 suspicion)
	controller.set_suspicion_level(15.0)
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.NORMAL, "Suspicion 15.0 -> Stage NORMAL")
	assert_true(controller.is_acting_normal, "Normal stage has is_acting_normal = true")
	
	# Doubtful stage (>= 35 and < 75)
	controller.set_suspicion_level(45.0)
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.DOUBTFUL, "Suspicion 45.0 -> Stage DOUBTFUL")
	assert_true(not controller.is_acting_normal, "Doubtful stage has is_acting_normal = false")
	
	# Certain stage (>= 75)
	controller.set_suspicion_level(85.0)
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.CERTAIN, "Suspicion 85.0 -> Stage CERTAIN")
	assert_true(not controller.is_acting_normal, "Certain stage has is_acting_normal = false")
	
	# Lower suspicion back down
	controller.set_suspicion_level(10.0)
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.NORMAL, "Suspicion lowered to 10.0 -> Stage NORMAL")
	assert_true(controller.is_acting_normal, "Recovered stage has is_acting_normal = true")
	
	controller.free()

func test_signals_emitted() -> void:
	print("\n--- Test Suite: Signals for External Systems ---")
	var controller := FamiliarController.new()
	
	var data := {
		"stage_changed": false,
		"prev_stage": -1,
		"new_stage": -1,
		"trust_changed": false,
		"trust": -1.0,
		"normal_changed": false
	}
	controller.behavior_stage_changed.connect(func(prev: int, current: int):
		data["stage_changed"] = true
		data["prev_stage"] = prev
		data["new_stage"] = current
	)
	
	controller.trust_level_changed.connect(func(new_trust: float):
		data["trust_changed"] = true
		data["trust"] = new_trust
	)
	
	controller.acting_normal_changed.connect(func(_val: bool):
		data["normal_changed"] = true
	)
	
	controller.set_suspicion_level(50.0)
	assert_true(data["stage_changed"], "behavior_stage_changed signal fired")
	assert_eq(data["prev_stage"], FamiliarConstants.BehaviorStage.NORMAL, "Previous stage was NORMAL")
	assert_eq(data["new_stage"], FamiliarConstants.BehaviorStage.DOUBTFUL, "New stage is DOUBTFUL")
	assert_true(data["trust_changed"], "trust_level_changed signal fired")
	assert_approx(data["trust"], 50.0, "New trust value delivered via signal")
	assert_true(data["normal_changed"], "acting_normal_changed signal fired")
	
	controller.free()

func test_visual_adapter_decoupling() -> void:
	print("\n--- Test Suite: Visual Adapter Decoupling ---")
	var controller := FamiliarController.new()
	
	# Create a mock visual adapter implementing FamiliarVisualAdapter
	var adapter := FamiliarVisualAdapter.new()
	controller.visual_adapter = adapter
	
	# Verify controller drives visual adapter methods without hardcoding paths
	controller.set_suspicion_level(80.0)
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.CERTAIN, "Controller successfully configured with visual adapter")
	
	adapter.free()
	controller.free()

func test_stage_1_normal_routines_and_greeting() -> void:
	print("\n--- Test Suite: Stage 1 (Normal) Routines and Greeting ---")
	var controller := FamiliarController.new()
	var player := Node3D.new()
	player.position = Vector3(0, 0, 2) # Within 4.0m greeting distance
	controller.player_target = player
	
	var greeting_data := {"fired": false}
	controller.greeting_emitted.connect(func(_msg: String):
		greeting_data["fired"] = true
	)
	
	# Run normal physics step to trigger greeting
	controller._physics_process(0.016)
	assert_true(greeting_data["fired"], "Familiar greets player when nearby in Normal stage")
	assert_eq(controller.current_action, FamiliarConstants.ACTION_GREET, "Current action transitions to GREET")
	assert_true(controller.is_acting_normal, "Greeting is recognized as normal behavior")
	
	player.free()
	controller.free()

func test_stage_2_doubtful_behaviors() -> void:
	print("\n--- Test Suite: Stage 2 (Doubtful) Behaviors ---")
	var controller := FamiliarController.new()
	controller.set_suspicion_level(50.0)
	
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.DOUBTFUL, "In Doubtful stage")
	assert_true(not controller.is_acting_normal, "is_acting_normal is false in Doubtful stage")
	
	# Simulate physics process in Doubtful stage
	controller._physics_process(0.016)
	assert_true(
		controller.current_action == FamiliarConstants.ACTION_REPEATING_CHORE or
		controller.current_action == FamiliarConstants.ACTION_UNNATURAL_PAUSE or
		controller.current_action == FamiliarConstants.ACTION_SLOW_TURN,
		"Doubtful stage engages flawed chore repetition, unnatural pause, or slow turn"
	)
	
	# Force unnatural pause
	controller.force_pause()
	assert_eq(controller.current_action, FamiliarConstants.ACTION_UNNATURAL_PAUSE, "Can enter unnatural pause")
	
	controller.free()

func test_stage_3_certain_behaviors() -> void:
	print("\n--- Test Suite: Stage 3 (Certain) Behaviors ---")
	var controller := FamiliarController.new()
	var player := Node3D.new()
	player.position = Vector3(5, 0, 5)
	controller.player_target = player
	
	controller.set_suspicion_level(90.0)
	assert_eq(controller.behavior_stage, FamiliarConstants.BehaviorStage.CERTAIN, "In Certain stage")
	assert_true(not controller.is_acting_normal, "is_acting_normal is false in Certain stage")
	
	controller._physics_process(0.016)
	assert_eq(controller.current_action, FamiliarConstants.ACTION_STARING, "Certain stage halts routines and enters staring action")
	assert_approx(controller.velocity.length(), 0.0, "Certain stage halts movement velocity")
	
	player.free()
	controller.free()

func test_instantiate_test_scene() -> void:
	print("\n--- Test Suite: Instantiate Test Scene ---")
	var scene_res := load("res://tests/familiar/familiar_test_scene.tscn") as PackedScene
	assert_true(scene_res != null, "familiar_test_scene.tscn loaded successfully")
	
	var scene_instance := scene_res.instantiate() as Node3D
	assert_true(scene_instance != null, "familiar_test_scene.tscn instantiated without errors")
	
	var familiar_node := scene_instance.get_node_or_null("Familiar") as FamiliarController
	assert_true(familiar_node != null, "Test scene contains Familiar instance")
	
	scene_instance.free()

func test_mother_skeletal_adapter() -> void:
	print("\n--- Test Suite: Mother Visual Adapter & Skeleton3D ---")
	var adapter := MotherVisualAdapter.new()
	root.add_child(adapter)
	adapter.notification(Node.NOTIFICATION_READY)
	adapter._process(0.016)
	
	assert_true(adapter.skeleton != null, "MotherVisualAdapter discovers Skeleton3D")
	if adapter.skeleton:
		assert_eq(adapter.skeleton.get_bone_count(), 25, "Mother skeleton has 25 bones")
		assert_true(adapter.bone_indices["neck"] >= 0, "neck_020 bone indexed")
		assert_true(adapter.bone_indices["head"] >= 0, "Head_021 bone indexed")
		assert_true(adapter.bone_indices["arm_r"] >= 0, "RightArm_017 bone indexed")
		assert_true(adapter.bone_indices["spine_upper"] >= 0, "Spine_011 bone indexed")
		
		# Test stage application
		adapter.apply_stage(FamiliarConstants.BehaviorStage.DOUBTFUL)
		assert_eq(adapter.current_stage, FamiliarConstants.BehaviorStage.DOUBTFUL, "Adapter stage set to DOUBTFUL")
		adapter._process(0.016)
		
		# Test action posing
		adapter.play_action(FamiliarConstants.ACTION_GREET)
		assert_eq(adapter.current_action, FamiliarConstants.ACTION_GREET, "Adapter action set to GREET")
		adapter._process(0.016)
		
		# Test cache restoration
		adapter.reset_all_bone_overrides()
		var neck_idx: int = adapter.bone_indices["neck"]
		var restored_neck: Quaternion = adapter.skeleton.get_bone_pose_rotation(neck_idx)
		var cached_neck: Quaternion = adapter.base_bone_poses[neck_idx]
		assert_true(restored_neck.is_equal_approx(cached_neck), "Restored neck matches cached base pose")
	
	adapter.free()

func test_monster_handoff_mechanism() -> void:
	print("\n--- Test Suite: Monster System Handoff ---")
	var controller := FamiliarController.new()
	var adapter := MotherVisualAdapter.new()
	controller.add_child(adapter)
	controller.visual_adapter = adapter
	root.add_child(controller)
	controller.notification(Node.NOTIFICATION_READY)
	
	var data := {"started": false, "ended": false}
	controller.monster_handoff_started.connect(func(): data["started"] = true)
	controller.monster_handoff_ended.connect(func(): data["ended"] = true)
	
	# Trigger handoff
	controller.hand_off_to_monster()
	assert_true(controller.is_monster_controlled, "Controller marks is_monster_controlled = true")
	assert_true(adapter.is_monster_controlled, "Adapter marks is_monster_controlled = true")
	assert_true(data["started"], "monster_handoff_started signal emitted")
	
	# Verify physics process early returns when monster controlled
	controller.velocity = Vector3(5, 0, 0)
	controller._physics_process(0.016)
	assert_approx(controller.velocity.length(), 5.0, "Familiar routine paused during monster control")
	
	# Reclaim control
	controller.reclaim_from_monster()
	assert_true(not controller.is_monster_controlled, "Controller restores is_monster_controlled = false")
	assert_true(not adapter.is_monster_controlled, "Adapter restores is_monster_controlled = false")
	assert_true(data["ended"], "monster_handoff_ended signal emitted")
	
	controller.free()

func test_instantiate_mother_test_scene() -> void:
	print("\n--- Test Suite: Instantiate Mother Test Scene & First-Person POV ---")
	assert_eq(FamiliarConstants.CertainPhase.EYE_CONTACT, 0, "CertainPhase EYE_CONTACT enum value")
	assert_eq(FamiliarConstants.CertainPhase.NECK_TWIST, 1, "CertainPhase NECK_TWIST enum value")
	assert_eq(FamiliarConstants.CertainPhase.TORSO_BEND, 2, "CertainPhase TORSO_BEND enum value")
	assert_eq(FamiliarConstants.CertainPhase.SHOULDER_ASYMMETRY, 3, "CertainPhase SHOULDER_ASYMMETRY enum value")
	assert_eq(FamiliarConstants.CertainPhase.ARMS_JERK, 4, "CertainPhase ARMS_JERK enum value")
	assert_eq(FamiliarConstants.CertainPhase.CONTORTED_FREEZE, 5, "CertainPhase CONTORTED_FREEZE enum value")
	assert_eq(FamiliarConstants.CertainPhase.SLOW_RECOVERY, 6, "CertainPhase SLOW_RECOVERY enum value")
	
	var fp_player_script := load("res://tests/familiar/test_first_person_player.gd")
	assert_true(fp_player_script != null, "test_first_person_player.gd script loaded successfully")

	var scene_res := load("res://tests/familiar/familiar_mother_test_scene.tscn") as PackedScene
	assert_true(scene_res != null, "familiar_mother_test_scene.tscn loaded successfully")
	
	var scene_instance := scene_res.instantiate() as Node3D
	assert_true(scene_instance != null, "familiar_mother_test_scene.tscn instantiated without errors")
	
	var familiar_node := scene_instance.get_node_or_null("Familiar") as FamiliarController
	assert_true(familiar_node != null, "Mother test scene contains Familiar controller")
	assert_eq(familiar_node.collision_layer, 4, "Familiar controller is on collision layer 4")
	
	var adapter_node := scene_instance.get_node_or_null("Familiar/MotherVisualAdapter") as MotherVisualAdapter
	assert_true(adapter_node != null, "Mother test scene contains MotherVisualAdapter")
	
	var player_node := scene_instance.get_node_or_null("TestPlayer") as CharacterBody3D
	assert_true(player_node != null, "Mother test scene contains TestPlayer")
	assert_eq(player_node.collision_layer, 2, "TestPlayer is on collision layer 2")
	assert_eq(player_node.collision_mask, 5, "TestPlayer collides with Floor (1) and Familiar (4)")
	
	var fp_cam := player_node.get_node_or_null("FirstPersonCamera") as Camera3D
	assert_true(fp_cam != null, "TestPlayer has FirstPersonCamera node")
	
	var overhead_cam := scene_instance.get_node_or_null("OverheadCamera3D") as Camera3D
	assert_true(overhead_cam != null, "Scene contains OverheadCamera3D")
	
	scene_instance.free()


