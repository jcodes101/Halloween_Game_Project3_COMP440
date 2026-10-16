extends SubViewportContainer
## Live, non-interactive view of the existing house for the front-end.
## It builds only the environment geometry: no player, Familiar, timers or objectives.

const HOUSE_BUILDER := preload("res://game/house/house_builder.gd")

var _viewport: SubViewport
var _camera: Camera3D
var _elapsed := 0.0
var _active := true

func _ready() -> void:
	name = "MenuHouseBackdrop"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = false
	resized.connect(_resize_render_target)
	_viewport = SubViewport.new()
	_viewport.name = "HouseRender"
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_child(_viewport)
	var builder := HOUSE_BUILDER.new() as Node3D
	builder.name = "MenuHouse"
	_viewport.add_child(builder)
	# Build the actual front shell and porch from the game builder. The menu view
	# deliberately omits the four-floor interior, navigation, pickups and actors.
	builder.call("_lighting")
	builder.call("_shell")
	var world := builder.get_child(0) as WorldEnvironment
	if world != null:
		world.environment.ambient_light_color = Color("596572")
		world.environment.ambient_light_energy = 0.08
	var sun := builder.get_child(1) as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = false
		sun.light_energy = 0.06
	var lawn := builder.call("box", Vector3(0.0, -0.23, 20.0), Vector3(46.0, 0.35, 47.0), Color("252a2a"), true, true) as Node3D
	lawn.name = "MenuYard"
	var drive := builder.call("box", Vector3(0.0, -0.035, 30.0), Vector3(44.0, 0.06, 7.0), Color("292b30"), false, true) as Node3D
	drive.name = "WetDrive"
	_add_window_glows(builder)
	_add_porch_practicals(builder)
	_add_moon(builder)
	_add_tree_silhouette(builder, Vector3(-14.5, 0.0, 16.5), 1.08)
	_add_tree_silhouette(builder, Vector3(11.8, 0.0, 15.5), 0.88)
	_camera = Camera3D.new()
	_camera.name = "MenuCamera"
	_camera.position = Vector3(0.0, 11.0, 39.0)
	_camera.fov = 39.0
	_camera.near = 0.1
	_camera.far = 160.0
	_viewport.add_child(_camera)
	_camera.current = true
	_resize_render_target()
	_update_camera(0.0)

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_update_camera(delta)

func set_active(active: bool) -> void:
	_active = active
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	set_process(active)

func _resize_render_target() -> void:
	if _viewport == null:
		return
	var viewport_size := get_viewport_rect().size
	var scale := minf(1.0, minf(1600.0 / maxf(1.0, viewport_size.x), 900.0 / maxf(1.0, viewport_size.y)))
	_viewport.size = Vector2i(maxi(1, roundi(viewport_size.x * scale)), maxi(1, roundi(viewport_size.y * scale)))

func _update_camera(_delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var pan := sin(_elapsed * 0.11) * 0.12
	var lift := sin(_elapsed * 0.075) * 0.09
	_camera.look_at(Vector3(-3.0 + pan, 5.2 + lift, 2.0), Vector3.UP)

func _add_moon(builder: Node3D) -> void:
	var moon := MeshInstance3D.new()
	moon.name = "MenuMoon"
	var mesh := SphereMesh.new()
	mesh.radius = 0.82
	mesh.height = 1.64
	mesh.radial_segments = 16
	mesh.rings = 8
	moon.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d5d1c4")
	material.emission_enabled = true
	material.emission = Color("c5d0dc")
	material.emission_energy_multiplier = 0.28
	moon.material_override = material
	moon.position = Vector3(0.0, 15.2, 7.5)
	builder.add_child(moon)

func _add_tree_silhouette(builder: Node3D, at: Vector3, scale_value: float) -> void:
	var tree := Node3D.new()
	tree.name = "MenuTreeSilhouette"
	tree.position = at
	tree.scale = Vector3.ONE * scale_value
	builder.add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.38
	trunk_mesh.height = 5.4
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	var bark := StandardMaterial3D.new()
	bark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bark.albedo_color = Color("101417")
	trunk.material_override = bark
	trunk.position.y = 2.7
	tree.add_child(trunk)
	for index in 4:
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		var radius := 3.35 - float(index) * 0.55
		cone.top_radius = 0.0
		cone.bottom_radius = radius
		cone.height = 4.7
		cone.radial_segments = 7
		crown.mesh = cone
		var needles := StandardMaterial3D.new()
		needles.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		needles.albedo_color = Color("11171a")
		crown.material_override = needles
		crown.position.y = 4.5 + float(index) * 2.15
		tree.add_child(crown)

func _add_window_glows(builder: Node3D) -> void:
	for level in [0.0, 3.6]:
		for x in [-7.0, 7.0]:
			_add_glowing_window(builder, Vector3(x, level + 1.82, 11.82), Vector2(1.55, 2.0), 0.65 if level == 0.0 else 0.8)
	_add_glowing_window(builder, Vector3(0.0, 9.3, 11.79), Vector2(2.15, 2.2), 0.28)

func _add_glowing_window(builder: Node3D, at: Vector3, dimensions: Vector2, brightness: float) -> void:
	var pane := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(dimensions.x, dimensions.y, 0.035)
	pane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.60, 0.37, 0.17, 1.0)
	material.emission_enabled = true
	material.emission = Color("ffb466")
	material.emission_energy_multiplier = brightness
	pane.material_override = material
	pane.position = at
	pane.name = "WarmWindowLight"
	builder.add_child(pane)

func _add_porch_practicals(builder: Node3D) -> void:
	for x in [-2.7, 2.7]:
		var light := OmniLight3D.new()
		light.name = "PorchPractical"
		light.position = Vector3(x, 2.3, 11.0)
		light.light_color = Color("e8ad73")
		light.light_energy = 0.48
		light.omni_range = 6.0
		light.shadow_enabled = false
		builder.add_child(light)
