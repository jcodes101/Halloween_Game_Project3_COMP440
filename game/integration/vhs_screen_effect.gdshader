shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity = 0.08;
uniform vec2 screen_size = vec2(960.0, 720.0);

float hash21(vec2 point) {
	vec3 value = fract(vec3(point.xyx) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float edge_distance = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
	float edge_strength = smoothstep(0.28, 0.98, edge_distance);
	float chroma_offset = (0.00012 + intensity * 0.0013) * edge_strength;

	float time_frame = floor(TIME * 24.0);
	float row = floor(uv.y * screen_size.y / 2.0);
	float pixel_noise = hash21(vec2(floor(uv.x * screen_size.x / 2.0) + time_frame, row));
	float grain = (pixel_noise - 0.5) * (0.012 + intensity * 0.035);

	float scan = 0.5 + 0.5 * sin(uv.y * screen_size.y * 1.35);
	float scan_strength = (0.012 + intensity * 0.055) * scan;

	float track_seed = floor(TIME * 1.4);
	float tracking_gate = step(0.87, hash21(vec2(track_seed, 7.31)));
	float track_y = fract(TIME * 0.13 + hash21(vec2(track_seed, 2.17)));
	float track_band = 1.0 - smoothstep(0.0, 0.014, abs(uv.y - track_y));
	float tracking = tracking_gate * track_band * (0.0004 + intensity * 0.0032);
	float soft_band = hash21(vec2(floor(uv.y * 34.0), floor(TIME * 4.0)));
	float band_noise = (soft_band - 0.5) * (0.004 + intensity * 0.018);

	float horizontal_shift = (pixel_noise - 0.5) * (0.00015 + intensity * 0.00045) + tracking;
	vec2 red_uv = clamp(uv + vec2(horizontal_shift + chroma_offset, 0.0), vec2(0.001), vec2(0.999));
	vec2 green_uv = clamp(uv + vec2(horizontal_shift, 0.0), vec2(0.001), vec2(0.999));
	vec2 blue_uv = clamp(uv + vec2(horizontal_shift - chroma_offset, 0.0), vec2(0.001), vec2(0.999));
	vec3 red_sample = texture(screen_texture, red_uv).rgb;
	vec3 green_sample = texture(screen_texture, green_uv).rgb;
	vec3 blue_sample = texture(screen_texture, blue_uv).rgb;
	vec3 image = vec3(red_sample.r, green_sample.g, blue_sample.b);
	image *= 1.0 - scan_strength;
	image += grain + band_noise;
	COLOR = vec4(clamp(image, vec3(0.0), vec3(1.0)), 1.0);
}
