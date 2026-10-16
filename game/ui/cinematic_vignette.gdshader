shader_type canvas_item;

uniform vec4 shadow_tint : source_color = vec4(0.004, 0.003, 0.006, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.68;
uniform float left_fade : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	centered.x *= 1.15;
	float radial = smoothstep(0.22, 0.82, length(centered));
	float left_shadow = 1.0 - smoothstep(0.08, 0.78, UV.x);
	float alpha = max(radial * 0.72, left_shadow * left_fade);
	COLOR = vec4(shadow_tint.rgb, alpha * strength);
}
