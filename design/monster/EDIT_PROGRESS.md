# Integrated mother face

The adapted head mesh itself now contains the facial changes. `integrate_mother_face.py`, called by `finish_mother_design.py`, removes the skin spanning the eyes and mouth and connects new eyelid, socket, lip, and oral-cavity surfaces directly to the head's existing boundary vertices. The head is welded into one manifold mesh. Separate black eye ovals, lip-rim objects, and mouth plates are no longer created or exported.

The mouth transitions from a narrow ordinary slit to the wider exposed-teeth opening through `UncannySmile`. Teeth remain separate anatomical meshes, positioned approximately 4.5?7.5 mm behind the exterior face surface inside the cavity. `HollowEyeSockets` changes the actual eyelid/socket geometry; ordinary eyes retain textured detail, while Uncanny and Revealed use dark matte interiors. Hair and clothing remain separate fitted meshes, as is normal for a rigged character.

The ordinary eye surface has a small convex center within its modeled eyelids. The revealed socket floor is recessed approximately 23 mm; the mouth interior extends approximately 27?33 mm behind the original face surface. These are model dimensions, not gameplay settings.

The builder verifies one connected head, no open/non-manifold edges, safe skin triangle splits, and cavity depths at all four stage strengths. Front skin quads are explicitly triangulated to prevent folded slivers at the remodeled boundaries. `check_integrated_mesh.py` separately checks the saved file?s face orientation and actual triangle splits. Results are saved to `assets/monster/everyday-jane/face_geometry_audit.json`. Godot also checks that one integrated head is present, old facial overlay objects are absent, facial deformation values persist, and walking actually moves the bones.

The editable adaptation is `assets/monster/everyday-jane/Mother_Detailed.blend`. `EverydayJane.glb` and the user's `mimic_copy.blend` remain preserved. Earlier material-only drafts remain historical assets and are not used by the current preview. Only the source walking clip is supplied; monster mechanics and additional clips remain future work.
