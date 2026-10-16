# Monster performance and perception refinements

## Presence and deceptive basement Exit

Mother starts near the upstairs landing. Her normal patrol repeatedly visits
the landing, kitchen, basement storage, kitchen, and rear upstairs hall, with
shorter chore pauses. The household bridge advances the shared body's path
refresh timer while the threat tick is disabled; otherwise she can stop at her
first station. Routine arrival includes floor height. The main stair ramp now
meets its upstairs floor opening so slower NPCs do not fall through its edge.
Both stair flights have side boundaries included in the navigation bake. The
house supplies clear entry/exit landings; the mother navigates to the entry,
then traverses the physical ramp with collision and gravity enabled. This
prevents navigation links from cutting diagonally into a stair's side. The
legacy lab does not configure these house-specific landing routes.

The door and prompt say Exit. On its first attempt, the one existing mother is
staged behind the opaque door in the enclosed pocket, and the door opens for a
visible reveal. After the existing one-second pause, her house chase speed is
5.3 m/s (player sprint remains 5.8). Searching/hunting uses 2.8 m/s. Losing sight
does not end her aggression: she follows fixed basement/kitchen/upstairs hunt
waypoints without reading an unseen player's current location. Concealment,
three-second stillness, and QTE recovery remain available. Repeating the Exit
interaction cannot restart the encounter. The old open service gap is replaced
by a full wall; the pocket has side walls and a ceiling.

Mother's room is now the rear west upstairs suite. Its key is on the cabinet at
`(-3.5, 4.525, -18)` and her letter is on the desk at `(-8.5, 4.54, -19)`.
The room opposite the player's starting bedroom is a guest bedroom.

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

Verified in Godot 4.7.2 after the presence/Exit pass: headless monster lab 82 checks,
rendered house 176 checks, real observation/inventory integration 72 checks,
and legacy Familiar integration 53 checks,
all with zero failures. House traversal, gradual escalation, hiding, basement
reveal, capture/QTE, escape, and restart are covered. Refreshed house previews
were generated. Full human playtesting of chase fairness and animation quality is
still needed; these checks establish behavior and integration, not final balance.

API reference: [Godot 4.7 SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html)
for post-animation pose layering, and [ray queries](https://docs.godotengine.org/en/4.7/classes/class_physicsrayqueryparameters3d.html)
for geometry-aware hearing.
