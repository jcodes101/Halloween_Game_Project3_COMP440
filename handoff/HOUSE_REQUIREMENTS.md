# House requirements

## Confirmed by the user

- A larger older suburban house made with 3D assets, with two main floors, a basement, and an attic.
- Ground floor: living room, kitchen, dining room, and bathroom.
- Second floor: two bedrooms, bathroom, and hallway.
- Basement: storage and utility rooms, a false exit, and a crowbar needed for progression.
- Main staircase near the front entrance. Basement stairs enter through the kitchen.
- Mostly narrow halls and dead ends.
- Hiding opportunities in closets, under beds, and behind furniture.
- Attic access through a pull-down ladder. The basement crowbar opens access to the attic.
- A separate key found somewhere outside the basement unlocks the attic window; its exact location has not been selected.
- The real escape is a player jump out of the attic window. A porch-roof escape was suggested but was not approved; do not substitute it for the jump.
- Approved assets: free Kenney Building Kit and Furniture Kit.

## Progression to support in the layout

The basement false exit draws the player downstairs, where the crowbar can be found. The crowbar enables attic access. The separate key unlocks the attic window. The player jumps through the window to escape. The order of key collection relative to crowbar collection remains open.

Reserve room for the mimic encounter and a reachable hiding opportunity near the basement route. Narrow halls and dead ends should still allow a player to evade the creature using the approved hiding spaces.

## Decisions still needed before implementation

- Exact room dimensions, extra rooms, doorway widths, and stair measurements.
- Position and mechanism of the false basement exit.
- What physically blocks attic access and how the crowbar removes it.
- Placement of the window key. An upstairs bedroom closet was suggested but not approved.
- Where the pull-down ladder sits, and how climbing it works.
- Whether the window jump immediately triggers victory or includes a landing sequence.
- Player controls, movement speeds, interaction distance, and hiding mechanics.
- How the earlier basement interception/reveal rule fits the revised false-exit progression. Do not assume the old door trigger remains final.

## Team integration

The GDD proposes Escape / Environment ownership for Jadin Hutchinson; confirm team assignments before treating them as final. Coordinate door progression, hiding, and escape triggers with the other owners.

Reuse agreed interfaces; no shared interface is implemented here yet. The proposed Environment-owned values are `door_state`, `player_location`, `escape_progress`, and `is_hidden`, with `player_is_still` still proposed. Agree on types, signals, and scene paths before connecting systems. Monster code must not overwrite environment state.
