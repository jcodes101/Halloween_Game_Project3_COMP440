# Godot design validation

Tested October 9, 2026 in Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility renderer on the installed AMD Radeon device.

## Current assets

The preview uses `assets/monster/MotherVisual.tscn`, an appearance-only reusable scene. Its `appearance` property selects Ordinary, Doubtful, Uncanny, or Revealed and loads the matching GLB. `mother_visual.gd` explicitly sets the stored deformation values; Godot's imported GLB defaults did not reliably preserve them. The walking export excludes facial animation tracks so walking cannot overwrite the chosen appearance.

## Verified

- All four stage GLBs import, instantiate, and render.
- Each contains one skeleton and the retained walking animation.
- Ordinary has five imported blend shapes; the other stages have eleven, including the new facial additions.
- Walking advances its playback position and changes actual bone poses in each stage.
- Every stage retains the expected facial, arm, and reveal-strength values after walking.
- Full-body and face captures are produced for all stages; Ordinary and Revealed also have side, back, and walking captures. These were inspected for clothing, hair, face seams, hollow eyes, tooth visibility, and the mostly human silhouette.
- The final rendered test reports `ALL MOTHER DESIGN TESTS PASSED`.

## Open and review

1. Import this repository's `project.godot` in Godot and press **F5**.
2. Select **Ordinary**, **Doubtful**, **Uncanny**, or **Revealed**.
3. Use **Face / full body**, **View 0/90/180/270 degrees**, and **Walk / pause**.

To place the appearance in another scene, drag `assets/monster/MotherVisual.tscn` from the FileSystem panel into that scene. Select it and choose its **Appearance** property in the Inspector. The model is instantiated when the scene runs. This provides visuals only, with a paused initial walking pose; it does not move, chase, or capture a player.

The automated review can be run with Godot arguments `--path . -- --verify-model`; it saves screenshots to `design/monster/`. These checks verify import, rendering, stored stage deformation, and walking movement. They do not verify house navigation, chase, hiding, capture, or a smooth gameplay transition. Only the source walking clip is available; idle, chase, and capture clips remain future work. Visual taste still requires the user's review.

Official Godot 4.7 references checked: [AnimationPlayer](https://docs.godotengine.org/en/4.7/classes/class_animationplayer.html), [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html), and [MeshInstance3D](https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html).
