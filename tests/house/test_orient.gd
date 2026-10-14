extends SceneTree

func _init() -> void:
	var s: Node3D = load("res://assets/environment/building/stairs-closed.glb").instantiate()
	root.add_child(s)
	s.position = Vector3(4.5, 0, 6.5)
	s.rotation.y = 0
	
	# Find mesh
	var mi: MeshInstance3D = s.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh: Mesh = mi.mesh
	var data := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	
	print("--- WITH ROTATION Y = 0 ---")
	var min_z_verts := []
	var max_z_verts := []
	for v in verts:
		var g: Vector3 = s.to_global(mi.to_global(v))
		if g.z > 7.5: max_z_verts.append(g)
		if g.z < 5.5: min_z_verts.append(g)
	
	var max_z_y := []
	for v in max_z_verts: max_z_y.append(v.y)
	var min_z_y := []
	for v in min_z_verts: min_z_y.append(v.y)
	
	print("Near z=8.5 (foyer side, z=10): y min=", min_z_y.min() if not max_z_y.is_empty() else 0, " y max=", max_z_y.max() if not max_z_y.is_empty() else 0)
	print("Near z=4.5 (upstairs side, z=3): y min=", min_z_y.min() if not min_z_y.is_empty() else 0, " y max=", min_z_y.max() if not min_z_y.is_empty() else 0)

	quit(0)

