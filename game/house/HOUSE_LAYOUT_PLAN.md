# The Familiar — House Architecture and Greybox Plan

This document describes the procedural house assembled by `house_builder.gd` and the architectural cleanup now applied to the rear extension. The plan keeps the existing escape route, player spawn, stair locations, hiding spots, gameplay props, and exterior window landing stable.

## Coordinate key and overall dimensions

- Front of the house is **positive Z**; rear is **negative Z**.
- West is negative X; east is positive X.
- Interior shell is approximately `x = -11…11` (22 m wide) and `z = -22…12` (34 m deep), plus the front porch. This keeps the existing gameplay footprint close to the requested 24 × 34 m target without invalidating the established item and stair coordinates.
- Floor elevations are basement `y=-3.6`, ground `y=0`, second floor `y=3.6`, and attic walkable floor `y=7.2`.
- Typical floor-to-floor clearance is 3.6 m. The attic is unfinished beneath the sloping roof.
- The center circulation strip on the main floors is approximately 2.4 m wide (`x=-1.2…1.2`). Most room openings are approximately 3 m wide in this greybox; major rear openings are broad, framed connections.

## Ground floor

**Implemented living-room bounds:** the builder's ground-floor living room spans roughly `x=-11…-1.2`, `z=3…8` (about 49 m²). The original partition at z=7 moved to z=8, expanding the previous 9.8 × 4 m room by 25%. This is an internal wall change; the shell, kitchen boundary, furniture arrangement, sofa hiding path, and stair locations remain fixed. The wider threshold aligns with the existing living-room entry opening.

```text
                         FRONT / +Z
       WEST                                             EAST
  ┌────────────────────┬────────────┬────────────────────────┐
  │ Living room        │            │ Foyer + main stair     │ z 7…12
  │ sofa / CRT / hide  │ central    │ porch + jammed entry   │
  ├──── doorway ───────┤ hall spine ├────────────────────────┤
  │ Kitchen + basement │            │ Dining room            │ z 0…7
  │ stair              │            │                        │
  ├────────────────────┤            ├────────────────────────┤
  │ Bathroom           │            │ Pantry / storage       │ z -7…-12
  ├─────── rear opening┴──────┬─────┴──── rear opening ──────┤ z -12
  │ Family room               │ Breakfast room                │
  │ sofa / second CRT         │ table / cabinet               │ z -12…-17
  │                           ├── wide opening ────────────────┤
  │                           │ Sunroom / reading area         │ z -17…-22
  └───────────────────────────┴────────────────────────────────┘
                          REAR / -Z
```

The checked generated geometry places the ground-floor west living room at approximately `x=-11…-1.2`, `z=3…8` (9.8 × 5 m, about 49 m²). The earlier room ended at z=7 (9.8 × 4 m, about 39.2 m²); moving the internal foyer divider one metre to z=8 therefore adds 9.8 m², a 25% increase. The exterior shell, kitchen boundary, main stair approach, sofa hiding path, and rear extension remain fixed. East circulation remains unchanged. The rear extension is accessed through two framed openings in the original rear wall. The ground-floor west rear is one continuous family room. On the east, a cross-wall keeps the breakfast area distinct from the far-rear sunroom; a wide opening connects them. The central rear-wing partition has a large cross-opening, providing a loop between west and east routes.

**Connections:** foyer connects to living room and dining/stair side; the hall spine connects kitchen, dining, pantry/bathroom, and the rear openings. Kitchen connects to the basement stair. Dining is next to the kitchen across the hall. Family room and breakfast/sunroom connect through the paired rear openings and rear-wing cross-opening.

## Second floor

```text
                         FRONT / +Z
       WEST                                             EAST
  ┌────────────────────┬────────────┬────────────────────────┐
  │ Landing / player   │            │ Main stair landing     │ z 7…12
  │ circulation        │ hall spine │ closet hiding spot     │
  ├────────────────────┤            ├────────────────────────┤
  │ Player bedroom     │            │ Mother's bedroom       │ z 0…-7
  │ under-bed hiding   │            │ key remains here       │
  ├────────────────────┤            ├────────────────────────┤
  │ Shared bathroom    │            │ Study                  │ z -7…-12
  ├─────── rear opening┴──────┬─────┴──── rear opening ──────┤ z -12
  │ Guest bedroom              │ Study / library              │
  │ under-bed hiding           │ desk, chair, books, reading  │ z -12…-22
  └────────────────────────────┴───────────────────────────────┘
                          REAR / -Z
```

The main stair arrives at the central/east landing. Bedrooms open from the hall side rather than connecting through one another. The original west/east room partitions retain the player and Mother's bedroom locations. The rear west space is one guest bedroom; the rear east study and reading area are combined into one study/library by omitting the unnecessary cross-wall. The attic hatch stays in the upstairs circulation area at `(0, -3)` in X/Z, not inside a bedroom.

**Connections:** main stair to landing; landing to bedrooms, bathroom, study, closet, and rear wing. Both rear openings and a cross-opening between rear sides preserve alternate pursuit routes. The Mother’s room key stays at `(3.5, 4.325, -5.5)`.

## Basement

```text
                         FRONT / +Z
       WEST                                             EAST
  ┌────────────────────┬────────────┬────────────────────────┐
  │ Box storage / hide │ central    │ Storage / false-exit    │ z 0…12
  │                    │ passage    │ encounter door at front │
  ├────────────────────┤            ├────────────────────────┤
  │ Utility / workshop │            │ Work table / utility    │ z -2…-12
  │ crowbar route      │            │ crowbar at (5,-8)       │
  ├─────── rear opening┴──────┬─────┴──── rear opening ──────┤ z -12
  │ Archive / workshop         │ Laundry / mechanical         │
  │ shelving and boxes         │ washer, dryer, boxes         │ z -12…-22
  └────────────────────────────┴───────────────────────────────┘
                          REAR / -Z
```

The kitchen-side basement stair opens into the main passage. The west-side storage alcove retains the box hiding spot. The crowbar remains near `(5, -2.55, -8)`. The rear west space serves as archive/workshop storage; the rear east is the laundry/mechanical zone. Duplicate laundry machines from the middle basement were removed so there is one clear laundry area. Basement partitions remain more confining than the residential floors but leave the central and rear connections navigable. The false-exit door remains blocked until its existing encounter sequence runs and does not become a valid escape.

## Attic and escape

- The boarded hatch is centered near `(0, -3)` in X/Z on the second-floor ceiling. The crowbar remains required to open it; the existing ladder interaction leads to the attic.
- The attic floor is at `y≈7.2`. The center aisle leads from the ladder near `(0, -1.65)` toward the front escape window.
- Rafters and storage boxes remain along the roof space sides; the attic stays open rather than subdivided into arbitrary rooms.
- The locked escape window remains centered on the positive-Z/front wall near `(0, 12)`. Its opening, sill, and exterior landing remain aligned with the current jump-through escape trigger.

## Vertical circulation and navigation

- **Ground to second floor:** 2.4 m wide main stair near `x=4.5`; its ground approach is near `z=10` and its upper landing near `z=3`.
- **Basement to ground:** 2.4 m wide kitchen/service stair near `x=-7`; it rises from basement `z≈-6.4` toward ground `z≈1.4`.
- **Second floor to attic:** ladder through the crowbar-gated hatch. This remains an interaction/climb transition, not a conventional staircase.
- The existing navigation integration bakes static house collision and adds navigation links for the two stair flights and usable doors. The opened rear routes maintain loops on the residential floors. The attic escape ladder is not represented as a monster stair link.

## Interactive room doors and new-game start

- A fresh run starts in the west second-floor bedroom beside the existing single bed, at approximately `(-8.0, 3.6, -4.4)`, facing the bedroom exit. The initial objective is **Leave your bedroom**.
- The player's bedroom door at the west side of the central hall starts closed and uses the same E interaction, hinge animation, and collision layer as the other room doors.
- Additional interactive doors serve the ground-floor bathroom, pantry, dining room, upstairs bathroom, basement workshop, and basement utility room. The second-floor door to the rear guest/study wing remains open at start to preserve circulation.
- The existing Mother's room door remains closed but openable, since its room contains the progression key. The jammed front entrance and false basement exit retain their special locked/encounter behavior; the attic hatch and escape window retain their existing progression interactions.
- During pursuit, the Familiar can open ordinary closed room doors when it reaches the doorway. It cannot open the jammed front door or bypass the false-exit encounter. A room door cannot be closed while the player or Familiar is standing in its swing area.

## Kept gameplay and household assets

- Ground-floor living room sofa hiding, both bedroom under-bed hiding spots, closet hiding, and basement box hiding remain in their existing positions.
- Crowbar, Mother's key, boarded hatch, ladder, window, front door, and false-exit interactions retain their existing coordinates and progression.
- Existing televisions, kitchen appliances, furniture, lamps, plants, bookcases, and storage props are reused. The rear-wing family room retains its CRT; the study/library retains its desk, chair, shelves, books, and reading chair.
- Room location names now distinguish the ground-floor breakfast room from the sunroom, treat the upstairs rear east as one study, and call the rear east basement laundry/utility area utility.

## Changes from the earlier greybox

The base room grid, main hallway, stairs, footprint, item coordinates, and escape route remain because they are already coupled to navigation and gameplay. The former rear-wing cross-walls split large areas into narrow, under-furnished annexes. The ground family room and upstairs guest bedroom are now continuous rear rooms; the upstairs study and reading room are one study/library. The ground east cross-wall remains to create a breakfast-to-sunroom sequence. Basement partitions remain for tighter utility/storage navigation, and redundant middle-basement washer/dryer props were removed.

This is a procedural greybox plan, not a CAD survey. Dimensions are approximate bounds inferred from builder coordinates. Imported model meshes can extend beyond their nominal placement bounds; review the generated scene in Godot for visual fit and clipping.
