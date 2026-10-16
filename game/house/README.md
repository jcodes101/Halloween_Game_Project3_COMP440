# The playable house

`game/main.tscn` runs the active house through `game/environment/escape_environment.tscn` and `game/house/house_builder.gd`. The environment is generated when the scene runs. The original rooms and progression remain; the expansion adds a connected rear wing and organizes generated nodes by floor structure, room partitions, staircases, furnishings, attic storage, and neighborhood.

## Layout before expansion

The original footprint was about 22 m wide by 26.5 m deep (x −11..11, z −12..14.5). The three inhabited floors sit at y −3.6, 0, and 3.6 m; the attic floor is at y 7.2 m.

| Level | Existing spaces and connections |
| --- | --- |
| Ground floor | Front porch and foyer, main stair, living room west/front with sofa hiding, kitchen west/rear with basement stair, dining table east/rear, pantry and downstairs bathroom at the back, linked by a narrow central hall. |
| Second floor | Player's bedroom west, guest bedroom opposite, Mother's room and window key in the rear west wing, study east/back, and a closable hiding closet. The main stair connects to the foyer. |
| Basement | Storage and box hiding west, laundry and crowbar/workbench east, false exit and interception route at the front. The kitchen stair is the normal floor connection. |
| Attic | Open roof space with boarded hatch and pull-down ladder near the center, storage boxes and rafters, and the locked escape window at the front. |
| Outside | Porch, front walk, evening street, lamps, planting, and neighboring house silhouettes. |

The room placement and stair positions were already useful, but the rear bathroom/pantry zones had no space behind them, the ground floor had few alternate paths, and furniture was concentrated in the original footprint. The previous side walls, floor rectangles, roof, location labels, and navigation bake also ended at z −12.

## Layout after expansion

The house now reaches z −22 at the back while retaining its original 22 m width, front porch, floor heights, stairs, and escape window. The main floor depth grows from 24 m to 34 m (about 42% more floor area on the rectangular interior footprint). The new rooms attach through two 3 m framed openings in the former rear wall. The west and east wings connect through another wide doorway, and each wing has a framed opening into its rear room, so the extension provides a cross-route instead of sealed extra rooms.

| Level | Expanded spaces and routes |
| --- | --- |
| Ground floor | Original foyer, living room, kitchen, dining room, pantry, and bath remain. The former rear wall now connects the pantry/bath side to a west family room with TV and sofa and an east breakfast room. Beyond them are a west sitting area and east sunroom/reading nook; the rooms cross-connect near the rear. |
| Second floor | The former east Mother room is a guest bedroom. Mother occupies the rear west suite with a double bed, key cabinet, and letter desk. The east wing adds a work area and reading room; the cross-connection remains. |
| Basement | Storage hiding, laundry, and crowbar/workbench remain. The apparent Exit opens onto a sealed encounter pocket; the old side service gap is closed. The rear archive and utility rooms retain their cross-route. |
| Attic | The existing hatch, ladder, escape window, and open attic remain. The roof, floor, rafters, and storage continue over the new rear depth; boxes are kept to the sides to preserve the route from the ladder. |
| Outside | Original porch, neighborhood, and escape landing remain in front. The rear wing is enclosed by extended exterior walls and a matching roof. |

## Assets, collision, and navigation

The expansion reuses the already imported CC0 Kenney building and furniture models: lounge sofa/chair, coffee and side tables, television cabinet/TV, kitchen cabinets, dining table/chairs, bed, desk/chair, bookcases, lamps, plants, and storage boxes. Existing `model`, `_prop`, and `box` helpers keep meshes, approximate furniture collision, and floors aligned. The new furniture is grouped under descriptive room nodes beneath `FurnishingsAndGameplayProps`; the generated shell, room dividers, stairs, floors, attic storage, and neighborhood also have named groups. Existing item and escape nodes remain referenced by the house environment.

Rear floor slabs, side walls/windows, rear wall, roof panels, and gable were extended together. Framed openings preserve player/monster clearance. The rear room partitions have open, framed crossing routes. `main_game.gd` expands the navigation bake bounds through the wing; the existing stair links, open/closed door links, monster collision, and controller remain in use. `house_environment.gd` reports the new room areas correctly rather than treating z < −12 as outdoors. The new guest bed is added through the existing collision-checked hiding system.

Stair meshes and their physics ramps follow the same travel direction. The main ramp meets the upper floor edge without leaving a fall-through gap. Side barriers block entry through either flight while leaving their end landings open.

The main ramp now meets the upstairs floor at z=2.7. Both flights have complete
side barriers included in navigation. Mother reaches a clear landing first,
then walks the physical ramp with collision enabled, avoiding diagonal entry
through its side. Her normal route visits the upstairs landing, kitchen,
basement storage, and rear upstairs hall; a round-trip test verifies this.

## Escape route and controls

1. Find the basement crowbar. The door marked Exit reveals Mother and starts a faster, persistent hunt; it never awards victory. Its former service gap and the encounter pocket are enclosed.
2. Break sight and hide, then find the window key in Mother's rear upstairs room. The order of the two pickups remains flexible.
3. Use the crowbar at the boarded second-floor ceiling hatch and press E to pull down the attic ladder.
4. Climb the ladder with E, then unlock the attic window using Mother's key.
5. Press Space + forward movement to jump through the window; victory follows the physical exterior landing.

WASD/arrows move, Shift runs, mouse looks, E interacts or hides, Space jumps, and Tab/Esc opens or closes the pause menu. R opens restart confirmation while paused. Capture encounters show a randomized on-screen key sequence. The 1/2/3 suspicion inputs are developer testing controls, not normal player controls. Existing Familiar routines, pursuit, concealment, capture, audio, and restart are still connected.

## Validation

Run the house suite in Godot 4.7.2 from the project root:

```powershell
& 'C:\Users\jadin\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --headless --path . game/main.tscn -- --verify-house
```

It checks navigation bake, both stair directions, side entry blocking, wing doorway movement and cross-wing navigation, key/crowbar/hatch/window progression, attic ladder directions, bedroom doors, physical escape landing, every hiding spot, false-exit monster interception, capture, and full restart. The monster test uses the existing AI and is not a substitute for a continuous human playthrough. To review the house visually, open the project in Godot 4.7.2 and press F5; use WASD, mouse, E, and Esc as needed. The existing standalone compact environment remains available only as the legacy regression fixture.
