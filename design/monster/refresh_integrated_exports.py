"""Re-export the saved integrated adaptation after manual mesh edits."""
import bpy,json
from pathlib import Path
root=Path(bpy.data.filepath).parents[3]
head=bpy.data.objects['Mother integrated face']
socket_faces=json.loads((root/'assets/monster/everyday-jane/face_geometry_audit.json').read_text())['socket_face_indices']
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
names=['MotherBody','Mother integrated face','Clean neck below short hair','Clean white everyday shirt','Left short shirt sleeve','Right short shirt sleeve','Short black bob edge','Upper teeth','Lower teeth']
for stage,strength in [('Ordinary',0),('Doubtful',.3),('Uncanny',.65),('Revealed',1)]:
 for name in names:
  o=bpy.data.objects[name]
  if o.data.shape_keys:
   for key in o.data.shape_keys.key_blocks:
    if key.name!='Basis':key.value=1-strength if key.name=='RevealStrength' else strength
 for index in socket_faces:head.data.polygons[index].material_index=5 if strength>=.65 else 4
 bpy.ops.object.select_all(action='DESELECT')
 for o in [bpy.data.objects[name] for name in names]+[rig]:
  o.select_set(True);parent=o.parent
  while parent:parent.select_set(True);parent=parent.parent
 bpy.context.view_layer.objects.active=head
 bpy.ops.export_scene.gltf(filepath=str(root/'assets/monster'/('Mother'+stage+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_morph=True,export_morph_animation=False)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('REFRESHED_INTEGRATED_EXPORTS',flush=True)
