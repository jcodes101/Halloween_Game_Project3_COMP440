"""Read-only inspection of the saved integrated head and tooth positions."""
import bpy,json
from collections import Counter
from pathlib import Path
from mathutils import Vector
head=bpy.data.objects['Mother integrated face']
edges=Counter()
for p in head.data.polygons:
 v=list(p.vertices)
 for a,b in zip(v,v[1:]+v[:1]):edges[a,b]+=1
inconsistent=[(a,b) for a,b in edges if edges[a,b]!=edges[b,a]]
print('INCONSISTENT_WINDING_EDGES',len(inconsistent),flush=True)
assert not inconsistent
for name in ['UncannySmile','HollowEyeSockets']:head.data.shape_keys.key_blocks[name].value=0
bpy.context.view_layer.update()
e=head.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh()
folded=0
m.calc_loop_triangles()
for triangle in m.loop_triangles:
 p=m.polygons[triangle.polygon_index]
 points=[e.matrix_world@m.vertices[i].co for i in triangle.vertices]
 center=sum(points,Vector())/3
 if center.y<-.09 and p.material_index<3 and (points[1]-points[0]).cross(points[2]-points[0]).y>1e-9:
  folded+=1;print('FOLD',p.index,p.material_index,tuple(round(v,5) for v in center),[(i,tuple(round(v,6) for v in e.matrix_world@m.vertices[i].co)) for i in p.vertices],flush=True)
print('FRONT_SKIN_FOLDED_TRIANGLES',folded,flush=True)
assert folded==0, 'Folded skin triangles in saved model'
print('HEAD_WORLD_BOUNDS' ,[(min((e.matrix_world@v.co)[a] for v in m.vertices),max((e.matrix_world@v.co)[a] for v in m.vertices)) for a in range(3)])
e.to_mesh_clear()
print('SAVED_HEAD_CHECK_PASSED',flush=True)
