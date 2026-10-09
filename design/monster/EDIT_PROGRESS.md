# Mother editing progress

Created separate `Mother_Detailed.blend` and `Mother_Detailed.glb` from the user's saved copy. The original `mimic_copy.blend` is preserved. The GLB used by the preview is `assets/monster/MotherDetailed.glb`; the editing-source folder is excluded from Godot scanning with `.gdignore`.

The first material pass selects hair and clothing faces using source texture samples and bone weights. Godot 4.7.2 import, rendering, and walking advancement were tested. Visual inspection showed an incomplete white-shirt boundary, incomplete hair recoloring, and jeans that still appear source blue. This is a draft, not a finished mother appearance. The color selection needs refinement or manual texture work before acceptance. Shortening the hair, adjusting build, facial shape controls, teeth, and hollow eyes are not yet implemented.

Next work: replace coarse material selection with clean region masks, review the ordinary appearance, then inspect facial geometry for the subtle horror stages. Preserve attribution from `assets/monster/everyday-jane/ATTRIBUTION.md` for all exported variants.
