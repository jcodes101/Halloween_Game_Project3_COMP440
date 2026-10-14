extends Node3D
## Approved Kenney modular house, furnished rooms and evening street.
var doors: Dictionary = {}
var hide_spots: Array[Dictionary] = []
var room_points: Dictionary = {}
var boards: Node3D
var ladder: Node3D
var window_barrier: StaticBody3D
var window_glass: MeshInstance3D
var crowbar: Node3D
var key: Node3D
var window_sign: Label3D
var asset_instances := 0
var _scenes: Dictionary = {}

func build() -> void:
	_lighting()
	_floors()
	_shell()
	_rooms()
	_stair(Vector3(4.5, 0, 10), Vector3(4.5, 3.6, 3), 2.4)
	_stair(Vector3(-7, -3.6, -6.4), Vector3(-7, 0, 1.4), 2.4)
	_furnish()
	_attic()
	_neighborhood()

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	return result

func box(at: Vector3, size: Vector3, color: Color, solid: bool = true, visible_mesh: bool = true) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	if visible_mesh:
		var instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		instance.mesh = mesh
		instance.material_override = _material(color)
		node.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func _bounds(node: Node3D, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform * node.transform
	var bounds := AABB()
	if node is MeshInstance3D:
		bounds = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var next := _bounds(child, transform)
			if next.size.length_squared() > 0:
				bounds = next if bounds.size.length_squared() == 0 else bounds.merge(next)
	return bounds

func model(kit: String, asset: String, at: Vector3, size: Vector3, yaw: float = 0) -> Node3D:
	var path := "res://assets/environment/%s/%s.glb" % [kit, asset]
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var instance: Node3D = _scenes[path].instantiate()
	# Building Kit walls span Z; normalize them to the X-wide convention used by
	# the floor plan before fitting. This preserves openings rather than stretching
	# wall thickness into the intended width.
	if kit=="building" and (asset.begins_with("wall") or asset.begins_with("door-rotate") or asset=="border"):
		instance.basis = Basis(Vector3.UP,PI/2)*instance.basis
	if asset=="barricade-doorway-a":
		instance.basis = Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,PI/2)*instance.basis
	if asset=="detail-pipe" and size.x>size.y:
		instance.basis = Basis(Vector3.FORWARD,PI/2)*instance.basis
	var bounds := _bounds(instance)
	assert(bounds.size.length_squared() > 0, "Missing model geometry: " + asset)
	var pivot := Node3D.new()
	pivot.name = asset
	add_child(pivot)
	pivot.add_child(instance)
	instance.position -= bounds.position + Vector3(bounds.size.x * 0.5, 0, bounds.size.z * 0.5)
	if kit=="building" and asset.begins_with("wall"):
		for mesh in instance.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.mesh.surface_get_material(surface)
				if original != null and original.resource_name.to_lower().contains("glass"):
					var glass := _material(Color(0.16,0.23,0.28,0.16))
					glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					glass.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh.set_surface_override_material(surface,glass)
				else:
					mesh.set_surface_override_material(surface,_material(Color("d7c9a8")))
	if asset=="border":
		for mesh in instance.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = _material(Color("6c5440"))
	if asset=="roof-flat-center":
		for mesh in instance.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = _material(Color("503b39"))
	pivot.scale = size / Vector3(maxf(bounds.size.x, 0.01), maxf(bounds.size.y, 0.01), maxf(bounds.size.z, 0.01))
	pivot.position = at
	pivot.rotation.y = yaw
	asset_instances += 1
	return pivot

func _floor_rect(x1: float, x2: float, z1: float, z2: float, level: float, color: Color) -> void:
	box(Vector3((x1+x2)/2, level-0.15, (z1+z2)/2), Vector3(x2-x1, 0.3, z2-z1), color)
	# Tile the original kit floor on top of each collision slab.
	var nx := maxi(1, ceili((x2-x1)/3.5))
	var nz := maxi(1, ceili((z2-z1)/3.5))
	for i in nx:
		for j in nz:
			var width := (x2-x1)/nx
			var depth := (z2-z1)/nz
			var tile := model("building", "floor", Vector3(x1+width*(i+0.5), level, z1+depth*(j+0.5)), Vector3(width, 0.025, depth))
			for mesh in tile.find_children("*", "MeshInstance3D", true, false):
				mesh.material_override = _material(color)

func _floor_with_hole(level: float, hole: Rect2, color: Color) -> void:
	_floor_rect(-11, hole.position.x, -12, 12, level, color)
	_floor_rect(hole.end.x, 11, -12, 12, level, color)
	_floor_rect(hole.position.x, hole.end.x, -12, hole.position.y, level, color)
	_floor_rect(hole.position.x, hole.end.x, hole.end.y, 12, level, color)

func _floors() -> void:
	_floor_rect(-11, 11, -12, 14.5, -3.6, Color("4b4840"))
	_floor_with_hole(0, Rect2(-8.4, -6.4, 2.8, 7.8), Color("70543c"))
	_floor_with_hole(3.6, Rect2(3.1, 2.7, 2.8, 7.6), Color("665039"))
	_floor_with_hole(7.2, Rect2(-1, -4, 2, 2), Color("59432f"))
	# Outdoor ground excludes the house footprint so it cannot seal the basement.
	box(Vector3(-43,-0.32,0),Vector3(64,0.25,150),Color("354936"))
	box(Vector3(43,-0.32,0),Vector3(64,0.25,150),Color("354936"))
	box(Vector3(0,-0.32,-43.5),Vector3(22,0.25,63),Color("354936"))
	box(Vector3(0,-0.32,44.75),Vector3(22,0.25,60.5),Color("354936"))

func _wall_segment(at: Vector3, length: float, level: float, yaw: float = 0, height: float = 3.6) -> void:
	var count := maxi(1, ceili(length/3.0))
	for i in count:
		var offset := Vector3(length*(float(i)+0.5)/count-length/2, 0, 0).rotated(Vector3.UP, yaw)
		model("building", "wall", at + offset + Vector3.UP*level, Vector3(length/count, height, 0.22), yaw)
	var size := Vector3(length, height, 0.22) if absf(sin(yaw)) < 0.5 else Vector3(0.22, height, length)
	box(at + Vector3.UP*(level+height/2), size, Color.WHITE, true, false)

func wall_between(a: Vector2, b: Vector2, level: float, gap: float = -1, door_id: String = "", closed: bool = false) -> void:
	var length := a.distance_to(b)
	var axis := (b-a).normalized()
	var yaw := -atan2(axis.y, axis.x)
	if gap < 0:
		_wall_segment(Vector3((a.x+b.x)/2,0,(a.y+b.y)/2), length, level, yaw)
		return
	var left := gap-1.5
	var right := length-gap-1.5
	if left > 0.1:
		var p := a+axis*left/2
		_wall_segment(Vector3(p.x,0,p.y), left, level, yaw)
	if right > 0.1:
		var p := b-axis*right/2
		_wall_segment(Vector3(p.x,0,p.y), right, level, yaw)
	var p := a+axis*gap
	var at := Vector3(p.x,level,p.y)
	_door_frame(at,yaw)
	if not door_id.is_empty():
		_door(door_id, at, yaw, closed)

func _door_frame(at: Vector3, yaw: float) -> void:
	model("building","wall-doorway-square",at,Vector3(3.0,2.75,0.22),yaw)
	model("building","wall",at+Vector3.UP*2.75,Vector3(3.0,0.85,0.22),yaw)
	box(at+Vector3.UP*3.0,Vector3(3,1.2,0.22) if absf(sin(yaw))<0.5 else Vector3(0.22,1.2,3),Color.WHITE,true,false)
	for side in [-1,1]:
		var offset := Vector3(side*1.1125,1.2,0).rotated(Vector3.UP,yaw)
		box(at+offset,Vector3(0.775,2.4,0.22) if absf(sin(yaw))<0.5 else Vector3(0.22,2.4,0.775),Color.WHITE,true,false)

func _door(id: String, at: Vector3, yaw: float, closed: bool) -> void:
	var leaf := model("building", "door-rotate-square-a", at, Vector3(1.4,2.35,0.1), yaw)
	var hinge := Node3D.new()
	add_child(hinge)
	hinge.position = at+Vector3(-0.7,0,0).rotated(Vector3.UP,yaw)
	hinge.rotation.y = yaw
	leaf.reparent(hinge,true)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.45,2.35,0.12)
	shape.shape = box_shape
	shape.position.y = 1.175
	body.add_child(shape)
	add_child(body)
	body.position = at
	body.rotation.y = yaw
	body.collision_layer = 8 if closed else 0
	hinge.rotation.y = yaw if closed else yaw+PI/2
	doors[id] = {"position":at+Vector3.UP, "leaf":leaf, "hinge":hinge, "body":body, "open":not closed, "yaw":yaw}

func set_door(id: String, opened: bool) -> void:
	doors[id].open = opened
	create_tween().tween_property(doors[id].hinge,"rotation:y",doors[id].yaw+(PI/2 if opened else 0),0.3)
	doors[id].body.collision_layer = 0 if opened else 8
	if doors[id].has("link"):
		doors[id].link.enabled = opened

func _window(at: Vector3, level: float, yaw: float = 0, width: float = 3.0) -> void:
	model("building", "wall-window-square", at+Vector3.UP*level, Vector3(width,3.6,0.22), yaw)
	box(at+Vector3.UP*(level+1.8), Vector3(width,3.6,0.16) if absf(sin(yaw))<0.5 else Vector3(0.16,3.6,width), Color.WHITE,true,false)

func _side_windows(x: float, level: float) -> void:
	var previous := -12.0
	for z in [-9.0,-3.0,5.0,9.0]:
		var start: float = z-1.5
		if start>previous:
			_wall_segment(Vector3(x,0,(start+previous)/2),start-previous,level,PI/2)
		_window(Vector3(x,0,z),level,PI/2)
		previous = z+1.5
	_wall_segment(Vector3(x,0,(previous+12)/2),12-previous,level,PI/2)

func _front_windows(level: float) -> void:
	for interval in [[-11.0,-8.5],[-5.5,-1.5],[1.5,5.5],[8.5,11.0]]:
		_wall_segment(Vector3((interval[0]+interval[1])/2,0,12),interval[1]-interval[0],level)
	for x in [-7.0,7.0]:
		_window(Vector3(x,0,12),level)
	if level==0:
		_door_frame(Vector3(0,0,12),0)
		_door("front_door",Vector3(0,0,12),0,true)
	else:
		_window(Vector3(0,0,12),level,0,3.0)

func _shell() -> void:
	for level in [-3.6,0.0,3.6]:
		if level>=0:
			_side_windows(-11,level)
			_side_windows(11,level)
		else:
			_wall_segment(Vector3(-11,0,0),24,level,PI/2)
			_wall_segment(Vector3(11,0,0),24,level,PI/2)
		_wall_segment(Vector3(0,0,-12),22,level)
		if level == -3.6:
			wall_between(Vector2(-11,12),Vector2(2.2,12),level,11,"false_exit",true)
			_wall_segment(Vector3(7.6,0,12),6.8,level)
			_wall_segment(Vector3(0,0,14.5),22,level)
		else:
			_front_windows(level)
	# Porch, supporting columns, and trim assembled from the building kit.
	box(Vector3(0,0.05,14),Vector3(7,0.1,4),Color("76644f"))
	for x in [-3.2,3.2]:
		model("building","column",Vector3(x,0,13.8),Vector3(0.3,3.4,0.3))
	model("building","roof-flat-center",Vector3(0,3.3,13),Vector3(7.2,0.25,2.2))
	box(Vector3(0,3.425,13),Vector3(7.2,0.25,2.2),Color.WHITE,true,false)
	for side in [-1,1]:
		var roof := model("building","roof-flat-center",Vector3(side*5.6,11.0,0),Vector3(11.7,0.24,25))
		roof.rotation.z = -side*deg_to_rad(18)
		var roof_collision := box(roof.position+Vector3(0,0.12,0).rotated(Vector3.BACK,roof.rotation.z),Vector3(11.7,0.24,25),Color.WHITE,true,false)
		roof_collision.rotation.z = roof.rotation.z
	_wall_segment(Vector3(-11,0,0),24,7.2,PI/2,2.0)
	_wall_segment(Vector3(11,0,0),24,7.2,PI/2,2.0)
	_wall_segment(Vector3(0,0,-12),22,7.2,0,2.0)
	_wall_segment(Vector3(-6.5,0,12),9,7.2,0,2.0)
	_wall_segment(Vector3(6.5,0,12),9,7.2,0,2.0)
	_gable(-12,false)
	_gable(12,true)
	# This opening is the real escape window; its sill requires a jump.
	# Assemble the escape casement from kit infill and trim to match the jump
	# aperture exactly. Ordinary facade windows retain their original kit meshes.
	model("building","wall",Vector3(0,7.2,12),Vector3(4,0.7,0.22))
	model("building","wall",Vector3(0,10.6,12),Vector3(4,0.4,0.22))
	for x in [-1.7,1.7]:
		model("building","wall",Vector3(x,7.9,12),Vector3(0.6,2.7,0.22))
	for y in [7.9,10.55]:
		model("building","border",Vector3(0,y,12.03),Vector3(2.9,0.1,0.3))
	for x in [-1.45,1.45]:
		model("building","column",Vector3(x,7.9,12.03),Vector3(0.1,2.7,0.3))
	box(Vector3(0,7.55,12),Vector3(4,0.7,0.22),Color.WHITE,true,false)
	box(Vector3(0,10.85,12),Vector3(4,0.3,0.22),Color.WHITE,true,false)
	for x in [-1.7,1.7]:
		box(Vector3(x,9,12),Vector3(0.6,2.3,0.22),Color.WHITE,true,false)
	window_glass = MeshInstance3D.new()
	var glass := BoxMesh.new()
	glass.size = Vector3(2.8,2.7,0.06)
	window_glass.mesh = glass
	var material := _material(Color(0.15,0.23,0.3,0.28))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_glass.material_override = material
	window_glass.position = Vector3(0,9.25,12)
	add_child(window_glass)
	window_barrier = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var pane := BoxShape3D.new()
	pane.size = glass.size
	shape.shape = pane
	window_barrier.add_child(shape)
	window_barrier.position = window_glass.position
	window_barrier.collision_layer = 8
	add_child(window_barrier)

func _rooms() -> void:
	for level in [0.0,3.6]:
		for side in [-1.2,1.2]:
			var spans: Array = [[-12.0,-7.0],[-7.0,3.0],[3.0,7.0]] if level==0 and side<0 else [[-12.0,-7.0],[-7.0,0.0],[0.0,7.0]]
			for span in spans:
				var id := "mother_room" if level==3.6 and side>0 and span[0]==-7 else ""
				wall_between(Vector2(side,span[0]),Vector2(side,span[1]),level,(span[1]-span[0])/2,id,not id.is_empty())
		for x in [-11.0,1.2]:
			for z in [-7.0,0.0]:
				var line_z: float = 3.0 if level==0 and x<0 and z==0 else z
				wall_between(Vector2(x,line_z),Vector2(x+9.8,line_z),level)
	# Ground-floor front bedroom/study wall has a doorway; foyer remains connected.
	wall_between(Vector2(-11,7),Vector2(-1.2,7),0,6)
	wall_between(Vector2(-11,7),Vector2(-1.2,7),3.6,6)
	wall_between(Vector2(1.2,7),Vector2(3.0,7),3.6)
	# Basement shelves/partitions create dead ends but leave the central route open.
	wall_between(Vector2(-11,-8),Vector2(-1.2,-8),-3.6,4)
	wall_between(Vector2(1.2,-2),Vector2(11,-2),-3.6,4)
	room_points = {"Kitchen":Vector3(-4,0.05,-4.9),"Dining":Vector3(3,0.05,-3),"Bookshelf":Vector3(-3.5,0.05,4.1),"Pantry":Vector3(6.2,0.05,-9)}
	for entry in [["LIVING ROOM",Vector3(-1.04,2.5,5),PI/2],["KITCHEN / BASEMENT",Vector3(-1.04,2.5,-2),PI/2],["DINING ROOM",Vector3(1.04,2.5,-3.5),-PI/2],["MOTHER'S ROOM",Vector3(1.04,6.1,-3.5),-PI/2],["YOUR ROOM",Vector3(-1.04,6.1,-3.5),PI/2],["FALSE EXIT",Vector3(0,-1.0,11.82),PI]]:
		_label(entry[0],entry[1],entry[2])

func _stair(bottom: Vector3, top: Vector3, width: float) -> void:
	var length := absf(top.z-bottom.z)
	var height := top.y-bottom.y
	model("building","stairs-closed",Vector3(bottom.x,bottom.y,(bottom.z+top.z)/2),Vector3(width,height,length),PI if top.z>bottom.z else 0)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	var z_dir := -1.0 if top.z < bottom.z else 1.0
	for x in [-width/2,width/2]:
		points.append(Vector3(bottom.x+x,bottom.y-0.2,bottom.z-z_dir*0.35))
		points.append(Vector3(bottom.x+x,bottom.y,bottom.z-z_dir*0.35))
		points.append(Vector3(top.x+x,bottom.y-0.2,top.z+z_dir*0.35))
		points.append(Vector3(top.x+x,top.y,top.z+z_dir*0.35))
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	for x in [bottom.x-width/2,bottom.x+width/2]:
		var rail := model("building","border",Vector3(x,bottom.y+0.95,(bottom.z+top.z)/2),Vector3(0.08,0.1,sqrt(length*length+height*height)))
		rail.rotation.x = atan2(height,top.z-bottom.z)

func _prop(asset: String, at: Vector3, size: Vector3, yaw: float = 0, solid: bool = true) -> Node3D:
	var item := model("furniture",asset,at,size,yaw)
	if solid:
		var dimensions := Vector3(size.z,size.y,size.x) if absf(sin(yaw))>0.5 else size
		box(at+Vector3.UP*size.y/2,dimensions,Color.WHITE,true,false)
	return item

func _lamp(at: Vector3, energy: float = 0.75, color: Color = Color("ffd49e")) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 8
	add_child(light)

func _bed(asset: String, center: Vector3, width: float) -> void:
	model("furniture",asset,center+Vector3.UP*0.8,Vector3(width,0.65,3.5))
	box(center+Vector3.UP*1.125,Vector3(width,0.65,3.5),Color.WHITE,true,false)
	for x in [-width/2+0.15,width/2-0.15]:
		for z in [-1.5,1.5]:
			model("building","column",center+Vector3(x,0,z),Vector3(0.12,0.8,0.12))
	var entry := center+Vector3(0,0,2.4)
	hide_spots.append({"title":"Hide under bed", "kind":"hide", "position":entry+Vector3.UP,"prompt":"E — hide under bed","hide_config":{"entry":entry,"path":[center],"exit_yaw":0.0,"hidden_yaw":0.0,"crouch_height":0.72,"crouch_camera_y":0.53}})

func _furnish() -> void:
	_prop("loungeSofa",Vector3(-7,0,5),Vector3(3.5,1.4,1.5))
	_prop("loungeChair",Vector3(-3.3,0,5.5),Vector3(1.2,1.2,1.2),PI/2)
	_prop("tableCoffee",Vector3(-6.7,0,6.2),Vector3(1.8,0.55,1.0))
	_prop("cabinetTelevision",Vector3(-9.2,0,6.5),Vector3(2.5,0.7,0.45))
	_prop("televisionVintage",Vector3(-9.2,0.7,6.5),Vector3(1.5,1.1,0.5))
	_prop("rugRectangle",Vector3(-7,0.035,5.2),Vector3(5,0.03,3),0,false)
	_prop("bookcaseOpen",Vector3(-2,0,3.5),Vector3(1.3,2.5,0.45))
	hide_spots.append({"title":"Hide behind sofa","kind":"hide","position":Vector3(-4.5,1,5),"prompt":"E — hide behind sofa","hide_config":{"entry":Vector3(-4.5,0,5),"path":[Vector3(-4.5,0,3.75),Vector3(-7,0,3.75)],"crouch_height":0.95,"crouch_camera_y":0.78}})
	for z in [-5.5,-3.8,-2.1]:
		_prop("kitchenCabinet",Vector3(-10,0,z),Vector3(1.6,1,1.2),PI/2)
		_prop("kitchenCabinetUpper",Vector3(-10,1.9,z),Vector3(1.6,0.85,1.2),PI/2)
	_prop("kitchenStove",Vector3(-4,0,-6),Vector3(1.2,1.0,0.8))
	_prop("hoodLarge",Vector3(-4,2.0,-6),Vector3(1.3,0.6,0.8),0,false)
	_prop("kitchenSink",Vector3(-10,1,-3.8),Vector3(1.3,0.2,1.0),PI/2,false)
	_prop("kitchenFridge",Vector3(-2.4,0,-6),Vector3(1.3,2.2,1.0))
	_prop("table",Vector3(6,0,-3),Vector3(3,0.9,2))
	for x in [4.0,8.0]:
		for z in [-2.2,-3.8]:
			_prop("chair",Vector3(x,0,z),Vector3(0.65,1.1,0.65),PI/2)
	_prop("bookcaseOpen",Vector3(8.5,0,-9),Vector3(3,2.7,0.6))
	_prop("cardboardBoxClosed",Vector3(5,0,-10),Vector3(1,1,1))
	for level in [0.0,3.6]:
		_prop("bathtub",Vector3(-8,level,-10.5),Vector3(2.8,0.75,1.3))
		_prop("toilet",Vector3(-3,level,-10),Vector3(0.8,1.0,1.1))
		_prop("bathroomSink",Vector3(-6,level,-8),Vector3(1.3,1.0,0.7))
		_prop("bathroomMirror",Vector3(-6,level+1.5,-7.8),Vector3(1.1,1,0.05),0,false)
	_bed("bedDouble",Vector3(6,3.6,-4.4),3.2)
	_bed("bedSingle",Vector3(-6,3.6,-4.4),2.2)
	for x in [-8.5,8.5]:
		_prop("cabinetBed",Vector3(x,3.6,-5.5),Vector3(1.0,0.7,0.7))
		_prop("lampRoundTable",Vector3(x,4.3,-5.5),Vector3(0.45,0.7,0.45),0,false)
		_lamp(Vector3(x,5.3,-5.5))
	_prop("cabinetBed",Vector3(3.5,3.6,-5.5),Vector3(1.0,0.7,0.7))
	_prop("desk",Vector3(8,3.6,-9.5),Vector3(2.8,0.9,1.1))
	_prop("chairDesk",Vector3(8,3.6,-8),Vector3(0.8,1.1,0.8))
	_prop("bookcaseOpen",Vector3(3,3.6,-10.5),Vector3(1.5,2.6,0.6))
	_prop("desk",Vector3(-7,3.6,3),Vector3(2.5,0.9,1.0))
	_prop("bookcaseOpen",Vector3(-9,3.6,5),Vector3(2,2.5,0.5))
	# Closet enclosure: open center with doors and a real concealed interior.
	wall_between(Vector2(7.5,4),Vector2(10.5,4),3.6,1.5,"closet",true)
	wall_between(Vector2(7.5,4),Vector2(7.5,6.5),3.6)
	wall_between(Vector2(10.5,4),Vector2(10.5,6.5),3.6)
	wall_between(Vector2(7.5,6.5),Vector2(10.5,6.5),3.6)
	hide_spots.append({"title":"Hide in closet","kind":"hide","position":Vector3(9,4.6,3.1),"prompt":"E — hide in closet","hide_config":{"entry":Vector3(9,3.6,3.1),"path":[Vector3(9,3.6,5.5)],"crouch_height":0.95,"crouch_camera_y":0.78,"closet":true}})
	for x in [-8.5,-5.5,5.5,8.5]:
		for z in [2.0,5.0,8.0]:
			_prop("cardboardBoxClosed",Vector3(x,-3.6,z),Vector3(1.2,1.0,1.0))
	# Stacked storage boxes create a reachable hiding alcove in the basement.
	for p in [Vector3(-8.5,-2.6,5.0),Vector3(-8.5,-2.6,8.0),Vector3(-5.5,-2.6,8.0),Vector3(-5.5,-2.6,5.0),Vector3(-9.5,-3.6,6.5),Vector3(-9.5,-2.6,6.5)]:
		_prop("cardboardBoxClosed",p,Vector3(1.1,0.95,1.1))
	hide_spots.append({"title":"Hide behind storage boxes","kind":"hide","position":Vector3(-4.2,-2.6,6.5),"prompt":"E — hide behind storage boxes","hide_config":{"entry":Vector3(-4.2,-3.6,6.5),"path":[Vector3(-7.2,-3.6,6.5)],"crouch_height":0.95,"crouch_camera_y":0.78}})
	_prop("washer",Vector3(8,-3.6,-8),Vector3(1.1,1.2,1.0))
	_prop("dryer",Vector3(9.5,-3.6,-8),Vector3(1.1,1.2,1.0))
	_prop("table",Vector3(5,-3.6,-8),Vector3(3,0.9,1.0))
	for x in [-4.0,4.0]:
		for z in [-9.0,0.0,9.0]:
			model("building","column",Vector3(x,-3.6,z),Vector3(0.3,3.6,0.3))
	crowbar = Node3D.new()
	add_child(crowbar)
	crowbar.position = Vector3(5,-2.55,-8)
	var bar := model("building","detail-pipe",crowbar.position,Vector3(0.75,0.08,0.08))
	var hook := model("building","detail-pipe",crowbar.position+Vector3(0.33,0.06,0),Vector3(0.08,0.22,0.08))
	for piece in [bar,hook]:
		piece.reparent(crowbar,true)
		for mesh in piece.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = _material(Color("8a9297"))
	key = Node3D.new()
	add_child(key)
	key.position = Vector3(3.5,4.325,-5.5)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.13
	ring.mesh = torus
	ring.material_override = _material(Color("c9a854"))
	key.add_child(ring)
	var stem := box(key.position+Vector3(0.18,0,0),Vector3(0.32,0.045,0.045),Color("c9a854"),false)
	stem.reparent(key,true)
	# Warm household lamps and cool, dim basement lamps.
	for p in [Vector3(-6,2.8,3),Vector3(-5,2.8,-3),Vector3(6,2.8,-3),Vector3(0,2.8,9),Vector3(-6,6.3,-3),Vector3(6,6.3,-3),Vector3(0,6.3,2),Vector3(0,9.8,3)]:
		_lamp(p,0.8,Color("ffd49e"))
	_lamp(Vector3(-6,-0.8,5),0.55,Color("b2c4d4"))
	_lamp(Vector3(5,-0.8,-7),0.65,Color("c0cbd4"))
	for p in [Vector3(-9,0,6),Vector3(9,0,9),Vector3(-9,3.6,9)]:
		_prop("pottedPlant",p,Vector3(0.8,1.6,0.8))
	_prop("coatRackStanding",Vector3(-9,0,10),Vector3(0.8,2,0.8))
	# Ceiling fans in living room and dining room.
	_prop("ceilingFan",Vector3(-6,3.3,5),Vector3(1.8,0.35,1.8),0,false)
	_prop("ceilingFan",Vector3(6,3.3,-3),Vector3(1.8,0.35,1.8),0,false)
	# Floor lamp in living room.
	_prop("lampRoundFloor",Vector3(-10,0,3.5),Vector3(0.6,2.0,0.6))
	# Side tables next to seating and beds.
	_prop("sideTable",Vector3(-1.8,0,5.5),Vector3(0.8,0.7,0.8))
	_prop("sideTable",Vector3(-4.0,3.6,-5.5),Vector3(0.8,0.7,0.8))
	# Books on shelves and desks.
	_prop("books",Vector3(-2,0.8,3.5),Vector3(0.9,0.45,0.35),0,false)
	_prop("books",Vector3(8.5,0.9,-9),Vector3(1.2,0.45,0.4),0,false)
	_prop("books",Vector3(3,4.4,-10.5),Vector3(1.1,0.45,0.4),0,false)
	_prop("books",Vector3(-9,4.4,5),Vector3(1.1,0.45,0.35),0,false)
	_prop("books",Vector3(8,4.5,-9.5),Vector3(0.8,0.35,0.4),PI/2,false)

func _attic() -> void:
	boards = model("building","barricade-doorway-a",Vector3(0,7.03,-3),Vector3(1.9,0.12,1.9))
	box(Vector3(0,7.06,-3),Vector3(2,0.12,2),Color.WHITE,true,false).name = "HatchBlocker"
	# The cord lets a small player reach the ceiling access with E.
	model("building","column",Vector3(0,4.9,-3),Vector3(0.025,2.2,0.025))
	ladder = Node3D.new()
	add_child(ladder)
	ladder.position = Vector3(0,3.6,-1.65)
	ladder.rotation.x = deg_to_rad(-20)
	for x in [-0.48,0.48]:
		var rail := model("building","column",Vector3(x,0,0),Vector3(0.08,3.83,0.08))
		remove_child(rail)
		ladder.add_child(rail)
	for i in 11:
		var rung := model("building","border",Vector3(0,0.28+i*0.32,0),Vector3(1.0,0.07,0.1))
		remove_child(rung)
		ladder.add_child(rung)
	ladder.visible = false
	for x in [-8.0,8.0]:
		for z in [-8.0,-2.0,6.0]:
			_prop("cardboardBoxClosed",Vector3(x,7.2,z),Vector3(1.6,1.1,1.3))
	for z in [-8.0,-2.0,4.0,10.0]:
		for side in [-1,1]:
			var beam := model("building","border",Vector3(side*5.5,10.85,z),Vector3(11.6,0.14,0.18))
			beam.rotation.z = -side*deg_to_rad(18)
			for mesh in beam.find_children("*","MeshInstance3D",true,false):
				mesh.material_override = _material(Color("503b2b"))
	window_sign = _label("ATTIC WINDOW — LOCKED",Vector3(0,10.9,11.8))

func _lighting() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("172538")
	sky_material.sky_horizon_color = Color("cb8871")
	sky_material.ground_horizon_color = Color("ac7764")
	sky_material.ground_bottom_color = Color("263829")
	sky.sky_material = sky_material
	world.environment.sky = sky
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("77869a")
	world.environment.ambient_light_energy = 0.35
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-9,-65,0)
	sun.light_color = Color("ffbf8b")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	add_child(sun)

func _neighbor(at: Vector3, yaw: float) -> void:
	var house := Node3D.new()
	add_child(house)
	house.position = at
	house.rotation.y = yaw
	for level in [0.0,3.1]:
		for i in 3:
			var front := model("building","wall-doorway-square" if level==0 and i==1 else "wall-window-square",Vector3((i-1)*3.0,level,4.5),Vector3(3,3.1,0.2))
			remove_child(front)
			house.add_child(front)
		for side in [-1,1]:
			var panel := model("building","wall",Vector3(side*4.5,level,0),Vector3(9,3.1,0.2),PI/2)
			remove_child(panel)
			house.add_child(panel)
		var back := model("building","wall",Vector3(0,level,-4.5),Vector3(9,3.1,0.2))
		remove_child(back)
		house.add_child(back)
	for side in [-1,1]:
		var roof := model("building","roof-flat-center",Vector3(side*2.3,7.2,0),Vector3(5,0.2,10))
		roof.rotation.z = -side*deg_to_rad(23)
		remove_child(roof)
		house.add_child(roof)
	# Ground silhouettes and collision prevent walking through neighboring homes.
	box(at+Vector3.UP*3,Vector3(9,6,9),Color.WHITE,true,false)
	var neighbor_door := model("building","door-rotate-square-a",Vector3(0,0,4.65),Vector3(1.5,2.3,0.1))
	remove_child(neighbor_door)
	house.add_child(neighbor_door)
	for z in [-4.5,4.5]:
		var gable := _triangle_mesh([Vector3(-4.6,6.2,z),Vector3(4.6,6.2,z),Vector3(0,8.2,z)])
		house.add_child(gable)
	for x in [-3.0,3.0]:
		var pane := box(Vector3(x,1.6,4.65),Vector3(1.5,1.3,0.03),Color("e9b679"),false)
		remove_child(pane)
		house.add_child(pane)

func _neighborhood() -> void:
	box(Vector3(0,-0.12,30),Vector3(145,0.08,8),Color("363b42"))
	for z in [24.5,35.5]:
		box(Vector3(0,-0.06,z),Vector3(145,0.12,2.5),Color("8a877b"))
	for x in range(-65,66,10):
		box(Vector3(x,-0.06,30),Vector3(4,0.025,0.12),Color("d7b77d"),false)
	box(Vector3(0,-0.04,19),Vector3(2.4,0.08,10),Color("8b887e"))
	for x in [-48.0,-30.0,30.0,48.0]:
		_neighbor(Vector3(x,0,13),0)
		_neighbor(Vector3(x,0,46),PI)
	for x in [-18.0,18.0]:
		_neighbor(Vector3(x,0,46),PI)
	for x in range(-60,61,15):
		for z in [20.0,40.0]:
			if absf(x)>6 or z>30:
				model("furniture","pottedPlant",Vector3(x,-2.8,z),Vector3(3.2,5.5,3.2))
			var post_z := 23.0 if z<30 else 37.0
			model("building","column",Vector3(x+4,0,post_z),Vector3(0.12,4.8,0.12))
			model("furniture","lampWall",Vector3(x+4,4.2,post_z),Vector3(0.35,0.6,0.35))
			_lamp(Vector3(x+4,4.5,post_z),0.65)
	for x in [-10.0,10.0]:
		for z in [15.0,18.0,21.0]:
			model("furniture","pottedPlant",Vector3(x,0,z),Vector3(2.0,1.6,2.0))

func _triangle_mesh(vertices: Array) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	var normals := PackedVector3Array()
	for vertex in vertices: normals.append(Vector3.FORWARD)
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := _material(Color("b9ad96"))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	return instance

func _gable(z: float, opening: bool) -> void:
	var vertices: Array = [Vector3(-11,9.2,z),Vector3(11,9.2,z),Vector3(0,12.8,z)]
	if opening:
		vertices = [Vector3(-11,9.2,z),Vector3(-2,9.2,z),Vector3(-2,12.1,z),Vector3(11,9.2,z),Vector3(2,12.1,z),Vector3(2,9.2,z),Vector3(-2,10.8,z),Vector3(2,10.8,z),Vector3(2,12.1,z),Vector3(-2,10.8,z),Vector3(2,12.1,z),Vector3(-2,12.1,z),Vector3(-2,12.1,z),Vector3(2,12.1,z),Vector3(0,12.8,z)]
	add_child(_triangle_mesh(vertices))

func _label(text: String, at: Vector3, yaw: float = PI) -> Label3D:
	var board := box(at,Vector3(maxf(1.0,text.length()*0.07),0.3,0.025),Color("3b3027"),false)
	board.rotation.y = yaw
	var label := Label3D.new()
	label.text = text
	label.position = at+Vector3(0,0,0.02).rotated(Vector3.UP,yaw)
	label.rotation.y = yaw
	label.font_size = 26
	label.pixel_size = 0.004
	add_child(label)
	return label
