import bpy
from pathlib import Path

root = Path(bpy.data.filepath).parents[3]
mesh = bpy.data.objects['Object_32']
base = mesh.data.materials[0]
image = bpy.data.images['Image_0']
pixels = list(image.pixels)
width, height = image.size
uv = mesh.data.uv_layers.active.data

def sample(poly):
    u = sum(uv[i].uv.x for i in poly.loop_indices) / len(poly.loop_indices)
    v = sum(uv[i].uv.y for i in poly.loop_indices) / len(poly.loop_indices)
    index = (min(height-1,max(0,int(v*height))) * width + min(width-1,max(0,int(u*width)))) * 4
    return pixels[index:index+3]

def tinted(name, color, amount):
    material = base.copy()
    material.name = name
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    source = shader.inputs['Base Color'].links[0].from_socket
    hue = nodes.new('ShaderNodeHueSaturation')
    hue.inputs['Saturation'].default_value = 0.0
    links.new(source, hue.inputs['Color'])
    mix = nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = 1.0
    mix.inputs[2].default_value = (*color, 1)
    links.new(hue.outputs['Color'], mix.inputs[1])
    links.new(mix.outputs[0], shader.inputs['Base Color'])
    links.remove(shader.inputs['Base Color'].links[0])
    shader.inputs['Base Color'].default_value = (*color, 1)
    mesh.data.materials.append(material)
    return len(mesh.data.materials)-1

# Use the existing texture for folds and detail; these materials tint selected faces.
white = tinted('Mother_White_Shirt', (0.65,0.65,0.65),1)
navy = tinted('Mother_Navy_Jeans', (0.012,0.025,0.065),1)
black = tinted('Mother_Black_Hair', (0.005,0.005,0.008),1)
blue_faces=[]
def group_weight(poly, names):
    return sum(g.weight for vi in poly.vertices for g in mesh.data.vertices[vi].groups
               if mesh.vertex_groups[g.group].name in names) / len(poly.vertices)
for poly in mesh.data.polygons:
    r,g,b = sample(poly)
    if b > r*1.05 and g > r*1.05:
        torso = group_weight(poly, {'Spine02_09','Spine01_010','Spine_011','LeftShoulder_012','RightShoulder_016'})
        blue_faces.append((poly, torso))
print('BLUE_REGION_BOUNDS',min(z for _,z in blue_faces),max(z for _,z in blue_faces))
for poly,z in blue_faces:
    poly.material_index = white if z > 0.02 else navy
hair_count=0
for poly in mesh.data.polygons:
    r,g,b = sample(poly)
    center=mesh.matrix_world @ poly.center
    if group_weight(poly, {'Head_021','neck_020','head_end_022'}) > 0.1 and r > g*1.04 and g > b*1.3:
        poly.material_index=black
        hair_count+=1
print('FACE_COUNTS',len(blue_faces),hair_count)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/monster/everyday-jane/Mother_Detailed.blend'))
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True)
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.select_set(True)
for obj in [mesh, rig]:
    parent = obj.parent
    while parent:
        parent.select_set(True)
        parent = parent.parent
bpy.context.view_layer.objects.active=mesh
bpy.ops.export_scene.gltf(filepath=str(root/'assets/monster/everyday-jane/Mother_Detailed.glb'),export_format='GLB',use_selection=True,export_animations=True)
