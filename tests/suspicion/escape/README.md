# Escape completion regression

Run from the repository root:

```powershell
./tests/suspicion/run_house_tests.ps1 -GodotPath 'C:/path/to/Godot_console.exe' -HouseRegression -EscapeRegression
```

The runner uses a temporary project copy; it never changes project configuration,
plugins, production scenes, or teammate scripts. Escape verification launches
the existing normal main menu and starts the integrated production house.

It performs a real Space + forward jump through the unlocked attic window,
followed by a second jump while only environment idle processing is withheld
for 1.1 seconds. Player physics and movement continue normally. This reproduces
the old failure: the player passes the brief high window gate between idle
samples, lands outside, but `crossed_window` remains false and no ending occurs.
The adapter now latches the original eligibility in physics updates and leaves
the original environment in charge of landing, stopping controls and emitting
the escape signal. No victory is awarded merely for jumping or unlocking.

Assertions cover the inherited victory UI, control shutdown, stopping the active
familiar/monster owner, exactly-once completion and ending cue, Play Again with
fresh clues/inventory, return to menu, preserving capture, and memorabilia.
The active house has one victory route: the attic window. The basement door
remains an interception/false exit and is explicitly checked not to award victory.
The old prototype basement escape is a separate fixture and is unchanged.

The test selects UI buttons programmatically and injects keyboard events. It
checks UI state and text headlessly; physical mouse/cursor behavior and visual
appearance require manual testing. Baseline engine certificate-store and audio
shutdown diagnostics are handled as documented in the Phase 3B test README.
