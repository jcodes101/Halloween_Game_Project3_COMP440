# Monster performance and perception refinements

## Gradual progression in the main game

The main scene now reads permanent evidence recognition separately from temporary
sight/noise alertness. Before any clue, she keeps the household routine; ordinary
walking, doors, pickups, and looking at her do not start aggression. The existing
first and second clues select Doubtful: she watches/stalks without a capture
attack, even after sustained sight. The existing third clue selects Certain:
visible reachable players can be pursued, and lost sight leads to searching.
Trying the false basement exit still triggers the established interception and
reveal regardless of clue count. No new clue thresholds or forced time gates
were added, and the monster never awards evidence.

`Phase3Game.threat_progression_score()` forwards the evidence owner's score into
`MonsterObservation.recognition_score`. The legacy isolated lab leaves that
field negative and retains its explicit alertness-based test controls. Restart
rebuilds the evidence state and restores the ordinary model and routine.
Capture, witnessed-hide checks, and basement arrival now use three-dimensional
distance to prevent proximity events through another floor.

The existing character and walk clip are retained. `threat_motion.gd` layers a
small forward lean and speed-driven vertical motion on the model while the
Monster owns it. Searching adds restrained stationary sway; the reveal stays
still. A post-animation skeleton modifier adds searching head turns, a stalking
head tilt, chase posture, and a close-encounter arm reach. Routine ownership
restores the model transform and disables threat bone offsets. This is procedural
performance, not a new authored run, grab, or door-opening animation.

`MonsterController.heard_alert()` casts through world and door collision layers.
Each of up to three intersected colliders reduces the alert value; opening a
door removes its attenuation when its collision is disabled. Floors also block
the ray. The existing distance limit and falloff still apply. This changes AI
hearing only; it does not filter the player's sound mix. Values are adjustable
in `monster_tuning.gd`. It is an approximation of transmission through solids,
not a simulation of sound travelling around corners.

House integration supplies static room activity points, door positions, and hide
entrances. Search investigates the last contact first, then reachable nearby
points on that floor, followed by shuffled local probes. It never reads the
unseen player's current position to choose those points. An unwitnessed hide
entrance is a place to approach, not permission to expose its occupant. The
existing witnessed-hide and three-second concealment rules retain ownership.
Duplicate points are rejected and blocked search points expire.

Search routes refresh when a newly audible source moves away from the planned
contact, including cumulative movement from several footsteps. Inaudible sounds
cannot redirect them. Optional probes have a navigation-route distance budget,
so a point just across a wall cannot send her on a long house-wide detour.
Arrival checks include floor height. Head, spine and reach offsets now ease
between states, cache bone lookups, and retain the capture pose when movement
processing is stopped for the ending camera.

## Try it

Press F5, choose New Game, and compare walking/running behind an open and closed
door. Break sight at a corner and watch her investigate the last contact before
nearby entrances. Hide out of sight and remain still; then separately try hiding
in direct view. Check basement interception, a successful capture QTE, and a
failed QTE/restart. Playtest timing and visual motion remain subjective.

The monster lab supports `-- --verify-monster`; the main gameplay scene supports
`-- --verify-house`. Tests cover acoustic barriers, last-contact ordering,
same-floor search selection, blocked-point expiry, and existing behavior rules.

Verified in Godot 4.7.2 after the progression fix: headless monster lab 81 checks,
rendered house 167 checks, real observation/inventory integration 72 checks,
and legacy Familiar integration 53 checks,
all with zero failures. House traversal, gradual escalation, hiding, basement
reveal, capture/QTE, escape, and restart are covered. Refreshed house previews
were generated. Full human playtesting of chase fairness and animation quality is
still needed; these checks establish behavior and integration, not final balance.

API reference: [Godot 4.7 SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html)
for post-animation pose layering, and [ray queries](https://docs.godotengine.org/en/4.7/classes/class_physicsrayqueryparameters3d.html)
for geometry-aware hearing.
