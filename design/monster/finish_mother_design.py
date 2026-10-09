"""Build ordinary and progressively uncanny mothers from the preserved source."""
import bpy, bmesh, math, json
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
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
source_uvs=[uv[i].uv.copy() for i in range(len(uv))]
face_polys=[];face_uvs=[];patch_polys=[];patch_uvs=[]
for p in obj.data.polygons:
    c=sum((world[i] for i in p.vertices),Vector())/len(p.vertices)
    coords=[source_uvs[i] for i in p.loop_indices]
    u=sum(q.x for q in coords)/len(coords);v=sum(q.y for q in coords)/len(coords)
    index=(min(height-1,max(0,int(v*height)))*width+min(width-1,max(0,int(u*width))))*4
    r,g,b=pixels[index:index+3]
    golden=r>g*1.02 and g>b*1.25 and r/max(g,.001)<1.37 and (c.z>1.485 or abs(c.x)>.060)
    if c.y<-.08 and abs(c.x)<.089 and 1.32<c.z<1.520 and not golden:
        patch_polys.append(list(p.vertices));patch_uvs.append(coords)
    if c.y<-.085 and abs(c.x)<.096 and 1.325<c.z<1.545 and .58<u<.80 and .05<v<.32 and not golden:
        face_polys.append(list(p.vertices));face_uvs.append(coords)
face_surface=BVHTree.FromPolygons(world,face_polys)
source_weights=[]
for v in obj.data.vertices:source_weights.append([(obj.vertex_groups[g.group].name,g.weight) for g in v.groups])
tree=KDTree(len(world))
for i,c in enumerate(world):tree.insert(c,i)
tree.balance()

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
    if c.z>1.29 or (c.z>.865 and abs(c.x)<.17) or (blue and c.z>.83) or (is_hair and c.z>1.08):trim_faces.append(p.index)
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
        bottom=1.405+.125*front+side_part
        phi=math.acos(max(-1,min(1,(bottom-1.463)/.153)))*t
        ripple=.0025*math.sin(18*a+phi*4)*math.sin(phi)
        x=-.004+math.sin(a)*(.119+ripple)*math.sin(phi)
        y=-.018+math.cos(a)*((.163 if math.cos(a)<0 else .146)+ripple)*math.sin(phi)
        z=1.463+.153*math.cos(phi)
        bob_verts.append((x,y,z))
for ring in range(rings-1):
    for j in range(segments):
        a=ring*(segments+1)+j;b=a+segments+1
        bob_faces.append((a,a+1,b+1,b))
bob=skinned_object('Short black bob edge',bob_verts,bob_faces,bob_mat)
skin_mat=simple_material('Pale warm skin under hair',(.90,.46,.29),.76)
def ellipsoid(name,center,radii):
    verts=[];faces=[];segments=128;rings=96
    for r in range(rings+1):
        p=math.pi*r/rings
        for j in range(segments+1):
            a=2*math.pi*j/segments
            verts.append((center[0]+radii[0]*math.sin(p)*math.sin(a),center[1]+radii[1]*math.sin(p)*math.cos(a),center[2]+radii[2]*math.cos(p)))
    for r in range(rings):
        for j in range(segments):
            a=r*(segments+1)+j;b=a+segments+1;faces.append((a,b,b+1,a+1))
    return skinned_object(name,verts,faces,skin_mat)
skull=ellipsoid('Connected detailed mother head',(.003,-.022,1.455),(.100,.135,.135))
face_mat=bpy.data.materials.new('Preserved detailed face texture');face_mat.use_nodes=True
face_shader=face_mat.node_tree.nodes.get('Principled BSDF');face_shader.inputs['Roughness'].default_value=.7
face_texture=face_mat.node_tree.nodes.new('ShaderNodeTexImage');face_texture.image=image
face_mat.node_tree.links.new(face_texture.outputs['Color'],face_shader.inputs['Base Color'])
skull.data.materials.append(face_mat)
face_coordinates=[];face_map=[]
def barycentric(point,a,b,c):
    v0=b-a;v1=c-a;v2=point-a
    aa=v0.dot(v0);ab=v0.dot(v1);bb=v1.dot(v1);pa=v2.dot(v0);pb=v2.dot(v1)
    den=aa*bb-ab*ab
    if abs(den)<1e-14:return (1,0,0)
    v=(bb*pa-ab*pb)/den;w=(aa*pb-ab*pa)/den
    return (1-v-w,v,w)
for v in skull.data.vertices:
    c=bone_matrices['Head_021']@v.co
    if c.y<-.045:
        front=max(0,min(1,(-c.y-.045)/.045))
        nose=.032*math.exp(-((c.x-.003)/.015)**2-((c.z-1.412)/.025)**2)
        muzzle=.027*math.exp(-((c.x-.003)/.055)**2-((c.z-1.378)/.036)**2)
        cheeks=.007*math.exp(-((c.z-1.425)/.05)**2)
        c.y-=front*(nose+muzzle+cheeks)
    v.co=head_inverse@c;face_coordinates.append(c);face_map.append(Vector((.70,.21)))
head_uv=skull.data.uv_layers.new(name='FaceTextureUV')
for p in skull.data.polygons:
    center=sum((face_coordinates[i] for i in p.vertices),Vector())/len(p.vertices)
    p.material_index=0
    for loop in p.loop_indices:head_uv.data[loop].uv=face_map[skull.data.loops[loop].vertex_index]
skull.shape_key_add(name='Basis')
head_smile=skull.shape_key_add(name='UncannySmile');head_eyes=skull.shape_key_add(name='HollowEyeSockets')
for i,c in enumerate(face_coordinates):
    near=math.exp(-((c.z-1.384)/.024)**2-((c.x-.003)/.047)**2)*(1 if c.y<-.12 else 0)
    head_smile.data[i].co=skull.data.vertices[i].co+head_inverse.to_3x3()@Vector(((c.x-.003)*.15*near,0,.0025*near))
    hollow=sum(math.exp(-((c.x-x)/.018)**2-((c.z-1.459)/.013)**2) for x in [-.031,.038])*(1 if c.y<-.12 else 0)
    head_eyes.data[i].co=skull.data.vertices[i].co+head_inverse.to_3x3()@Vector((0,.0025*hollow,0))
neck=ellipsoid('Clean neck below short hair',(.001,.008,1.301),(.047,.043,.09))
patch_verts=[];patch_faces=[];patch_texcoords=[];patch_index={}
for triangle,texcoords in zip(patch_polys,patch_uvs):
    indices=[]
    for vi,texcoord in zip(triangle,texcoords):
        if vi not in patch_index:
            c=world[vi].copy();c.y-=.0012
            patch_index[vi]=len(patch_verts);patch_verts.append(tuple(c))
        indices.append(patch_index[vi]);patch_texcoords.append(texcoord)
    patch_faces.append(tuple(indices))
face_patch=skinned_object('Original detailed facial surface',patch_verts,patch_faces,face_mat)
patch_uv=face_patch.data.uv_layers.new(name='OriginalFaceUV')
for loop in face_patch.data.loops:patch_uv.data[loop.index].uv=patch_texcoords[loop.index]
face_patch.shape_key_add(name='Basis');patch_smile=face_patch.shape_key_add(name='UncannySmile');patch_eyes=face_patch.shape_key_add(name='HollowEyeSockets')
for i,c in enumerate(map(Vector,patch_verts)):
    near=math.exp(-((c.z-1.384)/.025)**2-((c.x-.003)/.047)**2)
    patch_smile.data[i].co=face_patch.data.vertices[i].co+head_inverse.to_3x3()@Vector(((c.x-.003)*.15*near,0,.0025*near))
    hollow=sum(math.exp(-((c.x-x)/.018)**2-((c.z-1.459)/.013)**2) for x in [-.031,.038])
    patch_eyes.data[i].co=face_patch.data.vertices[i].co+head_inverse.to_3x3()@Vector((0,.0025*hollow,0))

# Transfer the source detail to one continuous head surface, avoiding a floating
# facial sheet and preserving a clean silhouette from every direction.
head_uv=skull.data.uv_layers.active
for p in skull.data.polygons:
    for li in p.loop_indices:
        vi=skull.data.loops[li].vertex_index
        row,column=divmod(vi,129)
        head_uv.data[li].uv=(column/128,1-row/96)
face_bake=bpy.data.images.new('Mother_FaceColor',width=2048,height=2048,alpha=True)
head_material=simple_material('Continuous detailed skin',(.90,.46,.29),.76)
skull.data.materials.clear();skull.data.materials.append(head_material)
for p in skull.data.polygons:p.material_index=0
node=head_material.node_tree.nodes.new('ShaderNodeTexImage');node.image=face_bake
head_material.node_tree.nodes.active=node
# Bake posed world-space copies; Blender's active-mesh baker otherwise mixes
# rest coordinates and armature-evaluated source coordinates.
bpy.context.view_layer.update()
def bake_copy(original,name):
    evaluated=original.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data=bpy.data.meshes.new_from_object(evaluated)
    data.transform(evaluated.matrix_world)
    copy=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(copy)
    return copy
bake_source=bake_copy(face_patch,'Texture transfer source')
bake_target=bake_copy(skull,'Texture transfer target')
bpy.ops.object.select_all(action='DESELECT');bake_source.select_set(True);bake_target.select_set(True)
bpy.context.view_layer.objects.active=bake_target
bpy.context.scene.render.bake.use_selected_to_active=True
bpy.context.scene.render.bake.cage_extrusion=.04
bpy.context.scene.render.bake.max_ray_distance=.12
bpy.context.scene.render.bake.margin=12
bpy.ops.object.bake(type='DIFFUSE')
bpy.context.scene.render.bake.use_selected_to_active=False
face_bake.filepath_raw=str(out/'Mother_FaceColor.png');face_bake.file_format='PNG';face_bake.save();face_bake.pack()
# Rays outside the original front face use the same warm skin color.
nodes=head_material.node_tree.nodes;links=head_material.node_tree.links
bw=nodes.new('ShaderNodeRGBToBW');links.new(node.outputs['Color'],bw.inputs[0])
valid=nodes.new('ShaderNodeMath');valid.operation='MULTIPLY';valid.inputs[1].default_value=100;valid.use_clamp=True
links.new(bw.outputs[0],valid.inputs[0])
mix=nodes.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.90,.46,.29,1)
skin_mask=bake_target.data.color_attributes.new(name='CleanFaceBlend',type='FLOAT_COLOR',domain='POINT')
for i,c in enumerate(face_coordinates):
    ellipse=((c.x-.003)/.077)**2+((c.z-1.43)/.106)**2
    weight=max(0,min(1,(1-ellipse)/.40))*max(0,min(1,(c.z-1.355)/.020))*max(0,min(1,(1.505-c.z)/.014))*max(0,min(1,(.071-abs(c.x-.003))/.012)) if c.y<-.075 else 0
    nose_mask=math.exp(-((c.x-.003)/.020)**4-((c.z-1.419)/.022)**4)
    weight*=1-nose_mask*.95
    eye_detail=max(math.exp(-((c.x-x)/.034)**4-((c.z-1.473)/.045)**4) for x in [-.031,.038])
    lip_detail=math.exp(-((c.x-.003)/.060)**4-((c.z-1.379)/.022)**4)
    weight*=max(eye_detail,lip_detail)
    skin_mask.data[i].color=(weight,weight,weight,1)
attribute=nodes.new('ShaderNodeVertexColor');attribute.layer_name='CleanFaceBlend'
product=nodes.new('ShaderNodeMath');product.operation='MULTIPLY'
links.new(attribute.outputs['Color'],product.inputs[0]);links.new(node.outputs['Alpha'],product.inputs[1])
channels=nodes.new('ShaderNodeSeparateColor');channels.mode='RGB';links.new(node.outputs['Color'],channels.inputs['Color'])
def shader_math(operation,a,b):
    n=nodes.new('ShaderNodeMath');n.operation=operation
    for index,value in enumerate([a,b]):
        if isinstance(value,(float,int)):n.inputs[index].default_value=value
        else:links.new(value,n.inputs[index])
    return n.outputs[0]
rg=shader_math('DIVIDE',channels.outputs['Red'],channels.outputs['Green'])
gb=shader_math('DIVIDE',channels.outputs['Green'],channels.outputs['Blue'])
gold=shader_math('MULTIPLY',shader_math('LESS_THAN',rg,1.30),shader_math('GREATER_THAN',gb,1.25))
gold=shader_math('MULTIPLY',gold,shader_math('GREATER_THAN',channels.outputs['Red'],channels.outputs['Green']))
clean=shader_math('MULTIPLY',product.outputs[0],shader_math('SUBTRACT',1,gold))
links.new(clean,mix.inputs[0]);links.new(node.outputs['Color'],mix.inputs[2])
links.new(mix.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
final_face=bpy.data.images.new('Mother_FaceFinished',width=2048,height=2048,alpha=False)
final_node=nodes.new('ShaderNodeTexImage');final_node.image=final_face;nodes.active=final_node
bpy.ops.object.select_all(action='DESELECT');bake_target.select_set(True);bpy.context.view_layer.objects.active=bake_target
bpy.ops.object.bake(type='DIFFUSE')
final_face.filepath_raw=str(out/'Mother_FaceFinished.png');final_face.file_format='PNG';final_face.save();final_face.pack()
links.new(final_node.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])


def clothing_object(name,verts,faces):
    rest=[];groups=[]
    for c in map(Vector,verts):
        nearest,index,distance=tree.find(c)
        weights=[(n,w) for n,w in source_weights[index] if n not in {'Head_021','head_end_022','headfront_023','neck_020'}]
        if not weights:weights=[('Spine_011',1)]
        total=sum(w for n,w in weights);weights=[(n,w/total) for n,w in weights]
        matrix=Matrix(((0,0,0,0),)*4)
        for n,w in weights:matrix+=bone_matrices[n]*w
        rest.append(matrix.inverted_safe()@c);groups.append(weights)
    data=bpy.data.meshes.new(name);data.from_pydata(rest,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.parent=obj.parent;o.matrix_world=obj.matrix_world.copy()
    data.materials.append(simple_material(name+' white cotton',(.64,.64,.61),.83))
    for i,weights in enumerate(groups):
        for n,w in weights:
            group=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);group.add([i],w,'REPLACE')
    mod=o.modifiers.new('Follow body rig','ARMATURE');mod.object=rig
    for p in data.polygons:p.use_smooth=True
    return o

# A closed cotton tee replaces the scan's tangled hair/clothing at the shoulders.
profile=[(.830,.176,.102,-.026),(.88,.159,.093,-.026),(.94,.145,.093,-.030),(1.02,.137,.096,-.034),(1.10,.146,.106,-.039),(1.18,.157,.103,-.033),(1.24,.165,.086,-.015),(1.275,.166,.073,.001),(1.30,.077,.051,.007),(1.300,.050,.044,.009)]
shirt_verts=[];shirt_faces=[];segments=96
for r,(z,rx,ry,cy) in enumerate(profile):
    for j in range(segments+1):
        a=2*math.pi*j/segments
        wrinkle=.0015*math.sin(5*a+r*.8)+.001*math.sin(11*a-r*.3)
        shirt_verts.append((.002+math.sin(a)*(rx+wrinkle),cy+math.cos(a)*(ry+wrinkle),z+.001*math.sin(3*a+r)))
for r in range(len(profile)-1):
    for j in range(segments):
        a=r*(segments+1)+j;b=a+segments+1;shirt_faces.append((a,a+1,b+1,b))
cotton=clothing_object('Clean white everyday shirt',shirt_verts,shirt_faces)
clothes=[cotton]
for side in [-1,1]:
    verts=[];faces=[];rings=6;segments=48
    for r in range(rings):
        t=r/(rings-1);center=Vector((side*(.135+.06*t),-.014,1.267-.115*t))
        radius=.047*(1-t)+.040*t
        axis=Vector((side*.06,0,-.115)).normalized();u=Vector((0,1,0));v=axis.cross(u)
        for j in range(segments+1):
            a=2*math.pi*j/segments
            c=center+u*(math.cos(a)*radius)+v*(math.sin(a)*radius)
            verts.append(tuple(c))
    for r in range(rings-1):
        for j in range(segments):
            a=r*(segments+1)+j;b=a+segments+1;faces.append((a,a+1,b+1,b))
    clothes.append(clothing_object(('Left' if side<0 else 'Right')+' short shirt sleeve',verts,faces))
bpy.context.view_layer.update()
evaluated_head=skull.evaluated_get(bpy.context.evaluated_depsgraph_get())
head_mesh=evaluated_head.to_mesh()
surface=BVHTree.FromPolygons([evaluated_head.matrix_world@v.co for v in head_mesh.vertices],[list(p.vertices) for p in head_mesh.polygons])
evaluated_head.to_mesh_clear()
extras=[oval('Smile lip rim',.003,1.384,.046,.0105,.009,lip,.004),oval('Smile mouth cavity',.003,1.384,.043,.008,.012,dark,.004)]
for side,x in [('Left',-.031),('Right',.038)]:extras.append(oval(side+' hollow eye',x,1.459,.029,.016,.012,dark))
for row in [0,1]:
    verts=[];faces=[]
    for j in range(8):
        x=.003+(j-3.5)*.0084;z=1.384+(.0035 if row==0 else -.0035)+.003*(abs(j-3.5)/3.5)**2;y=front_y(x,z,.014)
        w=.0038;h=.0032 if row==0 else .0024;d=.0015;start=len(verts)
        verts.extend([(x+sx*w,y+sy*d,z+sz*h) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]])
        faces.extend([tuple(start+i for i in f) for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
    tooth_object=skinned_object('Upper teeth' if row==0 else 'Lower teeth',verts,faces,tooth)
    bm=bmesh.new();bm.from_mesh(tooth_object.data)
    bmesh.ops.bevel(bm,geom=list(bm.edges),offset=.000004,segments=3,affect='EDGES')
    bm.to_mesh(tooth_object.data);bm.free()
    extras.append(tooth_object)
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
    for o in [obj,rig,bob,skull,neck]+clothes+(extras if with_extras else []):
        o.select_set(True);parent=o.parent
        while parent:parent.select_set(True);parent=parent.parent
    bpy.context.view_layer.objects.active=obj
stages=[('MotherOrdinary',0,False),('MotherDoubtful',.3,True),('MotherUncanny',.65,True),('MotherRevealed',1,True)]
for name,strength,with_extras in stages:
    smile.value=strength;eyes.value=strength;limbs.value=strength
    head_smile.value=strength;head_eyes.value=strength
    patch_smile.value=strength;patch_eyes.value=strength
    for o in extras:o.data.shape_keys.key_blocks['RevealStrength'].value=1-strength
    select_for_export(with_extras)
    bpy.ops.export_scene.gltf(filepath=str(exports/(name+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_morph=True,export_morph_animation=False)
    print('EXPORTED',name,flush=True)
for helper in [face_patch,bake_source,bake_target]:
    helper.hide_set(True);helper.hide_render=True
select_for_export(True);bpy.ops.wm.save_as_mainfile(filepath=str(out/'Mother_Detailed.blend'))
(out/'build_manifest.json').write_text(json.dumps({'source':'mimic_copy.blend','stages':[s[0] for s in stages],'region_faces':counts,'features':['short black bob','white short-sleeved shirt','navy denim','broadened waist/hips','UncannySmile','HollowEyeSockets','StretchedArms','modeled teeth and mouth','skinned facial additions']},indent=2))
print('FINISHED_MOTHER_VARIANTS',flush=True)
