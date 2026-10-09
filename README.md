# The Familiar

A first-person horror game project made with Godot. The current **main** branch
launches a playable house environment prototype: find the basement key, unlock
the basement door, and reach the exit. Monster behavior is available in a separate
test scene and has not yet been connected to the house.

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
| Esc | Release or recapture the mouse |
| R | Restart after escaping or being captured |
| F8 in the editor | Stop the game |

Find and collect the **basement key**, then unlock the **basement door**. Enter the
basement and interact with its **exit** to complete this prototype. Follow the
on-screen interaction prompts. Hiding spots include behind the sofa, under the
bed, and among the crates. E leaves cover; moving also exits cover and resets
the stillness timer. Hiding transitions temporarily lock movement.

This is the current compact environment prototype, not the final two-floor house
and attic-window escape. The house does not currently run the monster's pursuit
or capture behavior.

## Try the monster behavior separately

In Godot's FileSystem panel, open **`tests/monster/behavior_lab.tscn`** and press
**F6 (Run Current Scene)**. F5 continues to launch the house on main.

The lab uses WASD, mouse look, Shift, and E. Press **1** for the disguised mother,
**2** for stalking, **3** for pursuit, and **R** to restart. Its camera has a lower
viewpoint looking up at the mother. Break sight before hiding in the closet and
stay still for three seconds; if she sees you enter, she checks the closet.
The labeled basement-route pedestal and door demonstrate interception. Capture
shows a close-up with a jump-scare sound. The lab also has footstep, door, locked
handle, and sample pickup audio. Headphones help judge sound direction.

The monster lab's sample item and safe exit are independent test interactions.
See the [detailed monster lab guide](design/monster_behavior/README.md).

## Troubleshooting

- **`git` is not recognized:** install Git and reopen your terminal.
- **F5 opens the monster lab or model preview:** verify that you are on `main`
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
- [Monster integration notes](systems/monster/INTEGRATION.md)
- [Audio sources and licenses](assets/audio/SOURCES.md)
- [Monster model attribution](assets/monster/everyday-jane/ATTRIBUTION.md)
- [House handoff](handoff/README.md)
