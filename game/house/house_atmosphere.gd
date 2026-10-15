extends Node3D
## Procedural house ambience: small CRTs, stove steam, and restrained lamp dips.

const CRT_SHADER = preload("res://game/house/crt_screen.gdshader")
const STEAM_SHADER = preload("res://game/house/steam_puff.gdshader")

@export_range(-40.0, -8.0, 0.5) var television_static_volume_db := -26.0
@export_range(4.0, 14.0, 1.0) var light_dip_interval_min := 7.0
@export_range(5.0, 20.0, 1.0) var light_dip_interval_max := 13.0

var television_screens: Array[MeshInstance3D] = []
var television_players: Array[AudioStreamPlayer3D] = []
var steam_emitter: GPUParticles3D
var flickering_lights: Array[OmniLight3D] = []
var _flicker_states: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()
var _tv_static_stream: AudioStreamWAV

func configure(televisions: Array[Node3D], stove_surface: Vector3, selected_lights: Array[OmniLight3D]) -> void:
	_random.randomize()
	_tv_static_stream = _make_tv_static_stream()
	for television in televisions:
		_configure_television(television)
		_add_television_glow(television)
		_add_television_audio(television)
	_create_stove_steam(stove_surface)
	for light in selected_lights:
		if not is_instance_valid(light):
			continue
		flickering_lights.append(light)
		_flicker_states.append({
			"base_energy": light.light_energy,
			"wait": _random.randf_range(light_dip_interval_min, light_dip_interval_max),
			"remaining": 0.0,
			"dipped": false,
			"dip_factor": 1.0,
		})

func _configure_television(television: Node3D) -> void:
	for candidate in television.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			if mesh_instance.mesh.surface_get_name(surface).to_lower() != "metaldark":
				continue
			var material := ShaderMaterial.new()
			material.shader = CRT_SHADER
			mesh_instance.set_surface_override_material(surface, material)
			television_screens.append(mesh_instance)
			return
	push_warning("Vintage television has no metalDark screen surface: " + television.name)

func _add_television_glow(television: Node3D) -> void:
	var light := OmniLight3D.new()
	light.name = television.name + "ScreenGlow"
	light.position = television.position + Vector3(0.0, television.scale.y * 0.55, -television.scale.z * 0.53)
	light.light_color = Color(0.50, 0.67, 0.82)
	light.light_energy = 0.19
	light.omni_range = 3.2
	light.omni_attenuation = 2.0
	light.shadow_enabled = false
	add_child(light)

func _add_television_audio(television: Node3D) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = television.name + "StaticAudio"
	player.stream = _tv_static_stream
	player.volume_db = television_static_volume_db
	player.unit_size = 1.5
	player.max_distance = 7.0
	player.position = television.position + Vector3(0.0, television.scale.y * 0.55, -television.scale.z * 0.53)
	add_child(player)
	television_players.append(player)
	# The dummy headless audio driver retains active WAV playback instances at exit.
	# Keep the configured spatial players available for inspection, but start audio
	# only when an actual audio-capable display/game session is running.
	if DisplayServer.get_name() != "headless":
		player.play()

func _create_stove_steam(stove_surface: Vector3) -> void:
	steam_emitter = GPUParticles3D.new()
	steam_emitter.name = "KitchenStoveSteam"
	steam_emitter.position = stove_surface
	steam_emitter.amount = 14
	steam_emitter.lifetime = 2.5
	steam_emitter.preprocess = 1.2
	steam_emitter.emitting = true
	steam_emitter.visibility_aabb = AABB(Vector3(-0.5, -0.1, -0.5), Vector3(1.0, 2.1, 1.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.10
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 17.0
	process_material.initial_velocity_min = 0.08
	process_material.initial_velocity_max = 0.17
	process_material.gravity = Vector3(0.0, -0.015, 0.0)
	process_material.damping_min = 0.015
	process_material.damping_max = 0.04
	process_material.scale_min = 0.34
	process_material.scale_max = 0.70
	process_material.color_ramp = _steam_color_ramp()
	steam_emitter.process_material = process_material
	var puff := QuadMesh.new()
	puff.size = Vector2(0.20, 0.30)
	var material := ShaderMaterial.new()
	material.shader = STEAM_SHADER
	material.set_shader_parameter("noise_texture", _steam_noise())
	puff.material = material
	steam_emitter.draw_pass_1 = puff
	add_child(steam_emitter)

func _steam_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.18, Color(1.0, 1.0, 1.0, 0.18))
	gradient.add_point(0.72, Color(1.0, 1.0, 1.0, 0.10))
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

func _steam_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.075
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 64
	texture.height = 64
	texture.seamless = true
	texture.generate_mipmaps = true
	return texture

func _make_tv_static_stream() -> AudioStreamWAV:
	# Original, low-level white/brown noise synthesis; no recorded audio is used.
	const SAMPLE_RATE := 11025
	const SAMPLE_COUNT := SAMPLE_RATE * 3
	var bytes := PackedByteArray()
	bytes.resize(SAMPLE_COUNT * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var low_noise := 0.0
	var fade_frames := int(SAMPLE_RATE * 0.015)
	for frame in SAMPLE_COUNT:
		low_noise = lerpf(low_noise, rng.randf_range(-1.0, 1.0), 0.16)
		var time := float(frame) / SAMPLE_RATE
		var sample := rng.randf_range(-0.19, 0.19) + low_noise * 0.10 + sin(time * TAU * 60.0) * 0.018
		var edge_fade := minf(1.0, minf(float(frame) / fade_frames, float(SAMPLE_COUNT - frame - 1) / fade_frames))
		bytes.encode_s16(frame * 2, roundi(clampf(sample * edge_fade, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = SAMPLE_COUNT
	return stream

func _process(delta: float) -> void:
	for index in flickering_lights.size():
		var light := flickering_lights[index]
		if not is_instance_valid(light):
			continue
		var state: Dictionary = _flicker_states[index]
		var target_energy: float = state.base_energy
		if state.dipped:
			state.remaining = float(state.remaining) - delta
			if state.remaining <= 0.0:
				state.dipped = false
				state.wait = _random.randf_range(light_dip_interval_min, light_dip_interval_max)
			else:
				target_energy *= float(state.dip_factor)
		else:
			state.wait = float(state.wait) - delta
			if state.wait <= 0.0:
				state.dipped = true
				state.remaining = _random.randf_range(0.15, 0.28)
				state.dip_factor = _random.randf_range(0.78, 0.90)
				target_energy *= float(state.dip_factor)
		_flicker_states[index] = state
		light.light_energy = lerpf(light.light_energy, target_energy, 1.0 - exp(-delta * 10.0))

func stop_ambience() -> void:
	for player in television_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(steam_emitter):
		steam_emitter.emitting = false

func _exit_tree() -> void:
	stop_ambience()
