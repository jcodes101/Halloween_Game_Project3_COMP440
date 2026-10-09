import bpy, json, collections
from mathutils import Vector
obj=bpy.data.objects['Object_32']
deps=bpy.context.evaluated_depsgraph_get()
ev=obj.evaluated_get(deps)
me=ev.to_mesh()
coords=[ev.matrix_world@v.co for v in me.vertices]
print('WORLD_BOUNDS', [(min(c[i] for c in coords), max(c[i] for c in coords)) for i in range(3)])
print('UVS',[(u.name,u.active_render) for u in obj.data.uv_layers])
print('ACTIVE_UV',obj.data.uv_layers.active.name)
parents=list(range(len(obj.data.vertices)))
def find(i):
    while parents[i]!=i:
        parents[i]=parents[parents[i]]; i=parents[i]
    return i
for e in obj.data.edges:
    a,b=map(find,e.vertices); parents[b]=a
parts={}
for i,c in enumerate(coords):parts.setdefault(find(i),[]).append((i,c))
print('PARTS',[(len(cs),[(min(c[i] for _,c in cs),max(c[i] for _,c in cs)) for i in range(3)]) for cs in sorted(parts.values(),key=len,reverse=True)[:15]])
for n in obj.data.materials[0].node_tree.nodes:
    print('NODE',n.name,n.type,[(i.name,i.default_value) for i in n.inputs if i.name=='Vector'])
    if n.type=='TEX_IMAGE':print('TEX',n.image.name if n.image else None,[(l.to_node.name,l.to_socket.name) for out in n.outputs for l in out.links])
counts=collections.Counter()
bounds={}
for v,c in zip(obj.data.vertices,coords):
    if v.groups:
        g=max(v.groups,key=lambda g:g.weight)
        name=obj.vertex_groups[g.group].name
        counts[name]+=1
        bounds.setdefault(name,[]).append(c)
print('GROUPS',json.dumps({n:{'count':counts[n],'bounds':[(min(c[i] for c in cs),max(c[i] for c in cs)) for i in range(3)]} for n,cs in bounds.items()}))
img=bpy.data.images['Image_0']; px=list(img.pixels); uv=obj.data.uv_layers.active.data
head_samples=collections.Counter()
samples=[]
for p in obj.data.polygons:
    u=sum(uv[i].uv.x for i in p.loop_indices)/len(p.loop_indices)
    v=sum(uv[i].uv.y for i in p.loop_indices)/len(p.loop_indices)
    idx=(min(2047,max(0,int(v*2048)))*2048+min(2047,max(0,int(u*2048))))*4
    color=tuple(round(x,2) for x in px[idx:idx+3])
    center=sum((coords[i] for i in p.vertices),Vector())/len(p.vertices)
    if center.z>1.25: head_samples[color]+=1
    if len(samples)<20 and center.z>1.3: samples.append((p.index,list(center),color,[u,v]))
print('HEAD_COLORS',head_samples.most_common(20))
print('HEAD_SAMPLES',samples)
features={'eyes':[],'lips':[]}
for p in obj.data.polygons:
    center=sum((coords[i] for i in p.vertices),Vector())/len(p.vertices)
    if center.z<1.35 or center.y>0 or abs(center.x)>.1:continue
    u=sum(uv[i].uv.x for i in p.loop_indices)/len(p.loop_indices); v=sum(uv[i].uv.y for i in p.loop_indices)/len(p.loop_indices)
    idx=(min(2047,max(0,int(v*2048)))*2048+min(2047,max(0,int(u*2048))))*4
    r,g,b=px[idx:idx+3]
    if b>r*1.2 and b>g*1.05 and 1.42<center.z<1.52 and center.y<-.10 and .014<abs(center.x)<.060:features['eyes'].append(list(center))
    if r>g*1.7 and r>b*1.6 and r>.5 and g>.1 and 1.36<center.z<1.44 and center.y<-.13 and abs(center.x)<.04:features['lips'].append(list(center))
print('FEATURES', {k:{'count':len(cs),'center':[sum(c[i] for c in cs)/len(cs) for i in range(3)] if cs else None,'bounds':[(min(c[i] for c in cs),max(c[i] for c in cs)) for i in range(3)] if cs else None} for k,cs in features.items()})
import numpy as np
fit=[]
for p in obj.data.polygons:
    c=sum((coords[i] for i in p.vertices),Vector())/len(p.vertices)
    if c.y<-.10 and abs(c.x)<.08 and 1.34<c.z<1.535:
        u=sum(uv[i].uv.x for i in p.loop_indices)/len(p.loop_indices); v=sum(uv[i].uv.y for i in p.loop_indices)/len(p.loop_indices)
        if .58<u<.80 and .05<v<.32:fit.append(([c.x,c.z,1],[u,v]))
if fit:
    a=np.array([x for x,y in fit]);b=np.array([y for x,y in fit]);coef=np.linalg.lstsq(a,b,rcond=None)[0]
    print('FACE_UV_FIT',len(fit),coef.tolist(),'ERROR',np.mean(np.linalg.norm(a@coef-b,axis=1)))
ev.to_mesh_clear()
