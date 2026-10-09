# Mother mimic design

The current mother adapts the approved detailed **Everyday Jane** model by XRProfXR. The older Quaternius models remain historical placeholders.

The design uses short black hair, warm light skin, a modestly broadened human silhouette, a white everyday shirt, navy denim jeans, and white shoes. A continuous detailed head replaces the fragmented source surface. Four preview variants progressively add a wider exposed-teeth smile, dark hollow-looking eyes, facial deformation, and subtly longer arms.

Open the project in Godot and press **F5**. Select **Ordinary**, **Doubtful**, **Uncanny**, or **Revealed**; use **Face / full body**, the four view angles, and **Walk / pause** to inspect the design. These are art-review controls, not gameplay mechanics.

Editable model: `assets/monster/everyday-jane/Mother_Detailed.blend`. Reusable Godot scene: `assets/monster/MotherVisual.tscn` (choose **Appearance** in the Inspector). Runtime models: `assets/monster/MotherOrdinary.glb`, `MotherDoubtful.glb`, `MotherUncanny.glb`, and `MotherRevealed.glb`. The source GLB and the user's `mimic_copy.blend` are preserved. The source folder has `.gdignore`; Godot uses the exported models.

See [Godot validation](GODOT_TEST.md), [stage details](DESIGN_STAGES.md), and [attribution](../../assets/monster/everyday-jane/ATTRIBUTION.md). Work continues on `monster-refinement`, created from the merged main branch. No chase, hiding, capture, or suspicion integration is included.
