"""Build ordinary and progressively uncanny mothers from the preserved source."""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

root=Path(bpy.data.filepath).parents[3]
out=root/'assets/monster/everyday-jane'; exports=root/'assets/monster'
obj=bpy.data.objects['Object_32']; obj.name='MotherBody'
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
base=obj.data.materials[0]; image=bpy.data.images['Image_0']
pixels=list(image.pixels); width,height=image.size
uv=next(u for u in obj.data.uv_layers if u.active_render).data
deps=bpy.context.evaluated_depsgraph_get(); ev=obj.evaluated_get(deps); me=ev.to_mesh()
world=[ev.matrix_world@v.co for v in me.vertices]
surface=BVHTree.FromPolygons(world,[list(p.vertices) for p in obj.data.polygons])
ev.to_mesh_clear()

def sample(poly):
    u=sum(uv[i].uv.x for i in poly.loop_indices)/len(poly.loop_indices)
    v=sum(uv[i].uv.y for i in poly.loop_indices)/len(poly.loop_indices)
    index=(min(height-1,max(0,int(v*height)))*width+min(width-1,max(0,int(u*width))))*4
    return pixels[index:index+3]

def silence_emission(mat):
    s=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    for link in list(s.inputs['Emission Color'].links):mat.node_tree.links.remove(link)
    s.inputs['Emission Strength'].default_value=0
    s.inputs['Metallic'].default_value=0; s.inputs['Roughness'].default_value=.72
    return s

silence_emission(base)
def tint(name,color,brightness):
    mat=base.copy();mat.name=name;s=silence_emission(mat);nodes=mat.node_tree.nodes;links=mat.node_tree.links
    source=s.inputs['Base Color'].links[0].from_socket
    hue=nodes.new('ShaderNodeHueSaturation');hue.inputs['Saturation'].default_value=0;hue.inputs['Value'].default_value=brightness
    links.new(source,hue.inputs['Color'])
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1)
    links.new(hue.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],s.inputs['Base Color'])
    obj.data.materials.append(mat);return len(obj.data.materials)-1

shirt=tint('White cotton fold detail',(1,1,1),4.3)
jeans=tint('Navy denim seam detail',(.16,.25,.46),1)
hair=tint('Short black hair',(.025,.028,.035),1)
hair_vertices=set();trim_faces=[];counts={'shirt':0,'jeans':0,'hair':0}
for p in obj.data.polygons:
    r,g,b=sample(p);c=sum((world[i] for i in p.vertices),Vector())/len(p.vertices)
    blue=g>r*1.015 and b>r*1.015
    face_skin=c.y<-.065 and abs(c.x)<.09 and 1.32<c.z<1.565
    brown=r>g*1.02 and g>b*1.29
    is_hair=(not face_skin or r/max(g,.001)<1.30) and (c.z>1.27 or (c.z>1.08 and (c.y>.035 or abs(c.x)>.10))) and brown
    keep_face=c.y<-.085 and abs(c.x)<.095 and c.z<1.55 and not is_hair
    if c.z>1.29 and not keep_face:trim_faces.append(p.index)
    if blue and c.z<1.35:
        p.material_index=shirt if c.z>.89 else jeans;counts['shirt' if c.z>.89 else 'jeans']+=1
    elif is_hair:
        p.material_index=hair if c.z>1.29 else shirt
        counts['hair']+=1;hair_vertices.update(p.vertices)
print('REGIONS',counts,flush=True)

# Bake shader color only; keep the source's painted folds, seams, and face detail.
bake=bpy.data.images.new('Mother_BaseColor',width=2048,height=2048,alpha=False)
for mat in obj.data.materials:
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=bake;mat.node_tree.nodes.active=node
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
bpy.context.scene.render.bake.use_pass_direct=False;bpy.context.scene.render.bake.use_pass_indirect=False
bpy.context.scene.render.bake.use_pass_color=True;bpy.context.scene.render.bake.margin=4
bpy.ops.object.bake(type='DIFFUSE')
bake.filepath_raw=str(out/'Mother_BaseColor.png');bake.file_format='PNG';bake.save();bake.pack()
mat=bpy.data.materials.new('Mother finished clothing and skin');mat.use_nodes=True
s=mat.node_tree.nodes.get('Principled BSDF');s.inputs['Roughness'].default_value=.72
tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bake;mat.node_tree.links.new(tex.outputs['Color'],s.inputs['Base Color'])
obj.data.materials.clear();obj.data.materials.append(mat)
for p in obj.data.polygons:p.material_index=0

# Inverse skin matrices keep geometric edits compatible with the existing rig.
bone_matrices={b.name:rig.matrix_world@rig.pose.bones[b.name].matrix@b.matrix_local.inverted()@rig.matrix_world.inverted()@obj.matrix_world for b in rig.data.bones}
inverse=[]
for v in obj.data.vertices:
    matrix=Matrix(((0,0,0,0),)*4);total=0
    for g in v.groups:
        name=obj.vertex_groups[g.group].name
        if name in bone_matrices:matrix+=bone_matrices[name]*g.weight;total+=g.weight
    if total:matrix*=1/total
    else:matrix=obj.matrix_world.copy()
    inverse.append(matrix.inverted_safe())
print('SKIN_TRANSFORM_ERROR',max(((inverse[i].inverted_safe()@v.co)-world[i]).length for i,v in enumerate(obj.data.vertices)),flush=True)
# Trim the long locks by removing only their surface faces. Do not pull shared skin vertices.
original_vertex_count=len(obj.data.vertices)
bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in trim_faces],context='FACES_ONLY')
bm.to_mesh(obj.data);bm.free()
assert len(obj.data.vertices)==original_vertex_count
print('TRIMMED_HAIR_FACES',len(trim_faces),flush=True)
new_world=[]
for i,v in enumerate(obj.data.vertices):
    c=world[i].copy();c.x*=1+.09*math.exp(-((c.z-.94)/.30)**2)
    v.co=inverse[i]@c;new_world.append(c)
obj.data.update();obj.shape_key_add(name='Basis')
smile=obj.shape_key_add(name='UncannySmile');eyes=obj.shape_key_add(name='HollowEyeSockets');limbs=obj.shape_key_add(name='StretchedArms')
for i,c in enumerate(new_world):
    near=math.exp(-((c.z-1.384)/.025)**2-((c.x-.003)/.047)**2);front=1 if c.y<-.12 else 0
    delta=Vector(((c.x-.003)*.20*near,0,.0035*near*(abs(c.x-.003)/.045)))*front
    smile.data[i].co=obj.data.vertices[i].co+inverse[i].to_3x3()@delta
    hollow=sum(math.exp(-((c.x-x)/.017)**2-((c.z-1.459)/.012)**2) for x in [-.031,.038])
    eyes.data[i].co=obj.data.vertices[i].co+inverse[i].to_3x3()@Vector((0,.0025*hollow*front,0))
    arm_weight=sum(g.weight for g in obj.data.vertices[i].groups if obj.vertex_groups[g.group].name in {'LeftArm_013','RightArm_017','LeftForeArm_014','RightForeArm_018','LeftHand_015','RightHand_019'})
    stretch=max(0,1.27-c.z)*.105*min(1,arm_weight)
    limbs.data[i].co=obj.data.vertices[i].co+inverse[i].to_3x3()@Vector((0,0,-stretch))

def simple_material(name,color,rough=.65):
    m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes.get('Principled BSDF')
    s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=rough;return m
dark=simple_material('Mouth interior and hollow eyes',(.003,.002,.002))
lip=simple_material('Muted natural lip rim',(.25,.07,.065))
tooth=simple_material('Natural ivory teeth',(.66,.60,.48),.4)
head_inverse=bone_matrices['Head_021'].inverted_safe()
def front_y(x,z,offset=.001):
    hit=surface.ray_cast(Vector((x,-.45,z)),Vector((0,1,0)),.5)[0]
    return (hit.y if hit else -.16)-offset

def skinned_object(name,verts,faces,material):
    data=bpy.data.meshes.new(name);data.from_pydata([head_inverse@Vector(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.matrix_world=obj.matrix_world.copy();data.materials.append(material)
    group=o.vertex_groups.new(name='Head_021');group.add(list(range(len(verts))),1,'REPLACE')
    mod=o.modifiers.new('Follow mother head','ARMATURE');mod.object=rig
    o.parent=obj.parent;o.matrix_world=obj.matrix_world.copy()
    for p in data.polygons:p.use_smooth=True
    return o

def oval(name,cx,cz,rx,rz,offset,mat,curve=0):
    verts=[(cx,front_y(cx,cz,offset),cz)]
    for i in range(48):
        a=2*math.pi*i/48;x=cx+rx*math.cos(a);z=cz+rz*math.sin(a)+curve*math.cos(a)**2
        verts.append((x,front_y(x,z,offset),z))
    faces=[(0,i+1,(i+1)%48+1) for i in range(48)]
    return skinned_object(name,verts,faces,mat)

# Replace the fused scan hair with a complete short bob, keeping the detailed face graft.
bob_mat=simple_material('Black bob satin strands',(.008,.009,.012),.68)
bob_verts=[];bob_faces=[];segments=128;rings=28
for ring in range(rings):
    t=ring/(rings-1)
    for j in range(segments+1):
        a=2*math.pi*j/segments
        front=max(0,-math.cos(a))**6
        side_part=.013*math.sin(a)*front
        bottom=1.405+.132*front+side_part
        phi=math.acos(max(-1,min(1,(bottom-1.463)/.153)))*t
        ripple=.0014*math.sin(j*.9+phi*2)*math.sin(phi)
        x=-.004+math.sin(a)*(.119+ripple)*math.sin(phi)
        y=-.018+math.cos(a)*(.146+ripple)*math.sin(phi)
        z=1.463+.153*math.cos(phi)
        bob_verts.append((x,y,z))
for ring in range(rings-1):
    for j in range(segments):
        a=ring*(segments+1)+j;b=a+segments+1
        bob_faces.append((a,a+1,b+1,b))
bob=skinned_object('Short black bob edge',bob_verts,bob_faces,bob_mat)
skin_mat=simple_material('Pale warm skin under hair',(.78,.51,.36),.76)
def ellipsoid(name,center,radii):
    verts=[];faces=[];segments=64;rings=24
    for r in range(rings+1):
        p=math.pi*r/rings
        for j in range(segments+1):
            a=2*math.pi*j/segments
            verts.append((center[0]+radii[0]*math.sin(p)*math.sin(a),center[1]+radii[1]*math.sin(p)*math.cos(a),center[2]+radii[2]*math.cos(p)))
    for r in range(rings):
        for j in range(segments):
            a=r*(segments+1)+j;b=a+segments+1;faces.append((a,b,b+1,a+1))
    return skinned_object(name,verts,faces,skin_mat)
skull=ellipsoid('Smooth head behind preserved face',(.002,-.022,1.455),(.093,.102,.123))
neck=ellipsoid('Clean neck below short hair',(.001,.008,1.301),(.047,.043,.09))
extras=[oval('Smile lip rim',.003,1.384,.046,.0105,.002,lip,.004),oval('Smile mouth cavity',.003,1.384,.043,.008,.003,dark,.004)]
for side,x in [('Left',-.031),('Right',.038)]:extras.append(oval(side+' hollow eye',x,1.459,.023,.011,.004,dark))
for row in [0,1]:
    verts=[];faces=[]
    for j in range(8):
        x=.003+(j-3.5)*.0084;z=1.384+(.0035 if row==0 else -.0035)+.003*(abs(j-3.5)/3.5)**2;y=front_y(x,z,.004)
        w=.0038;h=.0032 if row==0 else .0024;d=.0015;start=len(verts)
        verts.extend([(x+sx*w,y+sy*d,z+sz*h) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]])
        faces.extend([tuple(start+i for i in f) for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
    extras.append(skinned_object('Upper teeth' if row==0 else 'Lower teeth',verts,faces,tooth))
for o in extras:
    o.shape_key_add(name='Basis');key=o.shape_key_add(name='RevealStrength')
    for i,v in enumerate(o.data.vertices):
        c=bone_matrices['Head_021']@v.co
        if 'Smile' in o.name or 'teeth' in o.name:c.x=.003+(c.x-.003)*.78;c.z=1.384+(c.z-1.384)*.65
        elif 'hollow eye' in o.name:
            cx=-.031 if o.name.startswith('Left') else .038
            c.x=cx+(c.x-cx)*.55;c.z=1.459+(c.z-1.459)*.65
        key.data[i].co=head_inverse@c

def select_for_export(with_extras):
    bpy.ops.object.select_all(action='DESELECT')
    for o in [obj,rig,bob,skull,neck]+(extras if with_extras else []):
        o.select_set(True);parent=o.parent
        while parent:parent.select_set(True);parent=parent.parent
    bpy.context.view_layer.objects.active=obj
stages=[('MotherOrdinary',0,False),('MotherDoubtful',.3,True),('MotherUncanny',.65,True),('MotherRevealed',1,True)]
for name,strength,with_extras in stages:
    smile.value=strength;eyes.value=strength;limbs.value=strength
    for o in extras:o.data.shape_keys.key_blocks['RevealStrength'].value=1-strength
    select_for_export(with_extras)
    bpy.ops.export_scene.gltf(filepath=str(exports/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_morph=True)
    print('EXPORTED',name,flush=True)
select_for_export(True);bpy.ops.wm.save_as_mainfile(filepath=str(out/'Mother_Detailed.blend'))
(out/'build_manifest.json').write_text(json.dumps({'source':'mimic_copy.blend','stages':[s[0] for s in stages],'region_faces':counts,'features':['short black bob','white textured shirt','navy denim','broadened waist/hips','UncannySmile','HollowEyeSockets','StretchedArms','modeled teeth and mouth','skinned facial additions']},indent=2))
print('FINISHED_MOTHER_VARIANTS',flush=True)
