// Engine exhaust: additive, unshaded, with a hot core that fades to the edge colour
// and a flickering flow along the length of the plume.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform vec4 core_color : source_color = vec4(0.70, 0.95, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.00, 0.42, 1.00, 1.0);
uniform float intensity = 2.3;
uniform float flow_speed = 8.0;

float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453123);
}

float value1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), u);
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Noise runs along the plume length only, so the cylinder seam never shows.
	float flicker = 0.6 * value1(UV.y * 4.0 - TIME * flow_speed)
		+ 0.4 * value1(UV.y * 9.0 - TIME * flow_speed * 1.6 + 31.0);
	vec3 tint = mix(edge_color.rgb, core_color.rgb, pow(facing, 2.0));
	ALBEDO = tint * intensity * (0.55 + 0.9 * flicker);
	ALPHA = 1.0;
}
