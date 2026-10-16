shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.24;

float hash21(vec2 point) {
	vec3 value = fract(vec3(point.xyx) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}

void fragment() {
	vec2 uv = UV;
	float frame = floor(TIME * 18.0);
	float static_value = hash21(vec2(floor(uv.x * 180.0) + frame, floor(uv.y * 100.0)));
	float scanline = 0.91 + 0.09 * sin(floor(uv.y * 150.0) * 3.14159);
	float gate = step(0.94, hash21(vec2(floor(TIME * 1.1), 4.7)));
	float band_y = fract(TIME * 0.08 + hash21(vec2(floor(TIME * 1.1), 9.2)));
	float interference = gate * (1.0 - smoothstep(0.0, 0.024, abs(uv.y - band_y)));
	float signal = clamp(0.12 + static_value * 0.24 + interference * 0.36, 0.0, 0.8);
	vec3 phosphor = mix(vec3(0.008, 0.014, 0.021), vec3(0.34, 0.48, 0.54), signal * scanline);
	ALBEDO = phosphor;
	EMISSION = phosphor * glow_strength;
	ROUGHNESS = 1.0;
}
