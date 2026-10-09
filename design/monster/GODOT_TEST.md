# Godot model preview test

## Current preview: Everyday Jane

The preview now loads `assets/monster/everyday-jane/EverydayJane.glb`. Tested in Godot 4.7.2: successful import, rendering, and advancement of its single walking clip. Full-body screenshot inspected after correcting camera framing for the source's unskinned bounds. This source has no facial morph targets and no supplied idle/run clips. Original mother placeholders are preserved. Launch `project.godot` and press F5 to view the source model and its Walk button.

## Earlier placeholder tests

The navy-trouser revision was reimported and rendered successfully; Idle/Walk/Run/Wave advancement passed again. The captured viewport was inspected and shows navy trousers. This is a material color change, not a finished denim texture.

The preview now loads `assets/monster/Mother.gltf`, a black-haired design variant. Its rendered preview and Idle/Walk/Run/Wave playback were also tested successfully in Godot 4.7.2. The original Casual source remains preserved.

Tested October 8, 2026 with executable version `4.7.2.stable.official.ed1daf0bf`.

## Open the preview

1. Launch Godot, select **Import**, and select this repository's `project.godot`.
2. Open the project and press **F6** with `design/monster/preview.tscn` open, or **F5** to run the configured main scene.
3. Click **Idle**, **Walk**, **Run**, or **Wave** to inspect the animation. These preview buttons are not gameplay controls.

The approved source model is preserved under `assets/vendor/quaternius/ultimate-modular-women/`. The importable preview copy is `assets/monster/Casual.gltf`. `.gdignore` files exclude download responses and unused vendor assets from this model-only test. Remove the Kenney scan exclusion when house integration is intentionally started.

## Actual results

- Godot imported the glTF and instantiated its meshes and AnimationPlayer.
- All 24 advertised animations were present after import.
- Idle, Walk, Run, and Wave each advanced during a rendered runtime test.
- The OpenGL Compatibility renderer ran on the AMD Radeon graphics device without reported runtime errors.
- A viewport capture was inspected. The model has blond hair, a white shirt, orange trousers, and a stylized low-poly appearance. It is not yet the requested black-haired mother.
- Reported model height from mesh bounds was approximately 1.85 units.

This verifies import, rendering, and animation advancement, not monster mechanics, locomotion navigation, animation quality at every frame, or facial deformation. No chase, hiding, capture, or progression systems exist in this preview.

Checked official Godot 4.7 documentation for [3D scene import](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html) and [AnimationPlayer](https://docs.godotengine.org/en/4.7/classes/class_animationplayer.html).
