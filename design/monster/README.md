# Mother mimic design

## Confirmed appearance

A white mother of average build with black hair and everyday clothes. Use the stylized low-poly direction of the house. Her body remains mostly human, with stretched limbs, vacant eyes, and an unnaturally wide smile. Her face becomes more uncanny and distorted as the game progresses.

## Approved model pack

[Quaternius Ultimate Modular Women](https://quaternius.com/packs/ultimatemodularwomen.html), approved October 8, 2026. The creator lists CC0 licensing, ten characters, 24 animations, interchangeable parts, and a humanoid-rig version.

The creator's individual glTF folder lists a `Casual.gltf` character, the first candidate to inspect for everyday clothing. Its actual appearance, hair, skin, animation names, facial topology, and facial controls have not been inspected or confirmed.

## Download blocker

On October 8, 2026, Google Drive returned a **Quota exceeded** HTML page for both combined Blender/FBX bundles and the individual Casual glTF file. No valid model was downloaded. These error responses are excluded from Git; do not import them into Godot. Retry the official download later or obtain the pack directly from the creator.

Official download folder: https://drive.google.com/drive/folders/1720N9IGyQHXYvtvZJzazhxtTTlz-y2Vf

## Next steps

1. Download a valid model and retain its license information.
2. Inspect the Casual candidate and present its appearance for approval before customizing it.
3. Verify a skeleton, usable idle/walk/run animations, model scale, and any facial deformation support. The advertised 24 animations do not guarantee a capture animation or facial controls.
4. Decide how to build the widening smile and vacant eyes after inspecting the geometry. Custom mesh work may be needed.
5. Confirm installed Godot version and version-specific documentation before writing engine code. No Godot scene, monster mechanics, or playable test has been created at this checkpoint.

Keep monster work on `monster-design`. Coordinate familiar routine performance with its owner; monster threat decisions belong to the Mimic / Monster system.
