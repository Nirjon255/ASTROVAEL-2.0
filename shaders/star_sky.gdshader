// Star sky for ASTROVAEL 26.0. Used on an inverted sphere that follows the camera's
// position (see main.gd: _build_star_sky). Stars, the Milky Way and the sun's glare
// are evaluated in fixed world directions, so the sky does not rotate with the ship.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled;

uniform vec3 sun_dir = vec3(-0.78, 0.30, 0.55);
uniform vec3 sun_tint = vec3(1.0, 0.96, 0.88);
uniform float star_gain = 1.0;
uniform float milky_way_gain = 0.42;

varying vec3 sky_dir;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, f.x);
	float x10 = mix(n010, n110, f.x);
	float x01 = mix(n001, n101, f.x);
	float x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

// One star per grid cell, present with probability (1 - threshold). Jitter and
// radius are kept small enough that a star never crosses its cell boundary.
vec3 star_layer(vec3 dir, float density, float threshold, float max_radius) {
	vec3 p = dir * density;
	vec3 cell = floor(p);
	if (hash13(cell) < threshold) {
		return vec3(0.0);
	}
	vec3 jitter = vec3(hash13(cell + 1.7), hash13(cell + 4.3), hash13(cell + 8.9)) - 0.5;
	float d = length(fract(p) - 0.5 - jitter * 0.3);
	float radius = mix(0.14, max_radius, hash13(cell + 2.2));
	float core = smoothstep(radius, 0.0, d);
	vec3 tint = mix(vec3(0.70, 0.83, 1.0), vec3(1.0, 0.86, 0.66), hash13(cell + 6.6));
	float brightness = mix(0.18, 1.0, pow(hash13(cell + 9.1), 3.0));
	return tint * core * brightness;
}

void vertex() {
	// Object space equals world orientation here, because the sphere has no rotation.
	sky_dir = VERTEX;
}

void fragment() {
	vec3 dir = normalize(sky_dir);
	vec3 col = vec3(0.0);

	// Two star populations: a dense faint field and a sparse, brighter set.
	col += star_layer(dir, 340.0, 0.9915, 0.34) * star_gain;
	col += star_layer(dir, 150.0, 0.9975, 0.36) * star_gain * 1.6;

	// Milky Way: a soft band of dust and star clouds around a galactic plane.
	vec3 galactic_normal = normalize(vec3(0.32, 0.92, 0.22));
	float band = exp(-pow(dot(dir, galactic_normal) * 5.5, 2.0));
	float clouds = 0.6 * value_noise(dir * 6.0) + 0.4 * value_noise(dir * 15.0 + 4.0);
	col += vec3(0.46, 0.50, 0.72) * band * (0.20 + 0.95 * clouds) * milky_way_gain;

	// The sun: a hard disc with a wide glare.
	float sd = max(dot(dir, normalize(sun_dir)), 0.0);
	col += sun_tint * (smoothstep(0.99905, 0.99975, sd) * 5.0 + pow(sd, 700.0) * 1.2 + pow(sd, 18.0) * 0.10);

	ALBEDO = col;
	ALPHA = 1.0;
}
