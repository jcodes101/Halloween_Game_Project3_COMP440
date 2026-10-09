# Monster behavior prototype

Open the existing project in Godot **4.7.2**. In the FileSystem panel, open
`tests/monster/behavior_lab.tscn`, then press **F6 (Run Current Scene)**.
The room is built when the scene runs, so the editor initially shows an empty root.
F5 still opens the existing model preview.

The first-person camera is 1.05 m above the floor and starts tilted upward by
10 degrees so the mother towers over the player. Mouse look remains free.
The capture camera also looks up from this lower height. Adjust `eye_height` and
`starting_look_up_degrees` in `first_person_player.gd` to tune the viewpoint.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look in first person |
| Shift | Sprint |
| E | Interact with a nearby object you face; enter or leave the closet |
| 1 / 2 / 3 | Simulate unaware / doubtful / certain recognition |
| R | Restart and reset the test |
| Esc / click | Release / capture the mouse |

Start with **2** to see stalking, then **3** to see pursuit. Walls block sight.
Hide in the labeled closet after breaking sight and remain still for three seconds.
Movement keys interrupt that timer even while the closet prevents walking.
If she sees you enter, she remembers the closet and checks it instead.

For the basement test, interact with the green **PREPARE BASEMENT ROUTE** pedestal,
then the basement door. The mother walks around the access loop to wait behind the
closed door. A shadow and captions warn of her arrival. Opening the door reveals
her for one second before pursuit. You retain movement during the reveal.

Capture gives a brief revealed-face close-up, then a captured screen. There are
no flashing effects. A one-second approved horror sting plays with the close-up;
adjust `capture_volume_db` in `systems/monster/lab_audio.gd` to tune its volume.
The green **SAFE TEST EXIT** tests escape and restart; it
does not implement the game's attic-window escape.

## Approved prototype settings

Suspicion ranges from 0–100: stalking begins at 30 and pursuit at 70. Player
walk/sprint speeds are 3.5/5 m/s; monster stalk/chase speeds are 2/4.3 m/s.
Interaction distance is 2 m and capture distance is 0.9 m. Concealment requires
three seconds hidden, still, and out of sight. Basement reveal pause is one second.
These are approved isolated test settings, not confirmed team-wide constants.
Monster settings are in `systems/monster/prototype_tuning.tres`.

## Scope and verification

The controller handles threat decisions, stalking, physical pursuit, last-seen
search, lost-target retreat and reacquisition, basement interception, and capture.
The lab supplies simulated Observation/Environment inputs and a first-person player.
The partner's house and actual clue, lock, crowbar, key and attic escape systems
still need integration. See `systems/monster/INTEGRATION.md`.

The current walking animation is reused and sped up during pursuit. There are no
new chase/capture animation assets. Approved CC0 audio now covers player and mother
footsteps, wooden doors opening/closing, locked handles, and sample item pickup.
Important monster footsteps remain captioned. Press E at the labeled SAMPLE ITEM
to try pickup audio; it resets with R and does not grant a real inventory item.
Try the basement door before preparing the route to hear the locked handle.
Headphones help judge the mother's direction; sound volume falls with distance.
The test room uses simple geometry and is not the final house. Source licenses are
in `assets/audio/SOURCES.md`. Audio levels are initial mix choices to tune by ear.

Run automated checks from the project folder with your Godot executable:

```powershell
& 'C:\Users\kvong\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe' --path . tests/monster/behavior_lab.tscn -- --verify-monster
```

Add `--headless` before `--path` for physics/behavior checks without a window.
Rendered checks also exercise mouse input and save screenshots in this folder.
Tests cover real physics movement, visibility, capture, reset, snapshot ownership,
concealment and interrupted stillness, known hiding checks, finite search,
closed-door pre-positioning, early door opening, reveal timing, unreachable arrival,
and an E-interaction test escape.
