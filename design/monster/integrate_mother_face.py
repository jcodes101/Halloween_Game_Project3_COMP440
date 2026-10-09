"""Edit the head mesh itself: welded eyelids, recessed sockets and oral cavity.

The lip, socket and mouth rings reuse the cut head's boundary vertices. They
are part of the same connected mesh, not objects laid over intact facial skin.
All distances below are posed world metres; the caller supplies inverse skin.
"""
import math
from collections import defaultdict

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def integrate_face(head, skin_matrix, head_inverse, front_y, skin, lip, dark):
    source = head.data
    uv_layer = source.uv_layers.active
    base = [skin_matrix @ v.co for v in source.vertices]
    smile = [skin_matrix @ v.co for v in source.shape_keys.key_blocks['UncannySmile'].data]
    hollow = [skin_matrix @ v.co for v in source.shape_keys.key_blocks['HollowEyeSockets'].data]
    vertices, smile_positions, eye_positions = [], [], []
    weld, remap = {}, {}
    for i, point in enumerate(base):
        position = tuple(round(value, 8) for value in point)
        if position not in weld:
            weld[position] = len(vertices)
            vertices.append(point.copy())
            # The new facial rings own deformation. Keep the surrounding head
            # steady instead of combining an old 2-D stretch with the new lips.
            smile_positions.append(point.copy())
            eye_positions.append(point.copy())
        remap[i] = weld[position]

    # Remove the intact skin spanning each opening, then reuse its boundary.
    features = [
        ('mouth', .003, 1.379, .062, .026),
        ('left_socket', -.031, 1.459, .033, .022),
        ('right_socket', .038, 1.459, .033, .022),
    ]
    faces, face_uvs, materials = [], [], []
    removed = defaultdict(list)
    for polygon in source.polygons:
        indices, uvs = [], []
        for li in reversed(polygon.loop_indices):
            index = remap[source.loops[li].vertex_index]
            if index not in indices:
                indices.append(index)
                uvs.append(tuple(uv_layer.data[li].uv))
        if len(indices) < 3:
            continue
        center = sum((vertices[i] for i in indices), Vector()) / len(indices)
        cut = None
        if center.y < -.09:
            for name, x, z, rx, rz in features:
                cut_x=x+(-.0015 if name=='left_socket' else .0015 if name=='right_socket' else 0)
                cut_z=z-(.003 if name!='mouth' else 0)
                if ((center.x-cut_x)/rx)**2 + ((center.z-cut_z)/rz)**2 < 1:
                    cut = name
                    break
        if cut:
            removed[cut].append(tuple(indices))
        else:
            faces.append(tuple(indices)); face_uvs.append(uvs); materials.append(0)

    def uv_for(point):
        phi = math.acos(max(-1, min(1, (point.z-1.455)/.135)))
        denominator = .100 * math.sin(phi)
        angle = math.pi-math.asin(max(-1, min(1, (point.x-.003)/max(.00001, denominator))))
        return (angle/(2*math.pi), 1-phi/math.pi)

    def add_vertex(ordinary, revealed, feature):
        index = len(vertices)
        vertices.append(ordinary)
        smile_positions.append(revealed if feature == 'mouth' else ordinary.copy())
        eye_positions.append(revealed if feature != 'mouth' else ordinary.copy())
        return index

    def add_face(indices, material):
        faces.append(tuple(indices))
        face_uvs.append([uv_for(vertices[i]) for i in indices])
        materials.append(material)
        return len(faces)-1

    socket_faces, reports, moved_boundaries = [], [], set()
    for feature, cx, cz, rx, rz in features:
        edge_counts = defaultdict(int)
        for face in removed[feature]:
            for a, b in zip(face, face[1:]+face[:1]):
                edge_counts[tuple(sorted((a,b)))] += 1
        adjacency = defaultdict(list)
        for (a,b), count in edge_counts.items():
            if count == 1:
                adjacency[a].append(b); adjacency[b].append(a)
        assert adjacency and all(len(value) == 2 for value in adjacency.values()), feature
        start = next(iter(adjacency)); boundary = [start]
        previous, current = None, start
        while True:
            next_vertex = next(i for i in adjacency[current] if i != previous)
            if next_vertex == start:
                break
            boundary.append(next_vertex)
            previous, current = current, next_vertex
            assert len(boundary) <= len(adjacency)
        assert len(boundary) == len(adjacency), 'Disconnected cut: '+feature
        # Preserve actual edge adjacency. Sorting a staircase boundary by angle
        # can silently replace its edges and leave cracks in the surrounding skin.
        signed_area=sum(vertices[a].x*vertices[b].z-vertices[b].x*vertices[a].z
                        for a,b in zip(boundary,boundary[1:]+boundary[:1]))
        if signed_area<0:boundary.reverse()
        raw=[math.atan2((vertices[i].z-cz)/rz,(vertices[i].x-cx)/rx) for i in boundary]
        angles=[raw[0]]
        for a,b in zip(raw,raw[1:]):
            angles.append(angles[-1]+math.atan2(math.sin(b-a),math.cos(b-a)))
        # Fit a monotone angular sequence without shifting points around the
        # opening. Small staircase reversals are pooled instead of twisting
        # the whole cheek by reparameterizing its perimeter length.
        epsilon=.0005;blocks=[]
        for i,angle in enumerate(angles):
            blocks.append([angle-i*epsilon,1])
            while len(blocks)>1 and blocks[-2][0]>blocks[-1][0]:
                b=blocks.pop();a=blocks.pop();count=a[1]+b[1]
                blocks.append([(a[0]*a[1]+b[0]*b[1])/count,count])
        fitted=[value for value,count in blocks for _ in range(count)]
        start=raw[0]
        angles=[max(start+i*epsilon,min(start+2*math.pi-(len(raw)-i)*epsilon,value+i*epsilon))
                for i,value in enumerate(fitted)]
        # Put the shared boundary itself on a smooth ellipse, safely inside
        # the cut. Both the retained skin and new rings use these same vertices.
        cut_x=cx+(-.0015 if feature=='left_socket' else .0015 if feature=='right_socket' else 0)
        cut_z=cz-(.003 if feature!='mouth' else 0)
        for index,angle in zip(boundary,angles):
            x=cut_x+rx*.91*math.cos(angle)
            z=cut_z+rz*.91*math.sin(angle)
            point=Vector((x,front_y(x,z,0),z))
            vertices[index]=point
            smile_positions[index]=point.copy();eye_positions[index]=point.copy()
            moved_boundaries.add(index)
        previous_ring = boundary

        def ring(ordinary_rx, ordinary_rz, revealed_rx, revealed_rz,
                 ordinary_depth, revealed_depth, material, curve=0):
            nonlocal previous_ring
            indices = []
            for angle in angles:
                positions = []
                for radius_x, radius_z, depth in [
                    (ordinary_rx, ordinary_rz, ordinary_depth),
                    (revealed_rx, revealed_rz, revealed_depth),
                ]:
                    x = cx+radius_x*math.cos(angle)
                    z = cz+radius_z*math.sin(angle)+curve*math.cos(angle)**2
                    positions.append(Vector((x, front_y(x,z,0)+depth, z)))
                indices.append(add_vertex(*positions, feature))
            # Subdivide the cheek/lid transition instead of stretching a
            # single large quad from the irregular cut to the lip or eyelid.
            if previous_ring == boundary:
                outer_ring=boundary
                transition_count=7 if feature=='mouth' else 3
                for step in range(1,transition_count):
                    t=step/transition_count; transition=[]
                    for outer,inner in zip(outer_ring,indices):
                        end_ordinary=vertices[inner]
                        end_revealed=(smile_positions if feature=='mouth' else eye_positions)[inner]
                        start_revealed=(smile_positions if feature=='mouth' else eye_positions)[outer]
                        positions=[]
                        for start,end in [(vertices[outer],end_ordinary),(start_revealed,end_revealed)]:
                            point=start.lerp(end,t)
                            point.y=front_y(point.x,point.z,0)+(ordinary_depth if len(positions)==0 else revealed_depth)*t
                            positions.append(point)
                        transition.append(add_vertex(*positions,feature))
                    for j in range(len(transition)):
                        k=(j+1)%len(transition)
                        add_face((previous_ring[j],previous_ring[k],transition[k],transition[j]),1)
                    previous_ring=transition
            for j in range(len(indices)):
                k = (j+1)%len(indices)
                face_index = add_face((previous_ring[j],previous_ring[k],indices[k],indices[j]), material)
                if material == 4:
                    socket_faces.append(face_index)
            previous_ring = indices

        if feature == 'mouth':
            # Outer skin transitions into genuine lip volume, then an opening.
            ring(.036,.0065,.050,.015,0,0,1,.003)
            ring(.033,.0030,.048,.012,-.0010,-.0014,2,.003)
            ring(.031,.00055,.044,.009,0,0,2,.003)
            ring(.030,.0005,.043,.0085,.009,.011,3,.003)
            ring(.027,.0005,.039,.0080,.025,.029,3,.002)
            depth_ordinary, depth_revealed = .027,.033
            bottom_material = 3
        else:
            # Continuous skin eyelid -> inset eye surface -> deep socket floor.
            ring(.027,.014,.027,.015,0,.001,1)
            ring(.025,.011,.026,.012,-.0008,-.0002,1)
            ring(.023,.010,.024,.011,.002,.010,4)
            ring(.015,.007,.016,.007,-.0002,.019,4)
            depth_ordinary, depth_revealed = -.0005,.023
            bottom_material = 4
        y = front_y(cx,cz,0)
        center = add_vertex(Vector((cx,y+depth_ordinary,cz)), Vector((cx,y+depth_revealed,cz)), feature)
        for j in range(len(previous_ring)):
            face_index = add_face((center,previous_ring[j],previous_ring[(j+1)%len(previous_ring)]), bottom_material)
            if bottom_material == 4:
                socket_faces.append(face_index)
        reports.append({'feature':feature, 'removed_skin_faces':len(removed[feature]),
                        'shared_boundary_vertices':len(boundary),
                        'ordinary_depth_m':depth_ordinary,'revealed_depth_m':depth_revealed})

    # Remove unused source vertices; all remaining parts must share one graph.
    for face,coordinates in zip(faces,face_uvs):
        for index,vertex in enumerate(face):
            if vertex in moved_boundaries:coordinates[index]=uv_for(vertices[vertex])
    # Choose explicit diagonals in the front skin chart. Blender/glTF can
    # triangulate a curved concave quad along the wrong diagonal, producing a
    # flipped sliver even though its edge connectivity is correct.
    original_sockets=set(socket_faces)
    split_faces=[];split_uvs=[];split_materials=[];socket_faces=[]
    def triangle_area(points,triangle):
        a,b,c=(points[i] for i in triangle)
        return (b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
    for old_index,(face,coordinates,material) in enumerate(zip(faces,face_uvs,materials)):
        center=sum((vertices[i] for i in face),Vector())/len(face)
        choices=[tuple(range(len(face)))]
        if len(face)==4 and center.y<-.075 and material<3:
            candidates=[[(0,1,2),(0,2,3)],[(0,1,3),(1,2,3)]]
            scores=[]
            for candidate in candidates:
                areas=[]
                for strength in [0,.3,.65,1]:
                    points=[vertices[i]+(smile_positions[i]-vertices[i])*strength
                            +(eye_positions[i]-vertices[i])*strength for i in face]
                    areas.extend(triangle_area(points,tri) for tri in candidate)
                scores.append(min(areas))
            selected=max(range(2),key=lambda i:scores[i])
            assert scores[selected]>=-1e-10, 'Skin quad folds during facial deformation'
            choices=candidates[selected]
        for indices in choices:
            if old_index in original_sockets:socket_faces.append(len(split_faces))
            split_faces.append(tuple(face[i] for i in indices))
            split_uvs.append([coordinates[i] for i in indices])
            split_materials.append(material)
    faces,face_uvs,materials=split_faces,split_uvs,split_materials
    used = sorted(set(i for face in faces for i in face))
    compact = {old:new for new,old in enumerate(used)}
    faces = [tuple(compact[i] for i in face) for face in faces]
    data = bpy.data.meshes.new('Mother integrated facial topology')
    data.from_pydata([head_inverse @ vertices[i] for i in used],[],faces)
    data.update()
    old_material = source.materials[0]
    eye_material = old_material.copy(); eye_material.name = 'Natural inset eye detail'
    for material in [old_material,skin,lip,dark,eye_material,dark]:
        data.materials.append(material)
    uvs = data.uv_layers.new(name='IntegratedFaceUV')
    for polygon, coordinates, material in zip(data.polygons,face_uvs,materials):
        polygon.material_index=material; polygon.use_smooth=True
        for li, coordinate in zip(polygon.loop_indices,coordinates):
            uvs.data[li].uv=coordinate
    head.data=data
    group=head.vertex_groups.get('Head_021') or head.vertex_groups.new(name='Head_021')
    group.add(list(range(len(used))),1,'REPLACE')
    head.shape_key_add(name='Basis')
    smile_key=head.shape_key_add(name='UncannySmile')
    eye_key=head.shape_key_add(name='HollowEyeSockets')
    for new,old in enumerate(used):
        smile_key.data[new].co=head_inverse@smile_positions[old]
        eye_key.data[new].co=head_inverse@eye_positions[old]

    # Structural audit: manifold skin and cavities, joined into one mesh.
    edge_counts=defaultdict(int); graph=defaultdict(set)
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            edge_counts[tuple(sorted((a,b)))]+=1
            graph[a].add(b);graph[b].add(a)
    assert all(count==2 for count in edge_counts.values()), 'Head has open or non-manifold edges'
    visited=set();pending=[0]
    while pending:
        vertex=pending.pop()
        if vertex in visited:continue
        visited.add(vertex);pending.extend(graph[vertex]-visited)
    assert len(visited)==len(used), 'Detached facial mesh component'
    probes=[]
    for strength in [0, .3, .65, 1]:
        posed=[vertices[i]+(smile_positions[i]-vertices[i])*strength
               +(eye_positions[i]-vertices[i])*strength for i in used]
        surface=BVHTree.FromPolygons(posed,faces)
        depths={}
        for feature,cx,cz,rx,rz in features:
            hit=surface.ray_cast(Vector((cx,-.45,cz)),Vector((0,1,0)),.5)[0]
            assert hit is not None, 'Missing cavity surface: '+feature
            depths[feature]=round(hit.y-front_y(cx,cz,0),6)
        assert depths['mouth']>.02, 'Intact skin still blocks the mouth opening'
        if strength>=.65:
            assert min(depths['left_socket'],depths['right_socket'])>.014, 'Sockets are not recessed'
        folded=0
        for face,material in zip(faces,materials):
            points=[posed[i] for i in face]
            center=sum(points,Vector())/len(points)
            if material<3 and center.y<-.09:
                for j in range(1,len(points)-1):
                    if (points[j]-points[0]).cross(points[j+1]-points[0]).y>1e-9:folded+=1
        assert folded==0, 'Folded front skin triangles'
        probes.append({'strength':strength,'ray_depths_m':depths,'folded_skin_triangles':folded})
    audit={'connected_components':1,'non_manifold_edges':0,'vertices':len(used),
           'faces':len(faces),'features':reports,'cavity_probes':probes,'socket_face_indices':socket_faces}
    head['integrated_face']=True
    head['face_audit']=str(audit)
    print('INTEGRATED_FACE_AUDIT',audit,flush=True)
    return smile_key,eye_key,socket_faces,audit
