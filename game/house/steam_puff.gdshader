shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_texture : source_color, filter_linear;

void fragment() {
	vec2 uv = UV;
	float noise_value = texture(noise_texture, uv * 2.0 + vec2(0.0, TIME * 0.12)).r;
	float radial = 1.0 - smoothstep(0.16, 0.52, length((uv - vec2(0.5)) * vec2(1.0, 1.35)));
	float wisps = smoothstep(0.2, 0.78, noise_value);
	ALBEDO = vec3(0.76, 0.81, 0.84);
	ALPHA = radial * wisps * COLOR.a;
}
