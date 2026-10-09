# Custom mother model

The user selected a custom MakeHuman/MPFB character on October 8, 2026, replacing the low-poly direction for the monster. The previous model is retained as a tested placeholder.

## Target appearance

White mother, average build, short black hair, white everyday shirt, navy blue jeans. Give the face visible eyelids, brows, nose, lips, cheeks, and a modeled mouth with teeth. Keep the initial appearance ordinary. Later expression variants introduce a subtle widening smile, dark hollow-looking eyes, facial asymmetry, and stretched limbs while retaining her identity.

## Tools proposed for approval

- Blender, using a compatible stable release (MPFB requires at least 4.2).
- MPFB extension from the official Blender extension platform.
- MakeHuman system assets for skin, eyes, teeth, and related body parts; additional approved CC0 hair and clothing assets as needed.

Standalone MakeHuman is not required by MPFB. Blender/MakeHuman were not found on PATH or running during the initial check; an existing installation may still be available elsewhere. Do not install tools or packages until the user approves installation.

## Build stages

1. Create the ordinary mother with a detailed face and average proportions; present a close-up and full-body view for approval.
2. Add a skeleton and bind hair, clothing, eyes, and teeth. Preserve an editable Blender source and character preset.
3. Add named facial shape controls for the smile and subtle distortion; keep the ordinary face as the neutral basis.
4. Export a game-ready GLB with compatible materials and facial shapes, checking that teeth and eyes follow the face correctly.
5. Test import, face deformation, and animation in Godot 4.7.2. Existing placeholder animations will require retargeting or replacement; compatibility is not guaranteed.

Use `monster-design` for source, export, preview, and provenance files. Keep downloaded tool binaries, caches, and `memory/` out of Git.

References: [MPFB getting started](https://static.makehumancommunity.org/mpfb/docs/getting_started.html), [facial shape export](https://static.makehumancommunity.org/mpfb/docs/exporting/export_copy.html).
