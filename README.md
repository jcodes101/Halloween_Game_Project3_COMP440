# The Familiar

A first-person horror game project made with Godot. F5 opens the cinematic main
menu; New Game launches the four-level house, story introduction, and bedroom
wake-up sequence. The game includes Familiar routines, pursuit, hiding, escape,
capture, flashlight batteries, VHS effects, and optional dynamic music. Continue
is disabled until a real gameplay save system is added.

## Install the requirements

- **Godot 4.7.2 Standard edition**, which runs GDScript projects. Download from the
  [official Godot website](https://godotengine.org/download/) or its
  [version archive](https://godotengine.org/download/archive/).
- **Git**, available from [git-scm.com](https://git-scm.com/downloads).

On Windows, extract the Godot ZIP and launch its executable. After installing Git,
open a new PowerShell or terminal window. Blender, Python, export templates, and
the Godot .NET edition are not required to play.

## Clone the game from GitHub

Open a terminal in the folder where you want to save the game. Run these commands
one at a time:

```sh
git clone --branch main https://github.com/jcodes101/Halloween_Game_Project3_COMP440.git
cd Halloween_Game_Project3_COMP440
```

Keep the downloaded project folders together. The scenes need the scripts, models,
textures, and other assets included in the repository.

If you already have a clone, open a terminal inside it and update it:

```sh
git fetch origin
git switch main
git pull --ff-only origin main
```

If Git reports local changes or conflicts, preserve your work and resolve them
before updating. Players do not need to commit or push anything.

## Open the project and play in Godot

1. Launch **Godot 4.7.2** to open the Project Manager.
2. Click **Import** and select **`project.godot`** inside the cloned
   `Halloween_Game_Project3_COMP440` folder.
3. Confirm the import and open the project in the editor.
4. Wait for Godot to finish importing the assets on the first launch.
5. Press **F5**, or click **Run Project** at the top-right of the editor.
6. Click inside the running game if it needs keyboard or mouse focus.

On laptops with media function keys, use **Fn+F5** if necessary. Godot automatically
creates its local import cache; you do not need to download it separately.
See the [official project import instructions](https://docs.godotengine.org/en/4.7/tutorials/editor/project_manager.html#opening-and-importing-projects).

## House controls and objective

| Control | Action |
| --- | --- |
| WASD or arrow keys | Move |
| Mouse | Look around |
| Shift + movement | Run |
| E | Pick up a key, interact with a door/exit, enter or leave a hiding place |
| Space | Jump; jump through the unlocked attic window to escape |
| Tab or Esc | Pause / resume |
| R while paused | Open restart confirmation |
| H | Open Controls in the pause menu |
| F8 in the editor | Stop the game |

Find the **crowbar in the basement**, reached through the kitchen stairs. The
**false basement exit** triggers interception and never wins the game. Find the
**attic window key in Mother's room** on the second floor. Use the crowbar at the
boarded ceiling hatch in the upstairs hall, then E to climb the pull-down ladder.
Unlock the attic window, **jump through with Space + forward**, and land outside
to escape. A capture starts a five-second QTE; failure leads to the capture
ending, where Try Again and Main Menu are available.
Follow the on-screen randomized keys during a capture QTE.

Mother stays in her normal household routine before your first clue. The first
two unique clues make her doubtful and watchful; the third permits pursuit.
Sight and noise help her locate you during threat behavior, but do not substitute
for evidence. Trying the false basement exit still provokes its reveal.

Hiding spots include behind the sofa, under both beds, in the upstairs closet, and behind storage
boxes in the basement.
E leaves cover; moving also exits cover and resets
the stillness timer. Hiding transitions temporarily lock movement.

The current house uses the downloaded building and furniture assets. Break her
sight before hiding and stay still for three
seconds. If she sees you enter, she remembers and checks that hiding place.

## Try the monster behavior separately

In Godot's FileSystem panel, open **`tests/monster/behavior_lab.tscn`** and press
**F6 (Run Current Scene)**. F5 launches the main menu.

The lab uses WASD, mouse look, Shift, and E. Press **1** for the disguised mother,
**2** for stalking, **3** for pursuit, and **R** to restart. Its camera has a lower
viewpoint looking up at the mother. Break sight before hiding in the closet and
stay still for three seconds; if she sees you enter, she checks the closet.
The labeled basement-route pedestal and door demonstrate interception. Capture
shows a close-up with a jump-scare sound. The lab also has footstep, door, locked
handle, and sample pickup audio. Headphones help judge sound direction.

The monster lab's sample item and safe exit are independent test interactions.
See the [detailed monster lab guide](design/monster_behavior/README.md).

Developer-only suspicion controls (1 / 2 / 3) are available in the monster lab
and when gameplay debugging is enabled; they are not normal player controls.

## Troubleshooting

- **`git` is not recognized:** install Git and reopen your terminal.
- **F5 opens an older separate scene:** verify that you are on the latest game branch
  with `git branch --show-current`, then use the update commands above.
- **Nothing appears in the editor viewport:** the environment is built when it
  runs. Press F5; the monster lab is also generated when run with F6.
- **Mouse look is not working:** focus the game window and use Esc to recapture
  the mouse.
- **E does nothing:** move close to the object and follow the interaction prompt.
- **Missing assets or script errors:** use Godot 4.7.2, allow imports to finish,
  and keep the entire clone together. Share the first error in Godot's
  Output/Debugger panel if the issue persists.

## Project guides and credits

- [Environment prototype](game/environment/README.md)
- [House layout and escape route](game/house/README.md)
- [Combined scene and system connections](game/integration/README.md)
- [Monster integration notes](systems/monster/INTEGRATION.md)
- [Audio sources and licenses](assets/audio/SOURCES.md)
- [Monster model attribution](assets/monster/everyday-jane/ATTRIBUTION.md)
- [House handoff](handoff/README.md)
