# Mother visual stages

The detailed stylized mother retains one recognizable human body and the source's 25-bone rig. Short black hair, a white shirt, navy denim, and white shoes remain consistent.

| Preview variant | Visual treatment |
| --- | --- |
| Ordinary | Readable original eyes and lips, ordinary arm length; no horror additions |
| Doubtful | Small exposed-teeth smile and darkened eyes; 30% facial/arm deformation |
| Uncanny | Wider smile, larger hollow-looking eyes, 65% facial/arm deformation |
| Revealed | Widest modeled tooth smile, vacant dark eyes, full restrained arm stretch |

The exports retain custom `UncannySmile`, `HollowEyeSockets`, and `StretchedArms` blend shapes. A blend shape is a stored mesh deformation, allowing later code to adjust a feature. The face additions also retain `RevealStrength` shapes. Facial detail is transferred onto a smooth connected head; teeth, mouth, eye surfaces, short hair, and shirt are newly modeled and attached to the existing rig.

`MotherVisual.tscn` explicitly applies the chosen stage weights in Godot; use that scene when placing the model. The GLBs retain the custom controls, and their walking animation excludes facial tracks.

These are art-review variants. Their names and visual percentages do not define gameplay thresholds or overwrite another team member's performance stages. Continuous gameplay transformation and monster behavior are not implemented. The downloaded model supplies one walking clip; idle, chase, and capture animations remain future work.
