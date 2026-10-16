# The Familiar — Development Update Report

**Audit date:** 2026-10-15
**Engine target:** Godot 4.7.2, GL Compatibility renderer
**Scope:** Current `main` working tree plus verifiable repository history. The implementation changes audited here are uncommitted at report creation. This report documents evidence and does not assign shared working-tree changes to an individual contributor.

## Executive summary

The project has moved from a compact prototype and separate monster lab toward a connected first-person horror game. The current project entry point is a cinematic title menu. A fresh run enters the existing story introduction and bedroom wake-up, then plays in the four-level procedural house. The active feature set includes the house escape route, interactive doors, Familiar routines and pursuit, hiding, flashlight and randomized battery pickups, a five-second capture QTE, a scene-local adaptive music manager, VHS distortion, environment effects, and shared menus/HUD.

At the start of the audit, the working tree contained 26 modified tracked files and multiple new source/UI/test/audio resources. This audit adds two report files, corrections to existing player-facing help/layout text, and a fade wait in the frontend test. The house verification writes to nine tracked `design/house/*.png` screenshot paths; those captures have HUD/debug framing. They were already modified at audit start, are preserved in the working tree, and are excluded from the commit as generated-looking previews. Git history shows `main` and its locally recorded `origin/main` reference at `ebb39bcf5e13823daf0d583d31f7360bd593c54b` before the fetch phase; this is a snapshot and must be rechecked before commit/push.

## Core gameplay

### MAJOR — Unified playable run and state ownership

`game/integration/main_game.gd` composes the player, procedural house, Familiar controller, monster threat controller, observation/perception bridge, navigation links, HUD, music, camera, and escape environment. The environment owns escape progress, item pickup, hiding state, room doors, and outcome signals; `game_ui.gd` owns presentation; the monster controller owns threat decisions. This preserves distinct system responsibilities rather than duplicating state.

The main project scene is selected in `project.godot`. The main menu instantiates gameplay only after New Game; Continue is disabled because no gameplay save/load implementation exists. Restart and return-to-menu flows clean up scene-local gameplay state rather than falsely treating saved settings as progress.

### HIGH — First-person controls, interactions, and transition gating

`game/environment/first_person_player.gd` keeps movement, mouse look, sprint/jump, interaction requests, hiding transition, and QTE lock behavior in the existing controller. The house exposes E interactions for pickups/doors/escape objects and keeps the wake-up, capture, pause, and ending states from accepting normal movement as appropriate. `game/environment/first_person_player.tscn` contains the player scene setup. Controls continue to use the existing InputMap; the README documents WASD and arrow-key movement, mouse look, Shift, Space, E, F, Tab/Escape, H, and paused restart options.

## Escape and environment

### MAJOR — Four-level escape progression

The house progression continues through the basement crowbar, Mother's room key, crowbar-gated attic hatch/ladder, locked attic window, and physical exterior escape landing. The false basement exit remains an encounter route, not a winning shortcut. Current interaction and progression implementation is in `game/house/house_environment.gd`, house generation in `game/house/house_builder.gd`, and the exterior jump/landing in `game/environment/escape_environment.gd`.

The main route is verified in `tests/house/verify_house.gd`: access routes and interactions are exercised, including the attic path and exterior landing. The report does not infer visual clearance solely from collision/navigation assertions.

### HIGH — Interactive ordinary doors and stair/navigation links

The builder creates ordinary room doors with animated panels and collision; room-door state is exposed for navigation links. Main Game adds links for supported doorways and the two stair flights. The Familiar may open ordinary doors but cannot bypass the jammed front door, false-exit encounter, or progression locks. New-run bedroom access begins behind a closed door. Relevant code: `house_builder.gd`, `house_environment.gd`, and `main_game.gd`.

### MEDIUM — Reorganized rear wing and 25% larger living room

The rear extension is connected through broad openings with a cross-connection. The ground floor keeps separate family, breakfast, and sunroom functions; upstairs merges the rear guest bedroom and study/library into coherent room areas; the basement retains storage/workshop and laundry/utility routes. The ground-floor west living-room bounds are defined as `Rect2(-11, 3, 9.8, 5)`: 49 m² versus the previous 39.2 m², a 25% increase by moving an internal partition. Furniture and sofa hiding remain in-room; the exterior shell and stair approach remain unchanged.

The house plan is `game/house/HOUSE_LAYOUT_PLAN.md`. Its living-room bounds text was corrected in this audit to match `LIVING_ROOM_BOUNDS` and the house assertion. Dimensions remain approximate procedural bounds and should be visually checked in Godot.

## Familiar AI and monster behavior

### MAJOR — Existing Familiar/Monster systems connected to the house

The committed history records development of the mother-like model, face/mesh refinements, monster behavior lab, footsteps and capture sound, and integration with the active house. Current AI sources are `systems/familiar/familiar_controller.gd`, `systems/monster/monster_controller.gd`, and `systems/monster/monster_tuning.gd`.

### HIGH — Evidence-based patrol, investigation, pursuit, concealment, and recovery

The controller uses household activity locations while not in direct pursuit, responds to sight/hearing and player-generated clues, maintains a last-known position, searches after line-of-sight loss, and handles witnessed hiding separately from a completed concealment transition. Hiding still requires three seconds of stillness; movement exits/resets concealment. The Familiar's pathing uses the house navigation and supported door/stair links, and stun/recovery suppresses normal capture behavior for the escape window.

`tests/monster/verify_monster.gd` covers controller-level behavior; `tests/house/verify_house.gd` and `tests/integration/verify_game.gd` exercise house and capture/hiding paths. Headless tests do not prove natural pursuit rhythm, route quality, or fairness; those need playtesting.

## QTE and player interactions

### HIGH — Live capture QTE, randomized keys, and stun escape

The physical close-encounter signal is routed by `main_game.gd` to the QTE before the capture camera/ending. The five-second timer pauses with the menu/tree; QTE input takes precedence for the active key pool. Each encounter creates a three-key sequence from Q/E/R/F with optional deterministic seed and avoids an exact immediately previous sequence where possible. A correct sequence closes the overlay, runs a player camera shove and procedural Familiar visual recoil/stagger, and grants temporary capture protection; failure enters the existing capture ending. Input help now describes the on-screen sequence rather than implying a fixed sequence.

`tests/house/verify_house.gd` exercises the live capture signal path, battery-independent QTE, randomized sequence behavior, pause handling, stun, recapture protection, and failure ending. `tests/integration/verify_game.gd` also checks the physical encounter callback and capture presentation.

### HIGH — Recharge pickups

`house_environment.gd` selects six to eight points from curated positions using Godot `RandomNumberGenerator`; a seed can reproduce a selection. Selection guarantees floor coverage, excludes duplicates, and positions simple battery geometry at reachable points. Collection uses E, updates the existing flashlight controller by up to 35 percentage points, clamps at maximum, removes the pickup, and uses current HUD notification. `flashlight_controller.gd` exposes `recharge_battery()` without replacing drain/flicker/depletion logic.

## House architecture and living room

### MAJOR — Procedural house and retained existing assets

`game/house/house_builder.gd` constructs the shell, room groups, floors, openings, doors, stair flights, navigation-relevant geometry, furniture, props, and hide points. The four floor levels are basement (about y=-3.6), ground (0), second floor (3.6), and attic (7.2), plus porch and escape landing. The updated plan documents floor adjacencies, main items, hiding places, and vertical routes. More than 600 asset instances are asserted by the house suite; the actual scene is generated at runtime from existing asset resources.

### MEDIUM — Living-room expansion and circulation verification

The west front living room is 9.8 × 5 m in the updated bounds, with sofa/CRT/seating, coffee table, rug, bookcase, lamp, ceiling fan, and existing sofa hide path. The house suite checks the 25% expansion, hide-entry bounds, and a navigation path through the doorway. The geometry test is automated; furniture comfort and line-of-sight need manual review.

## 3D graphics, materials, and lighting

### HIGH — House lighting contrast and selected practical effects

`house_builder.gd` sets the house lighting/environment values and selects a limited set of lights. `game/house/house_atmosphere.gd` applies spaced, irregular light dips, CRT glow, television static, and stove steam configuration. It avoids adding a separate large dynamic light array. `crt_screen.gdshader` animates television interference; `steam_puff.gdshader` supplies soft steam; actual models remain existing household assets.

### MEDIUM — VHS screen treatment

`game/integration/vhs_proximity_effect.gd` samples the existing player/monster references and sets shader intensity according to their distance; `vhs_screen_effect.gdshader` provides grain, scanline, banding, tracking disturbance, and subtle color separation. The overlay is separate from interactive HUD controls. Tests verify effect wiring/state; visual noise balance is subjective and needs live review.

### LIMITATION

The graphics work is a restrained procedural pass on existing assets, not a new Blender model set or final texture pass. The generated live menu backdrop is low-poly. No Blender-generated assets were part of this verified working-tree update. Do not describe these changes as photorealistic or professionally lit without a visual art review.

## Main menu and UI/UX

### MAJOR — Cinematic title menu and shared visual system

`game/ui/main_menu.tscn` and `main_menu.gd` present a dark/red title page, live house facade viewport, subtitle, keyboard/mouse navigation, New Game, disabled Continue, Settings, Controls, Credits, and Quit. Gameplay does not instantiate until the player chooses New Game. Settings reuse the `user://familiar_settings.cfg` architecture and AudioServer buses.

`horror_ui_style.gd`, `horror_typography.gd`, and `cinematic_vignette.gdshader` supply shared styling, typography, and vignette. Typography uses installed system serif candidates with fallback, not a repository font file. `menu_house_backdrop.gd` renders a small animated house façade rather than embedding the supplied concept image as a static screen.

### HIGH — Pause, restart confirmation, and endings

`game_ui.gd` builds the four-tab pause menu (Objective, Controls, Settings, Audio), keeps menu controls usable while the world is paused, releases/restores mouse capture, and offers Resume, restart confirmation, and return-to-menu confirmation. The ending screen retains retry and navigation actions and keeps capture/escape outcomes in the existing ending path. No gameplay save system exists, so Continue is honestly unavailable.

### MEDIUM — Responsive screens and interaction states

The shared UI uses Godot containers, viewport anchors, scroll regions, selected/hover/focus states, and theme styling. The frontend suite measures layout at 960×720, 1280×720, and 1920×1080. Rendered previews were inspected at the default 960×720 during the prior visual pass. Automated bounds checks are not equivalent to a human review at all output sizes.

## In-game HUD

### HIGH — Contextual HUD and priority handling

`game/ui/game_ui.gd` owns the existing HUD rather than adding a competing CanvasLayer. It reads current objective/location, flashlight signals/state, interactions, notifications, hiding timer, QTE, menu, and ending signals. It contains compact battery percentage/bar, contextual prompts, objective/location, temporary messages, stillness feedback, and QTE feedback. The paused menu hides gameplay HUD elements while paused; resume restores them.

The QTE control help was updated in this audit to reflect randomized prompted keys. The objective/hiding state comes from environment/monster-owned state rather than independent UI progress simulation.

## Audio and music

### HIGH — Seven-file state-driven music manager

`dynamic_horror_music.gd` scans `assets/audio/music` for matching stems with `.ogg`, `.mp3`, or `.wav`, loads four loops (`exploration`, `investigation`, `chase`, `hiding`) and three one-shots (`qte_sting`, `escape_ending`, `capture_ending`). The four loop players use `Music` bus and crossfade over a configurable interval. Monster states choose exploration/investigation/chase. Hiding replaces the mood only while the player is hidden and the Familiar is within configured threat distance. QTE begins signal a one-shot; escape/capture signals lock gameplay-music selection and play the appropriate ending cue. Loop flags are configured by stream type; one-shots are non-looping.

All seven supplied assets were present in the music folder at audit: `exploration.mp3`, `investigation.mp3`, `chase.mp3`, `hiding.mp3`, `qte_sting.wav`, `escape_ending.wav`, and `capture_ending.wav`. The manager reports discovery/load state; `tests/house/verify_house.gd` covers scenario selection, playback requests, state transitions, pause, and cleanup. Headless validation cannot assess sound quality or loop seams. No creators/licenses/attribution are documented; `assets/audio/music/README.md` explicitly flags this.

### MEDIUM — Existing effects and bus controls

Existing SFX routing and menu volume controls are preserved; music players route to the `Music` bus, with AudioServer buses and settings persistence used for live volume changes. Existing committed history documents Kenney SFX attribution separately; those files do not cover the seven music tracks.

## Wake-up sequence

### HIGH — Story then bedroom start

The existing three-page story UI completes before `wake_up_requested` starts the first-person wake sequence. It begins black, fades the eyelid overlay, blinks, shifts camera position/orientation through a lying/seated/standing path, then restores the normal standing camera and emits completion. The player is spawned in the upstairs bedroom beside the bed; the first objective is “Leave your bedroom.” Wake-up movement/interactions and monster capture are gated until completion, and a skip path restores the final state. The UI and tween are in `game/ui/game_ui.gd`; integration and spawn/state handling are in `game/integration/main_game.gd` and `first_person_player.gd`.

The camera path gives a first-person sensation of waking and standing; there is no visible full-body or leg animation. Timing, clipping, and accessibility comfort require live visual testing.

## Animation and camera effects

### MEDIUM — Movement motion and QTE feedback

The player controller applies configurable movement head bob/sway and landing/QTE shove effects while keeping the HUD independent. The Familiar recoil is procedural on a visual child/hierarchy rather than a new skeletal animation asset; its AI root/navigation state is preserved for recovery. Both motion quality and wall/furniture clearance must be reviewed in a running game. No new animation/audio assets were created for the stun reaction; any additional stun sound is optional and not present as a newly verified asset.

## Testing and validation

### MINOR — Automated suite coverage and actual audit results

The following suites were executed against the working tree:

| Validation | Result | Notes |
| --- | --- | --- |
| Frontend (`--verify-frontend`) | 32 checks, 0 failures; exit 0 | Includes menu controls/settings and responsive bounds checks. |
| House (`game/main.tscn -- --verify-house`) | 157 checks, 0 failures; exit 0 | Exercises layout, navigation, stair/door/escape, hiding, batteries, lighting, music, QTE, HUD, flashlight, and VHS. The test writes screenshot PNGs under `design/house`. |
| Monster (`--verify-monster`) | 51 assertions, 0 failures; exit 0 | Navigation bake reports voxel rounding warnings. |
| Familiar script suite | 79 passed, 0 failed, 79 total; exit 0 | Both Familiar test scenes instantiated. |
| Legacy integration (`--verify-game`) | 25 passed, 0 failed; exit 0 | Includes physical close-encounter to QTE, then failure to capture presentation. Process exit is tied to failure count. |
| Normal headless main-menu launch | exit 0 | `--quit-after 120`; confirms boot path, not visual quality. |
| `git diff --check` | no whitespace errors | Git emitted line-ending conversion notices for two text files. |

Observed environment/process warnings: Godot could not write `user://logs/godot*.log` in this sandbox, could not read the root certificate store, and monster navigation reported voxel-cell size rounding. The legacy scene also emitted an ObjectDB/resource-in-use shutdown warning in a prior run; no assertion failed. These warnings are recorded rather than treated as passing gameplay evidence. No audio was listened to as part of automated validation.

The house suite updates nine tracked images: `attic.png`, `exterior_evening.png`, `foyer.png`, `house_exterior.png`, `kitchen.png`, `mothers_room.png`, `neighborhood_landing.png`, `second_floor.png`, and `window_jump.png`. They show test-time scene/HUD framing and are generated verification output, not source changes. They are intentionally excluded from staging and remain modified in the working tree so no preexisting local change is discarded.

## Bug fixes and maintenance

### HIGH — Capture path bypass correction

The integration suite now triggers the same close-encounter method used by the Familiar signal path and asserts that the QTE is visible before the capture camera/ending. A failed QTE then enters the existing capture presentation. This addresses the previously reported direct-capture bypass and validates that capture is not conditioned on flashlight percentage.

### MINOR — Test failure exit codes, assertion timing, and help-text accuracy

The legacy suite now reports pass/fail totals and returns a failing process exit code when assertions fail. The frontend title visibility assertion waits for the menu fade to complete, removing a frame-timing race. The main-menu capture help no longer documents a fixed Q/R/Q string; README player controls no longer expose debug suspicion keys as standard game controls. The floor-plan living-room coordinates were corrected to match code and its assertion.

## Remaining issues and next steps

1. **Audio rights:** add verified source, creator, license, and attribution for each of the seven music tracks before redistribution.
2. **Font portability:** include a properly licensed serif font if identical typography across machines is required; current system font fallbacks vary with OS.
3. **Visual/audio playtest:** review house exposure, flashlight usefulness, CRT/steam, QTE contrast, music crossfades/loop seams, UI at all three requested resolutions, bed camera clipping, door swings, Familiar chase/stun animation, and end-to-end escape/capture behavior in Godot 4.7.2.
4. **Generated screenshots:** consider changing the house verification harness to write preview captures into `.godot/` or `user://` instead of tracked design documentation paths. This audit leaves the files unchanged and unstaged.
5. **Shutdown diagnostics:** investigate the ObjectDB/resource-in-use warning if it persists in a clean editor/runtime session; current assertions pass.
6. **Godot logging environment:** `user://logs` and certificate-store warnings appear to be sandbox/environment limitations; confirm they do not occur in the team's normal Windows Godot launch.
7. **Git synchronization:** fetch `origin/main` before committing and pushing. Do not infer remote freshness from the local tracking ref captured earlier in this report.

## Files represented by the current implementation

**Modified existing files:** `README.md`; nine `design/house/*.png` test captures (preserved locally but excluded from commit); `game/environment/escape_environment.gd`; `game/environment/first_person_player.gd` and `.tscn`; `game/house/README.md`; `game/house/house_builder.gd`; `game/house/house_environment.gd`; `game/integration/README.md`; `game/integration/main_game.gd`; `project.godot`; `systems/familiar/familiar_controller.gd`; `systems/monster/lab_audio.gd`; `systems/monster/monster_controller.gd`; `systems/monster/monster_tuning.gd`; and house/integration/monster verification scripts.

**New implementation/resources:** the seven audio tracks and `assets/audio/music/README.md`; `game/environment/flashlight_controller.gd` plus UID; `game/house/HOUSE_LAYOUT_PLAN.md`, `house_atmosphere.gd`, CRT/steam shaders and UID sidecars; `game/integration/dynamic_horror_music.gd`, `vhs_proximity_effect.gd`, VHS shader and UID sidecars; `game/ui/main_menu.tscn`, `main_menu.gd`, `game_ui.gd`, `horror_ui_style.gd`, `horror_typography.gd`, `menu_house_backdrop.gd`, `cinematic_vignette.gdshader`, and available Godot UID sidecars; `tests/ui/verify_frontend.gd` and UID; plus this report and `CHANGELOG.md`.

Godot-generated `.import` files and `.godot` cache files are ignored by the repository. The source audio and `.uid` files are legitimate project resources and should be committed after the staged review. The nine test-generated design screenshots should not be staged in this update.
