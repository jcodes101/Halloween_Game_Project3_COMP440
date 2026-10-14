# The Familiar — Familiar Behavior System Integration Guide

**Owner:** Megan (`Familiar_System` branch)  
**Target Project:** COMP 440 — *The Familiar* (Godot 4.7.2)  
**Scope:** `systems/familiar/` and `tests/familiar/`  

---

## Overview

The **Familiar Behavior System** governs the psychological horror illusion of the mother entity in the house:
- **Normal Stage:** Natural household routines (cooking, cleaning, reading, pantry), friendly greetings when approached, gentle idle breathing.
- **Doubtful Stage:** Glitched chore loops, sudden unnatural 3–5s pauses, subtle 14° head tilt, delayed head tracking, and intermittent micro-twitches.
- **Certain Stage:** Complete routine stoppage, relentless eye contact, and a recurring 9-step contortion sequence (neck twist, torso sideways bend, shoulder asymmetry, arm jerks, contorted freeze, slow recovery).
- **Monster Handoff:** Clean transition handing full bone and animation control over to K'von's Monster System during stalking, chases, jump scares, or captures.

The system is completely decoupled from visual meshes using visual adapters (`FamiliarVisualAdapter`), allowing seamless swapping between the low-poly test humanoid and K'von's 3D Mother character model without modifying any behavior logic.

---

## 1. Quick Start: Instantiating `Familiar.tscn`

`systems/familiar/Familiar.tscn` is a standalone `CharacterBody3D` ready to be dropped into any house scene.

### Scene Tree Structure
```
Familiar (CharacterBody3D, script: familiar_controller.gd)
├── CollisionShape3D (CapsuleShape3D, height: 1.75m, radius: 0.35m)
└── VisualAdapter (Node3D, script: placeholder_visual_adapter.gd or mother_visual_adapter.gd)
    └── [PlaceholderHumanoid OR MotherVisual.tscn]
```

### Instantiating via Godot Editor
1. In your level scene (`House.tscn`), click **Instantiate Child Scene** (`Ctrl + Shift + A`).
2. Select `res://systems/familiar/Familiar.tscn`.
3. In the Inspector:
   - Assign `Player Target` to the player node.
   - Assign `Routine Stations` with 3D marker nodes (e.g., Kitchen, Dining, Bookshelf, Pantry).

---

## 2. Swapping Visual Adapters (Placeholder vs. Actual Mother Model)

You can swap between the temporary placeholder model and K'von's actual 25-bone Mother character model without touching any behavior logic.

### To Use the Placeholder Humanoid (Default)
In `Familiar.tscn`:
- Visual child node has script `res://systems/familiar/placeholder_visual_adapter.gd`.
- Contains `PlaceholderHumanoid` instance (`res://systems/familiar/placeholder_humanoid.tscn`).

### To Use K'von's Actual 3D Mother Character
1. In `Familiar.tscn` (or in a variant such as `res://tests/familiar/familiar_mother_test_scene.tscn`):
2. Replace or change the script on the visual adapter child to:
   ```gdscript
   res://systems/familiar/mother_visual_adapter.gd
   ```
3. Set the exported property `mother_scene` to `res://assets/monster/MotherVisual.tscn`.
4. Ensure `visual_adapter` on `FamiliarController` points to this node.

`MotherVisualAdapter` automatically indexes all 25 bones of `Skeleton3D` (`neck_020`, `Head_021`, `RightArm_017`, `LeftArm_016`, `Spine_011`, etc.), aligns the asset orientation with Godot's `-Z` navigation, and applies smooth procedural bone transforms while preserving imported animations.

---

## 3. Michael's Interface (Observation & Suspicion System)

The Familiar Behavior System does **not** calculate suspicion; it receives suspicion from Michael's Observation System and updates its own trust level, behavior stages, and chore patterns.

### Public API Methods
```gdscript
# Method 1: Direct suspicion push (0.0 to 100.0)
familiar.receive_suspicion(suspicion_level: float)
# (set_suspicion_level() is also available as an alias)
familiar.set_suspicion_level(suspicion_level: float)

# Method 2: Comprehensive context intake
familiar.receive_observation(suspicion_level: float, { "player_node": player })
```

### Reading State
```gdscript
# Owned properties:
var stage: int = familiar.behavior_stage          # 0 = NORMAL, 1 = DOUBTFUL, 2 = CERTAIN
var action: String = familiar.current_action       # e.g., "cooking", "unnatural_pause", "contortion"
var normal: bool = familiar.is_acting_normal       # true in Normal, false in Doubtful/Certain
var trust: float = familiar.trust_level            # 100.0 (low suspicion) down to 0.0 (high suspicion)

# Complete state dictionary snapshot:
var snapshot: Dictionary = familiar.get_observation_snapshot()
# Returns:
# {
#   "behavior_stage": int,       # 0, 1, or 2
#   "stage_name": String,        # "Normal", "Doubtful", or "Certain"
#   "current_action": String,    # "idle", "cooking", "staring", "contortion", etc.
#   "is_acting_normal": bool,    # true/false
#   "trust_level": float,        # 0.0 - 100.0
#   "suspicion_level": float     # 0.0 - 100.0
# }
```

### Signals Emitted by FamiliarController
Connect to these signals to update UI, trigger sound stingers, or spawn observation clues:
```gdscript
familiar.behavior_stage_changed.connect(func(prev_stage: int, new_stage: int): ...)
familiar.action_changed.connect(func(prev_action: String, new_action: String): ...)
familiar.acting_normal_changed.connect(func(is_normal: bool): ...)
familiar.trust_level_changed.connect(func(new_trust: float): ...)
familiar.greeting_emitted.connect(func(dialogue_line: String): ...)
familiar.cue_emitted.connect(func(unsettling_cue: String): ...)
familiar.routine_station_changed.connect(func(station_name: String): ...)
```

### Michael's Integration Example
```gdscript
# observation_manager.gd
extends Node

@export var familiar: FamiliarController
var player_suspicion: float = 0.0

func _on_clue_discovered(clue_suspicion_value: float) -> void:
    player_suspicion = clampf(player_suspicion + clue_suspicion_value, 0.0, 100.0)
    
    # Notify Familiar Behavior System:
    if familiar:
        familiar.receive_suspicion(player_suspicion)

func check_familiar_behavior() -> void:
    if not familiar:
        return
    
    # Check if the player catches the familiar acting abnormally
    if not familiar.is_acting_normal:
        print("Clue Opportunity: Familiar is exhibiting unnatural behavior: ", familiar.current_action)
```

---

## 4. Jadin's Interface (Environment, House & Player)

The Familiar navigates the house environment, interacts with player proximity, and uses physics collision.

### Supplying the Player Reference
```gdscript
# Method A: Via dedicated helper
familiar.set_player(first_person_player_node)

# Method B: Direct property assignment
familiar.player_target = first_person_player_node
```

### Setting Up Routine Stations
Routine stations can be simple `Node3D` or `Marker3D` nodes placed around the house (e.g. at the kitchen counter, dining table, bookshelf, and pantry).

```gdscript
# Method A: Via script
familiar.set_routine_stations([
    $House/KitchenCounter,
    $House/DiningTable,
    $House/LivingRoomBookshelf,
    $House/PantryStorage
])

# Method B: Via Godot Inspector
# Simply add elements to the exported `routine_stations` array on FamiliarController.
```
*Note: If no stations are assigned, default fallback positions in the room will be used.*

### Collision Layers and Masks
`FamiliarController` is configured for physics collision standards:
- **`collision_layer` = 4** (`Familiar` layer)
- **`collision_mask` = 3** (Layer 1 = World/Floor, Layer 2 = Player)

Player settings in your game should have:
- **`collision_layer` = 2** (`Player` layer)
- **`collision_mask` = 5** (Layer 1 = World/Floor [1] + Layer 3/4 = Familiar/Monster [4])

This ensures the player cannot clip or walk through the mother character when approaching her.

### Jadin's Integration Example
```gdscript
# house_level.gd
extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var familiar: FamiliarController = $Familiar

func _ready() -> void:
    if familiar and player:
        # 1. Connect player reference for proximity greetings & gaze tracking
        familiar.set_player(player)
        
        # 2. Provide routine waypoints in the house
        familiar.set_routine_stations([
            $Stations/KitchenStove,
            $Stations/DiningTable,
            $Stations/StudyDesk,
            $Stations/BasementDoor
        ])
```

---

## 5. K'von's Interface (Monster System Handoff)

When suspicion reaches critical levels, when lights go out, or when a chase/stalk sequence begins, K'von's Monster System takes full control of the character.

### Handoff API
```gdscript
# To start stalk / chase / jump scare / capture:
familiar.hand_off_to_monster()

# To return control back to Familiar routines (e.g. after player hides or monster resets):
familiar.reclaim_from_monster()

# Check current control owner:
var is_active_monster: bool = familiar.is_monster_controlled
```

### What Happens During Handoff (`hand_off_to_monster()`)
1. **Bone Overrides Cleared:** All procedural skeletal bone rotations (`neck_020`, `Head_021`, `Spine_011`, arms) are immediately reset to rest poses.
2. **Animation Cleaned:** Familiar routine animations (`walking_man`) are stopped.
3. **Motion Halted:** Familiar velocity is zeroed.
4. **Behavior Loop Suspended:** `FamiliarController` early-returns in `_physics_process()`, allowing K'von's chase AI and Monster AnimationPlayers to drive root motion and animations without fighting the Familiar system.

### What Happens During Reclaim (`reclaim_from_monster()`)
1. Familiar re-evaluates current suspicion and behavior stage.
2. Restores appropriate routine or staring state.
3. Re-engages procedural head tracking and posture blending smoothly.

### Signals
```gdscript
familiar.monster_handoff_started.connect(func(): ...)
familiar.monster_handoff_ended.connect(func(): ...)
```

### K'von's Integration Example
```gdscript
# monster_ai_controller.gd
extends Node3D

@export var familiar_controller: FamiliarController
@export var monster_animator: AnimationPlayer

func start_chase_sequence() -> void:
    # 1. Take control from Familiar
    if familiar_controller:
        familiar_controller.hand_off_to_monster()
    
    # 2. Play monster sprint/scare animations cleanly
    if monster_animator:
        monster_animator.play("monster_sprint")

func end_chase_and_resume_familiar() -> void:
    # 1. Return control to Familiar System
    if familiar_controller:
        familiar_controller.reclaim_from_monster()
```

---

## 6. Production Guidelines (HUD & Debug Separation)

- **Test Scenes vs Production:**  
  The sliders, debug buttons, and diagnostic labels in `tests/familiar/familiar_test_scene.tscn` and `tests/familiar/familiar_mother_test_scene.tscn` belong **only** to the test scenes in `tests/familiar/`.
- **In the Real Game:**  
  Simply instantiate `systems/familiar/Familiar.tscn`. It has **no UI, no canvas layers, and no debug overlays**. It runs silently, controlled entirely by code via `receive_suspicion()` and `set_player()`.

---

## 7. Automated Test Suite

A standalone test suite is provided to verify system integrity at any time without running the full game:

```powershell
godot --headless -s tests/familiar/verify_familiar.gd
```
- Tests all 3 behavior stages and suspicion threshold math.
- Tests state ownership defaults and getter/setter methods.
- Tests signal emissions.
- Tests decoupling and both visual adapters.
- Tests Skeleton3D 25-bone discovery and pose caching.
- Tests monster handoff and reclaim logic.
- Tests test scene instantiations and first-person player collision layers.
