# Familiar Behavior System

Owned by **Familiar_System** for COMP 440 (*The Familiar*).

## Ownership Boundaries

This system owns:
- `trust_level: float` (0.0 to 100.0)
- `behavior_stage: int` (`NORMAL = 0`, `DOUBTFUL = 1`, `CERTAIN = 2`)
- `current_action: String`
- `is_acting_normal: bool`

It does **not** implement:
- Michael's suspicion calculation or clue inspection logic.
- K'von's pursuit/hunting AI or physical capture loop.
- 3D character mesh authoring (the mother character model is owned by our art teammate).

## Three Behavior Stages

1. **Normal (`NORMAL = 0`)**:
   - `is_acting_normal = true`, `trust_level` high (65.0 - 100.0).
   - Household Routines: Cycles naturally between household stations (Kitchen, Dining Room, Bookshelf, Pantry) performing chores (`cooking`, `cleaning`, `reading`, `checking_pantry`).
   - Player Greeting: When the player approaches within greeting proximity (`<= 4.0m`), she pauses her chore, faces the player warmly, and delivers motherly greetings ("Hello dear, dinner will be ready in a little while.", etc.) before resuming her task.
   - Posture & Aesthetics: Warm, gentle breathing bob, relaxed arm posture, dark eyes.

2. **Doubtful (`DOUBTFUL = 1`)**:
   - `is_acting_normal = false`, `trust_level` moderate (25.0 - 65.0). Triggered when suspicion reaches `>= 35.0`.
   - Action Glitches: Chore repetition becomes mechanical and erratic (`repeating_chore`), obsessively wiping or stirring.
   - Unnatural Pauses: Enters sudden mid-motion freezes (`unnatural_pause`), remaining completely motionless for 3–5 seconds.
   - Creeping Player Turn: While paused or near the player, slowly rotates toward the player (`slow_turn`) at a delayed creeping turn speed (`0.8 rad/s`).
   - Posture & Aesthetics: Asymmetrical stance, slight neck tilt, desaturated colors, occasional jerky micro-twitches.

3. **Certain (`CERTAIN = 2`)**:
   - `is_acting_normal = false`, `trust_level` low (0.0 - 25.0). Triggered when suspicion reaches `>= 75.0`.
   - Routine Stoppage: Household chores and navigation are terminated.
   - Relentless Stare: Constantly locks gaze onto the player (`staring`), rotating directly to follow the player's every step.
   - Disturbing Behavior: Rigid upright posture, uncanny glaring eyes, disturbing dialogue cues ("You know, don't you.", "Why are you looking at Mother like that?").

## Architecture & Visual Decoupling

The Familiar Behavior System strictly separates logic from 3D visual assets:

```
┌──────────────────────────────────────────────┐
│             FamiliarController               │
│   (State, Stages, Routines, Suspicion API)   │
└──────────────────────┬───────────────────────┘
                       │ Calls abstract API
                       ▼
┌──────────────────────────────────────────────┐
│           FamiliarVisualAdapter              │
│ (apply_stage, play_action, look_toward, etc.)│
└──────────────┬───────────────────────────────┘
               │
       ┌───────┴────────────────────────┐
       ▼                                ▼
┌───────────────────────────┐ ┌──────────────────────────┐
│ PlaceholderVisualAdapter  │ │   MotherVisualAdapter    │
│  (Wraps procedural low-   │ │ (Wraps teammate's model  │
│   poly humanoid model)    │ │  when preview is ready)  │
└───────────────────────────┘ └──────────────────────────┘
```

- **No Hardcoded Mesh Paths**: `FamiliarController` holds an exported reference to `FamiliarVisualAdapter`.
- **Placeholder Humanoid**: Built with standard Godot 3D primitive nodes (`BoxMesh`, `CapsuleMesh`) with distinct head, eyes, and limbs, providing immediate visual feedback for all three stages and actions.
- **Teammate Integration**: When our teammate finishes fixing the mother model preview in `assets/monster/MotherVisual.tscn`, swapping to it is as simple as switching the visual adapter node to `MotherVisualAdapter`. Zero behavior code needs to change.

## Public Interface for Michael's Observation System

### Writing to Familiar
```gdscript
# Updates suspicion level (0.0 - 100.0) and recalculates trust and stage
familiar_controller.set_suspicion_level(suspicion_val)

# Optional context-based intake
familiar_controller.receive_observation(suspicion_val, {"player_node": player})
```

### Reading from Familiar
```gdscript
var current_action: String = familiar_controller.get_current_action()
var behavior_stage: int = familiar_controller.get_behavior_stage()
var is_normal: bool = familiar_controller.get_is_acting_normal()
var trust_val: float = familiar_controller.get_trust_level()

# Or get a complete snapshot dictionary:
var snapshot: Dictionary = familiar_controller.get_observation_snapshot()
# Returns: {
#   "behavior_stage": int,
#   "stage_name": String,
#   "current_action": String,
#   "is_acting_normal": bool,
#   "trust_level": float,
#   "suspicion_level": float
# }
```

### Signals
Other systems can connect to:
- `signal behavior_stage_changed(previous_stage: int, new_stage: int)`
- `signal action_changed(previous_action: String, new_action: String)`
- `signal acting_normal_changed(is_acting_normal: bool)`
- `signal trust_level_changed(new_trust: float)`
- `signal greeting_emitted(message: String)`
- `signal cue_emitted(cue_text: String)`
- `signal routine_station_changed(station_name: String)`
