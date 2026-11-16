extends RefCounted
# Builds one planet: a textured body, optional cloud layer, an atmosphere shell and optional rings.
# Used by the flight scene (route planets) and by the cover (Earth).
# Returns the root plus the body and cloud nodes, so the caller can spin them.

const ATMOSPHERE_CODE: String = """
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
"""


static func build(data: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(0.0, 0.0, float(data.get("tilt", 0.0)))
	root.add_child(tilt)

	var radius: float = float(data.get("radius", 100.0))

	var body := MeshInstance3D.new()
	body.mesh = _sphere(radius, 128, 64)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(String(data.get("texture", "res://assets/mars_surface.png")))
	mat.albedo_color = data.get("tint", Color(1.0, 1.0, 1.0))
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	body.material_override = mat
	tilt.add_child(body)

	var clouds: MeshInstance3D = null
	var cloud_path: String = String(data.get("cloud", ""))
	if cloud_path != "":
		clouds = MeshInstance3D.new()
		clouds.mesh = _sphere(radius * 1.012, 128, 64)
		var cloud_mat := StandardMaterial3D.new()
		cloud_mat.albedo_texture = load(cloud_path)
		cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud_mat.roughness = 1.0
		clouds.material_override = cloud_mat
		tilt.add_child(clouds)

	var shell := MeshInstance3D.new()
	shell.mesh = _sphere(radius * 1.06, 128, 64)
	var shader := Shader.new()
	shader.code = ATMOSPHERE_CODE
	var atmo_mat := ShaderMaterial.new()
	atmo_mat.shader = shader
	atmo_mat.set_shader_parameter("glow_color", data.get("atmos", Color(0.3, 0.6, 1.0)))
	atmo_mat.set_shader_parameter("intensity", float(data.get("atmos_i", 1.0)))
	atmo_mat.set_shader_parameter("falloff", 3.2)
	shell.material_override = atmo_mat
	root.add_child(shell)

	if bool(data.get("ring", false)):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 1.35
		torus.outer_radius = radius * 2.25
		torus.rings = 6
		torus.ring_segments = 96
		ring.mesh = torus
		ring.scale = Vector3(1.0, 0.012, 1.0)
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.9, 0.84, 0.66, 0.7)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = ring_mat
		tilt.add_child(ring)

	var pivots: Array = []
	var moon_count: int = mini(int(data.get("moons", 0)), 3)
	for m in range(moon_count):
		var pivot := Node3D.new()
		pivot.rotation_degrees = Vector3(float(m) * 17.0 - 10.0, float(m) * 40.0, 0.0)
		root.add_child(pivot)
		var moon := MeshInstance3D.new()
		var moon_mesh := SphereMesh.new()
		var moon_radius: float = radius * (0.10 + 0.04 * float(m))
		moon_mesh.radius = moon_radius
		moon_mesh.height = moon_radius * 2.0
		moon.mesh = moon_mesh
		moon.position = Vector3(radius * (1.8 + 0.7 * float(m)), 0.0, 0.0)
		var moon_mat := StandardMaterial3D.new()
		moon_mat.albedo_color = Color(0.6, 0.58, 0.55)
		moon_mat.roughness = 0.9
		moon.material_override = moon_mat
		pivot.add_child(moon)
		pivots.append({"node": pivot, "speed": 0.25 + 0.12 * float(m)})

	return {"root": root, "body": body, "clouds": clouds, "pivots": pivots}


static func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh
