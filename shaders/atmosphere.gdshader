// Atmospheric limb glow for planets: a fresnel rim on a slightly larger sphere,
// drawn additively so it only brightens the edge of the planet.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

uniform vec4 glow_color : source_color = vec4(0.0, 0.5, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float falloff = 3.4;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, falloff);
	ALBEDO = glow_color.rgb * rim * intensity;
	ALPHA = 1.0;
}
