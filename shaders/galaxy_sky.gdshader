// Galaxy sky for ASTROVAEL 28.0: stars, a galactic band and nebula clouds.
// Each galaxy sets its own band direction and colours, so the sky changes on arrival.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled;

uniform vec3 band_normal = vec3(0.32, 0.92, 0.22);
uniform vec3 band_color = vec3(0.46, 0.50, 0.72);
uniform vec3 nebula_color = vec3(0.30, 0.12, 0.55);
uniform vec3 star_tint_a = vec3(0.70, 0.83, 1.0);
uniform vec3 star_tint_b = vec3(1.0, 0.86, 0.66);
uniform vec3 sun_dir = vec3(-0.78, 0.30, 0.55);
uniform float star_gain = 0.7;
uniform float band_gain = 0.26;
uniform float nebula_gain = 0.14;
uniform float time_s = 0.0;

varying vec3 sky_dir;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
			mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

vec3 star_layer(vec3 dir, float density, float threshold, float size) {
	vec3 p = dir * density;
	vec3 cell = floor(p);
	vec3 local = fract(p) - 0.5;
	float r = hash13(cell);
	float present = step(threshold, r);
	float d = length(local);
	float core = smoothstep(size, 0.0, d) * present;
	float tint_mix = hash13(cell + 6.6);
	vec3 tint = mix(star_tint_a, star_tint_b, tint_mix);
	float twinkle = 0.7 + 0.3 * sin(time_s * (1.2 + 2.8 * hash13(cell + 4.4)) + 6.2831 * hash13(cell + 1.3));
	return tint * core * (0.6 + 0.8 * hash13(cell + 2.1)) * twinkle;
}

void vertex() {
	sky_dir = VERTEX;
}

void fragment() {
	vec3 dir = normalize(sky_dir);
	vec3 col = vec3(0.0);
	col += star_layer(dir, 340.0, 0.9915, 0.34) * star_gain;
	col += star_layer(dir, 150.0, 0.9975, 0.36) * star_gain * 1.6;

	vec3 n = normalize(band_normal);
	float band = exp(-pow(dot(dir, n) * 5.5, 2.0));
	float clouds = 0.6 * value_noise(dir * 6.0) + 0.4 * value_noise(dir * 15.0 + vec3(4.0));
	col += band_color * band * (0.20 + 0.95 * clouds) * band_gain;

	float neb = value_noise(dir * 2.5 + vec3(9.0) + vec3(time_s * 0.01)) * value_noise(dir * 4.0 - vec3(3.0));
	col += nebula_color * neb * nebula_gain;

	float sd = max(dot(dir, normalize(sun_dir)), 0.0);
	col += vec3(1.0, 0.96, 0.88) * (smoothstep(0.99905, 0.99975, sd) * 5.0 + pow(sd, 700.0) * 1.2 + pow(sd, 18.0) * 0.10);

	ALBEDO = col;
	ALPHA = 1.0;
}
