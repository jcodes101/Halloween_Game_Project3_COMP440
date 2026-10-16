# Phase 3B playable house preview

Open **`res://tests/suspicion/house_preview.tscn`** and press **F6** (Run Current
Scene). F5 still starts the unchanged production main menu. The preview uses the
original house, player, familiar, monster, navigation, audio, UI and escape logic
through inherited scenes and scripts. It starts in the bedroom and retains the
existing wake-up sequence; Space skips that sequence.

## Try the four memories

Look at each small highlighted paper object from nearby and press **E** when its
existing contextual HUD prompt appears:

| Item | Location |
| --- | --- |
| Mom's Recipe Card | Ground-floor kitchen counter, toward the sink end |
| Mom's Unfinished Letter | Mother's bedside cabinet opposite the window-key cabinet |
| Hidden Rehearsal Notes | Upstairs desk beside the existing books |
| Impossible Family Photograph | Basement rear archive worktable |

The left-side story panel shows the original catalog text and current evidence
stage/count. Press **J** to close it, or J again to reopen the last memory. E on
the same object also rereads it. Reading is nonmodal: the house keeps running,
movement and flashlight stay available, and the mouse remains captured. The panel
hides during menus, hiding, climbing, opening sequences, QTEs and endings.

Zero clues is UNAWARE, one or two is DOUBTFUL, and three or four is CERTAIN.
Repeated inspections never add another clue. Objects remain in the world.

The original crowbar and Mother's window key still control the original hatch,
ladder and window escape. Successful pickups are mirrored into `ItemInventory`;
the window key is represented by the existing custom-room-key mechanism with
`room_id = "attic_window"`. No basement-key gate or new door locks are added.

Permanent clue scores feed the familiar's existing 0–100 interface. Existing
noise/sight alertness continues to drive the monster and shared-body handoff;
quiet inspection does not emit an artificial pickup sound. Debug 1/2/3 still
change temporary alertness only, so they no longer set the familiar's evidence
stage in this preview. Evidence behavior resumes after the monster relinquishes
the shared body. Restart the preview through its normal pause/ending menu to
reset the entire house and coordinator together; do not reset just inventory
during a live house session.

## Automated checks

```powershell
./tests/suspicion/run_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe'
./tests/suspicion/run_house_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe' -HouseRegression
```

The first command remains the isolated Phase 3A suite. The second copies game
dependencies, imported asset cache and actual input bindings into a disposable
temporary project, omitting the repository's plugins/autoloads and MCP setup.
All fixture settings and logs live in that temporary directory. It parses the
four new adapters and verifier, runs the Phase 3A checks, then runs a normally
launched preview verification scene with real E/J/F events. `-HouseRegression`
also runs the unchanged `tests/house/verify_house.gd` against the preview.

The focused test freezes the actors after navigation initializes so it can check
item placement/selection and state transitions deterministically. The existing
house regression separately exercises real movement, hiding, ladder travel,
window jumping/landing, false-exit interception, pursuit and capture/QTEs.

The older general integration suite expects temporary debug suspicion to set
the familiar stage. That expectation is intentionally incompatible with the two
separate channels in this preview; its source has not been changed.

Headless checks verify visible scene nodes and unobstructed selection from clear
standing positions, plus exact story contents. They do not assess visual polish,
font legibility on a physical display, or audio quality by listening.

Godot on this machine emits a certificate-store error at startup. The unchanged
house suite can also emit an audio-resource shutdown diagnostic after reporting
all assertions passed (also observed in the unchanged main scene). The runner
reports that shutdown diagnostic as a warning only after the house suite's zero-
failure completion marker; script errors, failed assertions and other errors
remain failures. It also requires explicit completion markers so a timeout or
premature exit cannot silently pass.
