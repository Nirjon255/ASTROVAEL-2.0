extends SubViewportContainer
# 3D map of the whole route. Each stop has a 3D position: galaxies are separate clusters and the stops
# of a galaxy sit on a ring. The ship is shown as a 3D arrow with its heading, a coloured XYZ compass,
# and a line to the next stop. Drag to turn the map, use the mouse wheel to zoom.
# The HUD button switches between following the ship and showing the whole route.

const STOPS_PER_GALAXY: int = 6
const PlanetView = preload("res://scripts/planet_view.gd")
const GALAXY_SPACING: float = 260.0
const RING_RADIUS: float = 60.0
const STOPS_BEFORE: int = 40
const STOPS_AFTER: int = 8
const EARTH_POSITION: Vector3 = Vector3(-40.0, 0.0, 0.0)
const EARTH_COLOR: Color = Color(0.6, 0.75, 0.9)

var route = null
var follow_mode: bool = true
var state: Dictionary = {}
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var path_node: MeshInstance3D
var stop_nodes: Array = []
var ship_marker: Node3D
var ship_gizmo: Node3D
var target_node: MeshInstance3D
var black_hole_node: Node3D
var ship_pos: Vector3 = Vector3.ZERO
var ship_heading: Vector3 = Vector3(0.0, 0.0, -1.0)
var next_pos: Vector3 = Vector3.ZERO
var view_center: Vector3 = Vector3.ZERO
var full_center: Vector3 = Vector3.ZERO
var full_extent: float = 120.0
var cam_distance: float = 120.0
var yaw: float = 0.6
var pitch: float = 0.45
var zoom: float = 1.0
var dragging: bool = false
var built_nearest: int = -2
var built_target: int = -3
var target_marker: Node3D = null
var pulse_time: float = 0.0
var accent_cache: Dictionary = {}


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(260.0, 200.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(520, 400)
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.024, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.4)
	env.ambient_light_energy = 0.8
	world_env.environment = env
	world.add_child(world_env)

	camera = Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.5
	camera.far = 5000.0
	world.add_child(camera)
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 1.2
	world.add_child(sun)

	path_node = MeshInstance3D.new()
	world.add_child(path_node)

	ship_marker = Node3D.new()
	world.add_child(ship_marker)
	var cone := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 3.0
	cone_mesh.height = 8.0
	cone.mesh = cone_mesh
	cone.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cone.material_override = _glow(Color(0.98, 0.84, 0.58), 1.6)
	ship_marker.add_child(cone)

	ship_gizmo = _build_gizmo()
	target_node = MeshInstance3D.new()
	world.add_child(target_node)
	black_hole_node = _build_black_hole()
	black_hole_node.visible = false
	world.add_child(black_hole_node)

	gui_input.connect(_on_gui_input)


func _process(delta: float) -> void:
	pulse_time += delta
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.scale = Vector3.ONE * (1.0 + 0.25 * sin(pulse_time * 4.0))
	if not dragging:
		yaw += delta * 0.05
	var goal_center: Vector3 = ship_pos if follow_mode else full_center
	view_center = view_center.lerp(goal_center, 1.0 - exp(-3.0 * delta))
	var goal_distance: float = (120.0 if follow_mode else maxf(150.0, full_extent * 2.0)) * zoom
	cam_distance = lerpf(cam_distance, goal_distance, 1.0 - exp(-3.0 * delta))
	var offset := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * cam_distance
	camera.position = view_center + offset
	camera.look_at(view_center, Vector3.UP)

	ship_marker.position = ship_pos
	_face(ship_marker, ship_heading)
	ship_gizmo.position = ship_pos

	var line := ImmediateMesh.new()
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.98, 0.84, 0.58)
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_mat)
	line.surface_add_vertex(ship_pos)
	line.surface_add_vertex(next_pos)
	line.surface_end()
	target_node.mesh = line


func update_state(s: Dictionary) -> void:
	state = s
	if route == null:
		return
	var nearest: int = int(s.get("nearest", 0))
	var target: int = int(s.get("target", -1))
	if nearest != built_nearest or target != built_target:
		_rebuild(nearest, target)
	var traveled_units: float = float(s.get("traveled", 0.0))
	ship_pos = map_pos_for_units(traveled_units)
	ship_heading = (map_pos_for_units(traveled_units + 40.0) - ship_pos)
	if ship_heading.length() < 0.001:
		ship_heading = Vector3(0.0, 0.0, -1.0)
	ship_heading = ship_heading.normalized()
	next_pos = stop_position(nearest)
	if bool(s.get("bh_active", false)):
		black_hole_node.visible = true
		black_hole_node.position = map_pos_for_units(float(s.get("bh_units", 0.0)))
	else:
		black_hole_node.visible = false


func toggle_follow() -> bool:
	follow_mode = not follow_mode
	return follow_mode


func readout() -> String:
	if route == null or state.is_empty():
		return ""
	var nearest: int = int(state.get("nearest", 0))
	var to_next: Vector3 = next_pos - ship_pos
	var dir: Vector3 = to_next.normalized() if to_next.length() > 0.001 else Vector3(0.0, 0.0, -1.0)
	var heading_angles: Vector2 = _az_el(ship_heading)
	var next_angles: Vector2 = _az_el(dir)
	var next_name: String = String(route.planet(nearest)["name"])
	return "HEADING   X %+.2f   Y %+.2f   Z %+.2f\nAZIMUTH %4.0f°   ELEVATION %+4.0f°\nNEXT STOP  %s   ·   AZ %4.0f°   EL %+4.0f°" % [
		ship_heading.x, ship_heading.y, ship_heading.z,
		heading_angles.x, heading_angles.y,
		next_name, next_angles.x, next_angles.y]


# Map position of any route distance (route units), by interpolating between the stops either side of it.
func map_pos_for_units(u: float) -> Vector3:
	var i: int = maxi(0, int(state.get("nearest", 0)) - 3)
	while i > 0 and float(route.units(i - 1)) >= u:
		i -= 1
	while float(route.units(i)) < u:
		i += 1
	var prev: int = i - 1
	var u_prev: float = 0.0 if i == 0 else float(route.units(prev))
	var u_next: float = float(route.units(i))
	var t: float = clampf((u - u_prev) / maxf(0.001, u_next - u_prev), 0.0, 1.0)
	return stop_position(prev).lerp(stop_position(i), t)


func stop_position(i: int) -> Vector3:
	if i < 0:
		return EARTH_POSITION
	var planet: Dictionary = route.planet(i)
	var g: int = int(planet["galaxy"])
	var gf: float = float(g)
	var center: Vector3 = Vector3(cos(gf * 1.7), 0.15 * sin(gf * 0.9), sin(gf * 1.7)) * GALAXY_SPACING * gf * 1.0
	var local_index: int = i % STOPS_PER_GALAXY
	var a: float = float(local_index) * TAU / float(STOPS_PER_GALAXY) + gf * 0.4
	var ring := Vector3(cos(a) * RING_RADIUS, sin(a * 2.0) * 6.0, sin(a) * RING_RADIUS)
	return center + ring


func _rebuild(nearest: int, target: int) -> void:
	built_nearest = nearest
	built_target = target
	for node in stop_nodes:
		if is_instance_valid(node):
			node.queue_free()
	stop_nodes.clear()
	target_marker = null
	var start: int = maxi(-1, nearest - STOPS_BEFORE)
	var last: int = nearest + STOPS_AFTER
	if target >= 0:
		last = maxi(last, target + 1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for i in range(start, last + 1):
		var pos: Vector3 = stop_position(i)
		var col: Color = _accent(i)
		if i == target:
			col = Color(1.0, 0.5, 0.2)
		im.surface_set_color(col)
		im.surface_add_vertex(pos)
		_add_stop_marker(i, pos, col, i == nearest, i == target)
		sum += pos
		count += 1
	im.surface_end()
	path_node.mesh = im
	full_center = sum / float(maxi(count, 1))
	full_extent = 0.0
	for i in range(start, last + 1):
		full_extent = maxf(full_extent, stop_position(i).distance_to(full_center))


func _add_stop_marker(i: int, pos: Vector3, col: Color, is_next: bool, is_target: bool) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var r: float = 3.2 if is_next else 1.8
	if is_target:
		r = 4.4
	sphere.radius = r
	sphere.height = r * 2.0
	node.mesh = sphere
	node.position = pos
	node.material_override = _glow(col, 2.0 if is_target else (1.4 if is_next else 0.8))
	world.add_child(node)
	stop_nodes.append(node)
	if is_target:
		target_marker = node
	var label := Label3D.new()
	if i < 0:
		label.text = "EARTH"
	elif is_target:
		label.text = "TARGET · %s" % String(route.planet(i)["name"])
	else:
		label.text = String(route.planet(i)["name"])
	label.font_size = 40
	label.pixel_size = 0.04
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = col
	label.position = Vector3(0.0, r + 3.0, 0.0)
	node.add_child(label)


func _accent(i: int) -> Color:
	if i < 0:
		return EARTH_COLOR
	var galaxy: int = int(route.planet(i)["galaxy"])
	if not accent_cache.has(galaxy):
		accent_cache[galaxy] = route.galaxy_palette(galaxy)["accent"]
	return accent_cache[galaxy]


func _build_gizmo() -> Node3D:
	var gizmo := Node3D.new()
	world.add_child(gizmo)
	var colors: Array = [Color(0.95, 0.4, 0.35), Color(0.45, 0.9, 0.5), Color(0.4, 0.6, 1.0)]
	var rotations: Array = [Vector3(0.0, 0.0, 90.0), Vector3(0.0, 0.0, 0.0), Vector3(90.0, 0.0, 0.0)]
	var tips: Array = [Vector3(9.0, 0.0, 0.0), Vector3(0.0, 9.0, 0.0), Vector3(0.0, 0.0, 9.0)]
	var names: Array = ["X", "Y", "Z"]
	for k in range(3):
		var bar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.18
		cylinder.bottom_radius = 0.18
		cylinder.height = 16.0
		bar.mesh = cylinder
		bar.rotation_degrees = rotations[k]
		bar.material_override = _glow(colors[k], 1.2)
		gizmo.add_child(bar)
		var label := Label3D.new()
		label.text = names[k]
		label.font_size = 48
		label.pixel_size = 0.05
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = colors[k]
		label.position = tips[k] + Vector3(0.0, 1.5, 0.0)
		gizmo.add_child(label)
	return gizmo


func _build_black_hole() -> Node3D:
	var node := Node3D.new()
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 3.0
	core_mesh.height = 6.0
	core.mesh = core_mesh
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.0, 0.0, 0.0)
	core.material_override = void_mat
	node.add_child(core)
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 3.8
	shell_mesh.height = 7.6
	shell.mesh = shell_mesh
	var shader := Shader.new()
	shader.code = PlanetView.ATMOSPHERE_CODE
	var shell_mat := ShaderMaterial.new()
	shell_mat.shader = shader
	shell_mat.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.3))
	shell_mat.set_shader_parameter("intensity", 1.2)
	shell_mat.set_shader_parameter("falloff", 2.2)
	shell.material_override = shell_mat
	node.add_child(shell)
	return node


func _face(node: Node3D, dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var up: Vector3 = Vector3.UP
	if absf(dir.normalized().y) > 0.98:
		up = Vector3.FORWARD
	node.look_at(node.global_position + dir, up)


func relative_bearing() -> float:
	if route == null or state.is_empty():
		return 0.0
	var to_next: Vector3 = next_pos - ship_pos
	if to_next.length() < 0.001:
		return 0.0
	var az_next: float = _az_el(to_next.normalized()).x
	var az_heading: float = _az_el(ship_heading).x
	return wrapf(az_next - az_heading + 180.0, 0.0, 360.0) - 180.0


func _az_el(v: Vector3) -> Vector2:
	return Vector2(rad_to_deg(atan2(v.x, -v.z)), rad_to_deg(asin(clampf(v.y, -1.0, 1.0))))


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_LEFT:
			dragging = button.pressed
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			zoom = clampf(zoom * 0.9, 0.3, 3.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			zoom = clampf(zoom * 1.1, 0.3, 3.0)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and dragging:
		yaw -= motion.relative.x * 0.01
		pitch = clampf(pitch + motion.relative.y * 0.01, -1.2, 1.2)


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
