# Blender working-copy inspection

The user supplied `assets/monster/everyday-jane/mimic_copy.blend`. Opened read-only in Blender 5.2.2 LTS with embedded script execution disabled on October 8, 2026.

## Findings

- Character mesh: `Object_32`, 64,573 vertices and 99,045 polygons.
- One material, `Material_1`, and a packed 2048 x 2048 image, `Image_0`.
- Armature: `Object_5`, 25 bones with an armature modifier on the character.
- No shape keys and no dedicated jaw, lip, or eye bones in the inspected rig.
- The file also contains a camera, light, and an unrigged `Icosphere`; these were preserved, not assumed to be part of the character.
- Mouth interior and separate teeth geometry have not yet been visually inspected. Their absence has not been established.

## Recommended first customization

Create a separate editable variant and inspect the head and UV layout closely. Paint the hair black, the shirt white, and the jeans navy in the existing texture where possible. Preserve the original working copy. Review the ordinary mother before adding a custom smile, teeth, or hollow-eye treatment.

This inspection did not modify the Blender file or change the existing Godot preview. The `.blend` is an editing source; use the exported GLB for Godot. Godot may request a Blender executable path if it attempts to import the `.blend` directly.
