# Connecting the monster to the house

Instantiate `Monster.tscn` in the house. Provide a baked NavigationRegion3D with
continuous paths around furniture and walls. The capsule is 1.6 m tall and
0.32 m in radius. Collision layers used by the prototype are world 1, player 2,
monster 4, and doors 8; agree on the team's final layers before connecting them.

Assign `player_actor`, `interception_anchor` just beyond the basement doorway,
and a reachable `retreat_anchor`. The interception marker's +Z direction faces
toward the doorway. There must be a real traversable route behind the closed door;
the monster cannot teleport into position. Unreachable arrival prevents reveal.

Assign `observation_provider` to an adapter exposing:

```gdscript
func read_monster_observation() -> MonsterObservation:
    # Return a fresh snapshot of the owning systems' current values.
    return snapshot
```

`MonsterObservation` is a provisional typed boundary for this isolated prototype,
not a replacement for established team interfaces. Confirm field mappings with
the Observation and Environment owners before production integration.

| Snapshot field | Owning writer / meaning |
| --- | --- |
| suspicion_level | Observation: 0–100 test recognition input |
| player_location | Environment: actual player feet position |
| is_hidden | Environment: valid hiding interaction |
| player_is_still | Environment: no movement intent or actual movement |
| hiding_check_position | Environment: reachable point outside a hiding place |
| door_state | Environment: CLOSED or OPEN for the basement door |
| escape_progress | Environment: EXPLORING, BASEMENT_READY, or ESCAPED |

The controller reads snapshots and owns `monster_state`, `monster_location`,
`disguise_state`, and `target`. It never writes suspicion, clues, doors, hiding,
or escape progress. It performs physical visibility and navigation checks.
An unseen player's location is not used to move search destinations: those use
the last visible position and a finite route through nearby reachable points.

Connect `interception_ready` to the Environment door gate and arrival warning.
Environment may defer a requested opening until this event. If another owner
opens the door early, reveal still waits for actual monster arrival.
Connect `reveal_started` to presentation cues; the monster holds its pose for the
approved pause, then treats recognition as certain without rewriting suspicion.

Connect `hiding_place_checked(position)` to Environment's validation of a known
hiding place. The lab opens its closet and removes concealment; the monster itself
does not change hiding or door state. A hiding place entered in view remains known.

Connect `capture_requested(monster)` to the capture presentation and player-control
owner. The lab uses a face camera for one second, followed by a restart screen.
Connect `cue_requested(text)` to captions and approved future audio. No audio asset
or autoload was introduced. `state_changed(previous, current)` supports presentation.

For restart, reset every owning system before resuming gameplay, then call
`reset_controller(spawn_position)`. This clears target, search, interception,
reveal, hide knowledge, timers, velocity, and appearance. Spawn relocation is only
used for restart; normal interception and pursuit use physical movement.

The lab does not provide Familiar routine scheduling, clue progression, final house
navigation, final attic-window escape, or production animation/audio integration.
