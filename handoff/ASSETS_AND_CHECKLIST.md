# Assets and build checklist

## Approved asset sources

- [Kenney Building Kit](https://kenney.nl/assets/building-kit): `assets/vendor/kenney/building-kit/`
- [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit): `assets/vendor/kenney/furniture-kit/`

Both kits include their original `License.txt` files and previews. Each includes GLB models under its `Models/` directory, alongside alternative formats. Preserve the original vendor files and license notices. Check the actual model inventory before promising a pull-down ladder, crowbar, or usable window; missing assets have not been approved from another source.

Suggested art treatment: stylized low-poly silhouettes, muted wood, warm cream walls, restrained textures, a cooler dim hall, and a dark basement. Keep routes, stairs, doors, and hiding entrances readable.

## Recommended next steps

1. Confirm the installed Godot version. The user's requested target is **Godot 4.7.2**, not yet verified. Resolve any mismatch with the user. For AI-assisted engine coding, check version-specific documentation using `godot_docs`; if unavailable, tell the user and ask how to proceed.
2. Obtain authorization to create or edit `project.godot`. There is no project configuration here yet, and the user's setup requires explicit authorization for this file.
3. Draft a floor plan with the confirmed rooms and vertical connections. Confirm unresolved layout details before implementing them.
4. Build a simple walkable house layout, then add the approved models. Test stairs, door openings, ceiling clearances, and the attic ladder route.
5. Place furniture with adequate room for each approved hiding interaction. Confirm player dimensions and mechanics before sizing under-bed spaces.
6. Coordinate the crowbar, key, false exit, hiding, and window escape interfaces with the team before implementing shared progression.
7. Run the game after each scene or script change. Record what was actually tested and any failures; do not call an untested scene playable.

## Acceptance checks once gameplay is connected

- Every required room and vertical connection can be reached.
- The basement is entered through the kitchen and cannot serve as the real exit.
- Crowbar collection and attic access work as agreed.
- The separate key unlocks the attic window.
- The player can jump through the open window and trigger the agreed win behavior.
- Closets, beds, and furniture hiding spaces work with agreed visibility and stillness rules.
- The mimic can navigate the intended routes without blocking unavoidable escape paths.
- Capture/restart and a successful escape both work; all owned state and timers reset.

No items on this acceptance list have been tested yet.
