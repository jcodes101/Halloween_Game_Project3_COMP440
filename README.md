# The Familiar — playable monster prototype

A first-person horror prototype featuring a mother-like creature that stalks,
chases, searches, and reacts to hiding and a basement escape attempt.

These instructions run the **monster-behavior** branch. The `main` branch currently
launches the separate house environment; the full house and monster integration
is still in progress.

## 1. Install what you need

- **Godot 4.7.2, Standard edition** (GDScript). Use the version this project was
  tested with. Get Godot from the [official downloads](https://godotengine.org/download/)
  or [version archive](https://godotengine.org/download/archive/).
- **Git**, available from [git-scm.com](https://git-scm.com/downloads). After installing,
  open a new terminal so the `git` command is available.

On Windows, extract the downloaded Godot ZIP and run the Godot executable.
Blender, Python, the .NET edition, export templates, and editor add-ons are not
required to play this prototype. Headphones are recommended for directional footsteps.

## 2. Clone the game from GitHub

Open PowerShell, Terminal, or Git Bash in a folder where you want to keep the game.
Run these commands one at a time:

```sh
git clone --branch monster-behavior https://github.com/jcodes101/Halloween_Game_Project3_COMP440.git
cd Halloween_Game_Project3_COMP440
```

Cloning downloads the project and its tracked assets. Keep the downloaded folders
together; `project.godot` needs the accompanying scripts, scenes, models, and audio.

If you already cloned the repository, open a terminal in that existing folder:

```sh
git fetch origin
git switch monster-behavior
git pull --ff-only
```

If Git reports local changes or conflicts, preserve your work and resolve those
before updating. You do not need to make commits or push anything just to play.

## 3. Import the project into Godot

1. Launch **Godot 4.7.2**. Its first window is the Project Manager.
2. Click **Import**.
3. Browse into `Halloween_Game_Project3_COMP440` and select **`project.godot`**.
4. Confirm the import and open the project in the editor.
5. Wait for the initial asset import to finish. Models and audio may take a little
   time on the first launch.
6. Press **F5**, or click **Run Project** at the top-right of the editor.

The playable monster test room should open. Click inside the game if it needs
focus. On keyboards that use function keys for media controls, try **Fn+F5**.
Godot generates its local import cache automatically; that cache is not in Git.
See the [official project-import guide](https://docs.godotengine.org/en/4.7/tutorials/editor/project_manager.html#opening-and-importing-projects).

## 4. Play

| Control | Action |
| --- | --- |
| WASD | Move |
| Mouse | Look around |
| Shift | Sprint |
| E | Interact with a nearby object you face; enter/leave the closet |
| 1 | Mother stays disguised |
| 2 | Test stalking |
| 3 | Test pursuit |
| R | Restart the test |
| Esc | Release/capture the mouse |
| Click inside game | Capture the mouse again |
| F8 in the editor | Stop the running game |

The camera starts low, looking up toward the mother. Mouse look remains free.

### Things to try

- Press **2** to see stalking, then **3** to start pursuit.
- Break her line of sight behind a wall, enter the **HIDING CLOSET**, and stay still
  for **three seconds**. Movement keys interrupt concealment. If she saw you enter,
  she remembers and checks the closet.
- Try the **BASEMENT TEST DOOR** while locked to hear its handle jiggle. Activate
  the **PREPARE BASEMENT ROUTE** pedestal with E, then try the door again. She walks
  behind it before revealing, pauses for one second, then resumes threatening you.
- Pick up the labeled **SAMPLE ITEM** with E to test pickup audio.
- Let her catch you to see the close-up and hear the jump-scare sting, then press R.
- Reach the **SAFE TEST EXIT** and press E to finish the test.

The sample item and safe exit are test interactions. They do not implement the
final crowbar/key objectives or attic-window escape.

## Troubleshooting

- **`git` is not recognized:** install Git and reopen your terminal.
- **F5 opens the house or a model preview:** check `git branch --show-current`.
  Follow the branch-switch commands above to use `monster-behavior`. You can also
  open `tests/monster/behavior_lab.tscn` in Godot and press **F6** to run that scene.
- **The editor viewport looks empty:** the test room is built when the game runs.
  Press F5 and wait for navigation setup.
- **The mouse will not move the view:** click inside the game; Esc releases it.
- **No interaction happens:** move within 2 meters and face the object until its
  interaction prompt appears, then press E.
- **No sound:** check your computer's output device and volume. The mother starts
  stationary; press 2 or 3 to hear her moving.
- **Missing assets or script errors:** confirm Godot 4.7.2, allow the initial import
  to finish, and check that you cloned the entire project rather than copying only
  `project.godot`. Share the first error from Godot's Output/Debugger panel if it persists.

## More information

- [Detailed prototype guide](design/monster_behavior/README.md)
- [House integration notes](systems/monster/INTEGRATION.md)
- [Audio sources and licenses](assets/audio/SOURCES.md)
- [Monster model documentation](design/monster/README.md)
