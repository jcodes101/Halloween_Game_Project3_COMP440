# Mother model adaptation

The current variants replace the earlier incomplete material-only draft. The original `EverydayJane.glb` and `mimic_copy.blend` are preserved.

Implemented changes:
- Complete short black bob replacing the fused long source hair.
- Smooth continuous head with transferred facial texture, brows, eyes, lips, and shaped nose.
- White short-sleeved shirt, navy denim retaining the source seams, and a modestly broader waist/hip silhouette.
- Rigged mouth interior, lip rim, two rows of teeth, and dark eye surfaces.
- Ordinary through Revealed exports with facial and arm deformation controls.

`finish_mother_design.py` rebuilds the Blender adaptation and four GLBs from the saved source. Texture transfer uses static posed copies so Blender's bake does not mix rest and animated coordinates. Shader results are baked before export to preserve their appearance in Godot.

`Mother_Detailed.blend` contains the editable adaptation and texture-transfer helpers. Helpers are excluded from GLB export. The Godot preview verifies rig and blend-shape presence, animation advancement, and captures each stage for visual review. See `GODOT_TEST.md` for the validation scope.

Earlier `MotherDetailed.glb`, `Mother_Detailed.glb`, and associated drafts remain preserved but are not used by the current preview. The adaptation is detailed stylized art, not photorealistic. Only the source walking animation is currently supplied.
