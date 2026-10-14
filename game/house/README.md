# The playable house

Press **F5** to run `game/main.tscn`. Its environment is now
`house_environment.tscn`, built from the approved Kenney Building and Furniture kits.
The house is generated when running; the editor root does not display the whole
generated layout before play.

## Layout

| Level | Rooms and routes |
| --- | --- |
| Ground floor | Front foyer and staircase, living room, kitchen, dining room, bathroom, pantry; narrow connecting hall |
| Second floor | Mother's bedroom, player's bedroom, bathroom, study/library, hallway and hiding closet |
| Basement | Storage, utilities/laundry, crowbar on the workbench, false exit and encounter alcove |
| Attic | Boarded ceiling access, pull-down ladder, storage, rafters, locked escape casement |
| Outside | Porch, front path and garden, street/sidewalks, lamps and neighboring houses under an evening sky |

The main stairs are near the front entrance. Basement stairs start **inside the
kitchen** on the left side of the house. Doorways and side rooms produce dead ends.
Closet, under-bed, behind-sofa, and basement storage-box hiding use collision-checked entry and exit routes.

## Escape route and controls

1. Find the **crowbar** on the basement utility workbench. The basement door marked
   FALSE EXIT is a dead end: trying it triggers the mother's interception and reveal.
2. Find the **window key** on the bedside cabinet in **Mother's room**, upstairs.
   Open the bedroom door with E. Crowbar and key can be collected in either order.
3. Locate the pull cord beneath the boarded **ceiling hatch in the second-floor
   hallway**. Face it and press E to pry the boards and deploy the ladder.
4. Press E again to climb. The ladder takes you through the ceiling opening;
   its upper interaction point lets you climb down again.
5. At the attic window, press E to unlock it with Mother's key.
6. Face outside and press **Space + forward movement** to jump over the sill.
   Walking through is not an escape. The camera follows the physical fall; victory
   occurs after landing outside, not at the window or on the porch roof.

WASD/arrows move, Shift runs, mouse looks, E interacts, Space jumps, Esc frees the
mouse, and R restarts. Temporary **1/2/3** suspicion controls remain approved until
the separate Observation implementation is supplied. Existing mother routines,
stalking/pursuit, capture close-up, sound effects, and three-second concealment
remain connected. A hiding place entered in view remains known to the mother.

## Build and verification

The builder uses copied approved GLBs under `assets/environment/`; original
vendor assets and licenses remain intact. See [asset sources](../../assets/environment/SOURCES.md).
Kit orientation is normalized before sizing so real door/window openings retain
their proportions. Native collision shapes match the stair ramps, roof, wall
frames and window sill. Crowbar and ladder are assembled from kit parts.

`tests/house/verify_house.gd` runs with:

```powershell
& 'C:\Users\kvong\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . -- --verify-house
```

Add `--headless` before `--path` for physics verification. Checks cover both stairs,
locks and real pickups, bedroom door passage, ladder directions, physical jump
and landing, all hiding entries/exits, false-exit interception, capture/sting and
restart. Rendered checks save preview PNGs under `design/house/`.

The earlier compact scene remains available at `game/environment/escape_environment.tscn`.
Its integration regression fixture is `tests/integration/legacy_main.tscn` with
`--verify-game`. The new house does not introduce an Observation replacement,
extra character/audio assets, or a new autoload. Existing browser exports in `docs/`
have not been rebuilt for this house.
