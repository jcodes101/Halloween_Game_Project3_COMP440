# Combined game scene

`game/main.tscn` is the project's F5 scene. `main_game.gd` wires the existing
Escape/Environment, Familiar, Monster, player and approved sound systems together.
The active environment is now the furnished multi-floor house; see
`game/house/README.md` for its crowbar, bedroom key, attic ladder and landing route.
The implementation is published on `main`, with its integration checkpoint also
retained on `game-integration`.

## What is connected

- House items, locks, crowbar/hatch progression, window jump and landing remain
  Environment-owned. The old compact key/basement exit is retained only as a test fixture.
- Familiar routines and greetings use the existing FamiliarController from
  `origin/Familiar_System` commit ca70b8d.
- One physical mother body and one visible rig are shared. Routine scheduling
  calls the body's navigation; threat behavior takes over that same body without
  relocating it. Familiar's skeletal adapter binds to the existing visual.
- Monster uses physical visibility and navigation for stalking, pursuit, search,
  concealment, interception and capture.
- The closed basement has a physical side passage. Environment defers opening
  until arrival; a shadow/caption warns the player. A navigation link enables
  the opened doorway. No interception teleport is used.
- The house owns key, door, hide and terminal states. Monster emits requests,
  the house applies changes, and the scene adapter reads snapshots.
- Actual camera height is used for sight. The raised mattress blocks sight and
  leaves the authored crawl route clear. The monster consumes raw motionlessness
  so its three-second timer is not added to Environment's three-second indicator.
- Footsteps are spatial; successful key pickup, opening and locked attempts
  trigger approved clips. Capture plays the one-second approved sting.
- Scene reload restarts all systems and audio together.

## Temporary Observation boundary

Both remote Familiar_System and Suspicion-System pointed to ca70b8d during
integration; neither supplied a distinct Observation implementation. The user
approved temporary 1/2/3 inputs (0/50/100). `test_observation.gd` owns only these
simulated values and publishes them to Familiar and Monster. It does not award
clues automatically or implement a replacement inventory/inspection system.
Replace this input adapter with the team's Observation publisher when available.
There is no new autoload.

Existing threshold settings remain system-specific: Familiar changes at 35/75;
Monster's approved test thresholds are 30/70. Test presets cross both boundaries.
The lower player camera preference is retained. The house's existing movement
speeds and hiding transitions are retained rather than replacing its controller.

## Verification

Run Godot with `--path . game/main.tscn -- --verify-house` to exercise the active house scene;
use `--path . tests/integration/legacy_main.tscn -- --verify-game` for the earlier compact fixture;
add `--headless` for physics checks without rendering. The suite checks movement,
one shared rig, routine/threat handoffs, locked feedback, key pickup, continuous
interception, door gating, reveal timing, hiding, three-second loss and movement
interruption, actual Environment escape, capture/sting, and full scene restarts.
Tests use actor-position fixtures to isolate situations; they are not a claim of
a human completing a continuous playthrough. Rendered checks save
`design/monster_behavior/combined_game.png`.

The old compact blockout remains as a regression fixture at
`tests/integration/legacy_main.tscn`. The house now supplies the two main floors,
basement, attic escape and evening exterior. The separate clue system remains absent.
Web exports in `docs/` are existing snapshots and have not been rebuilt here.
