# Mother mimic design

## Confirmed appearance

A white mother of average build with black hair and everyday clothes. Use the stylized low-poly direction of the house. Her body remains mostly human, with stretched limbs, vacant eyes, and an unnaturally wide smile. Her face becomes more uncanny and distorted as the game progresses.

## Approved model pack

[Quaternius Ultimate Modular Women](https://quaternius.com/packs/ultimatemodularwomen.html), approved October 8, 2026. The creator lists CC0 licensing, ten characters, 24 animations, interchangeable parts, and a humanoid-rig version.

The creator's individual glTF folder lists a `Casual.gltf` character, the first candidate to inspect for everyday clothing. Its actual appearance, hair, skin, animation names, facial topology, and facial controls have not been inspected or confirmed.

## Valid model received

The user supplied `downloads/Casual.gltf` on October 8, 2026. The valid glTF 2.0 file is now tracked at `assets/vendor/quaternius/ultimate-modular-women/Casual.gltf`. Its binary buffer is embedded and it references no image files. JSON inspection confirms a 62-joint `CharacterArmature`, four meshes, and 24 animations, including `Idle`, `Idle_Neutral`, `Walk`, `Run`, `Interact`, `Wave`, and `Death`. None of its mesh primitives include facial morph targets. Material names include `Skin`, `Hair_Brown`, and `Hair_Blond`; black hair and facial distortion require adaptation.

Embedded buffer lengths, buffer-view bounds, and skeleton node references were validated. Appearance has not been visually reviewed and Godot import/playback has not been tested. This is a source asset, not the finished mother design.

## Original download blocker (resolved by user-supplied file)

Initial automated requests returned **Quota exceeded** HTML pages. These error responses remain excluded from Git; do not import them into Godot. The later user-supplied file above resolves the immediate model-download blocker.

Official download folder: https://drive.google.com/drive/folders/1720N9IGyQHXYvtvZJzazhxtTTlz-y2Vf

## Next steps

1. Retain the creator's CC0 license information alongside the valid model.
2. Inspect the Casual candidate and present its appearance for approval before customizing it.
3. Verify a skeleton, usable idle/walk/run animations, model scale, and any facial deformation support. The advertised 24 animations do not guarantee a capture animation or facial controls.
4. Decide how to build the widening smile and vacant eyes after inspecting the geometry. Custom mesh work may be needed.
5. Confirm installed Godot version and version-specific documentation before writing engine code. No Godot scene, monster mechanics, or playable test has been created at this checkpoint.

Keep monster work on `monster-design`. Coordinate familiar routine performance with its owner; monster threat decisions belong to the Mimic / Monster system.
