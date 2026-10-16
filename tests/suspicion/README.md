# Phase 3A isolated suspicion lab

Open `tests/suspicion/suspicion_test.tscn` and run that scene (F6). Its independent
button interface displays evidence stage, clue count, temporary alertness,
inventory, and the selected story. No main-game integration is installed.

- **Collect** adds an inventory entry without evidence.
- **Inspect / reread** displays the catalog story and confirms its canonical clue.
- **Interact** uses the existing `PlayerInteractionComponent` to collect and inspect.
- The first distinct clue reaches DOUBTFUL; the third reaches CERTAIN.
- Repeated inspections and duplicate physical instances never add another clue.
- Detection buttons call the existing `test_observation.gd` interface. Alertness
  changes never change evidence, and evidence never changes alertness.
- Reset evidence/inventory preserves detection alertness; reset lab also clears
  the lab-owned detection source. Reset makes the same objects collectible again.

All four variants under `scripts/observation/scenes/` inherit the same simple
physical card scene. Their `Interaction.item_id` selects the existing catalog
definition; story text is not duplicated in scenes. Bind each Interaction node
using `ObservationCoordinator.bind_item()` before enabling gameplay interactions.
The coordinator can also be instantiated via `observation_system.tscn`.

## Adapter contract

`ObservationAdapter.suspicion_level`, `temporary_alertness`, `suspicion_changed`,
and `set_test_suspicion()` belong only to the temporary detection channel, matching
the existing observation interface. `bind_alertness_source(source)` mirrors an
existing provider's signal and snapshots its initial value without writing to it.
Unbinding preserves the last mirrored alertness. Finite values clamp to 0–100.

`evidence_stage`, `evidence_score`, and `evidence_changed(stage, score, clues)`
belong only to permanent session evidence. Scores map UNAWARE/DOUBTFUL/CERTAIN to
0/50/100 for future familiar integration. Stage transitions and clue discovery can
both emit evidence snapshots; consumers should treat them as state updates.

`reset_session()` clears manager, inventory and lab story through `session_reset`.
It explicitly refreshes the evidence snapshot even for an already-empty session.
`reset_session(true)` also clears the adapter's local alertness; it never writes to
an external detection source. Callers own resetting external detection mechanics.
Use the coordinator reset API for a complete session reset. There is no save/load.

The lab positions objects six units apart and moves a synthetic interaction
origin to the chosen object. It exercises the existing proximity dispatcher;
aiming, walls, movement, main-game input arbitration, doors and escape integration
are outside Phase 3A. The simple 3D props have visuals but no blocking colliders.

## Automated verification

From the repository root in PowerShell:

```powershell
./tests/suspicion/run_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe'
```

The runner copies only the seven original scripts, new observation files, this
test folder and the existing observation fixture into a unique temporary project.
It does not launch the repository project or its plugins, alter its configuration,
or import its assets. The temporary project and log are retained for inspection.
It parses every involved script, runs behavioral checks with a nonzero exit on
failure, and launches the lab headlessly for a scene smoke test. GUI appearance
still requires a manual scene run.
