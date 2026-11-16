extends Node3D
# The opening from the design document. A vast ring-shaped orbital station above a blue planet. The camera glides
# through the station on a smooth path while cargo shuttles, service drones and the station's lights move.
# START MISSION boards the ship: the engines ignite, the camera follows the ship out past the docking arm, and the
# station shrinks behind as the flight begins.

const MAIN_SCENE: String = "res://scenes/Main.tscn"
const COVER_SCENE: String = "res://scenes/Cover.tscn"
const SaveData = preload("res://scripts/save_data.gd")
const RouteBuilder = preload("res://scripts/route.gd")
const PlanetView = preload("res://scripts/planet_view.gd")
const ShipModel = preload("res://scripts/ship_model.gd")
const HudScript = preload("res://scripts/hud.gd")
const StationModel = preload("res://scripts/station_model.gd")
const StationTraffic = preload("res://scripts/station_traffic.gd")
const SUN_DIRECTION: Vector3 = Vector3(-0.78, 0.30, 0.55)
const AMBER: Color = Color(0.98, 0.76, 0.48)
const CREAM: Color = Color(0.90, 0.86, 0.78)
const GOLD: Color = Color(0.98, 0.84, 0.58)
const STATION_RADIUS: float = 34.0
const DOCK_POS: Vector3 = Vector3(0.0, -1.0, 54.0)
const GLIDE_SECONDS: float = 40.0
const LAUNCH_SECONDS: float = 9.0
# Camera keys for the glide. The first and last key are the same point, so the path loops.
const GLIDE_KEYS: Array = [
	Vector3(70.0, 14.0, 60.0), Vector3(26.0, 6.0, 26.0), Vector3(-16.0, 9.0, 10.0),
	Vector3(-44.0, 16.0, -22.0), Vector3(-18.0, 8.0, -56.0), Vector3(22.0, -6.0, -46.0),
	Vector3(54.0, 6.0, -12.0), Vector3(70.0, 14.0, 60.0),
]

var time_s: float = 0.0
var phase: String = "glide"
var glide_t: float = 0.0
var launch_t: float = 0.0
var camera: Camera3D
var station_root: Node3D
var planet_node: Node3D
var window_lights: Array = []
var beacons: Array = []
var panel_pivots: Array = []
var shuttles: Array = []
var drones: Array = []
var player_ship: Node3D
var player_flames: Array = []
var ui_column: VBoxContainer
var balance_label: Label
var fade_rect: ColorRect
var traffic: Node3D = null
var station_pads: Array = []


func _ready() -> void:
	var saved: Dictionary = SaveData.load_data()
	_build_environment()
	_build_planet()
	_build_station()
	_build_traffic()
	_build_flyers()
	_build_camera()
	_build_ui(int(saved.get("balance", 0)))


func _process(delta: float) -> void:
	time_s += delta
	match phase:
		"glide":
			glide_t += delta
			var u: float = fposmod(glide_t / GLIDE_SECONDS, 1.0)
			camera.position = _catmull(GLIDE_KEYS, u)
			camera.look_at(Vector3(sin(u * TAU) * 6.0, 0.0, cos(u * TAU) * 6.0), Vector3.UP)
		"launch":
			launch_t += delta
			_update_launch()
	_animate_station(delta)


# ---------------------------------------------------------------- the camera and the launch

# Catmull-Rom spline through the keys; u runs from 0 to 1 over the whole loop.
static func _catmull(points: Array, u: float) -> Vector3:
	var n: int = points.size() - 1
	var f: float = u * float(n)
	var i: int = int(floor(f))
	var t: float = f - float(i)
	var p0: Vector3 = points[(i - 1 + n) % n]
	var p1: Vector3 = points[i % n]
	var p2: Vector3 = points[(i + 1) % n]
	var p3: Vector3 = points[(i + 2) % n]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


func _update_launch() -> void:
	# The ship accelerates away from the dock along the arm.
	var distance: float = 0.5 * 8.0 * launch_t * launch_t
	var ship_pos: Vector3 = DOCK_POS + Vector3(0.0, 0.0, distance)
	player_ship.position = ship_pos + Vector3(0.0, sin(time_s * 2.0) * 0.05, 0.0)
	var ignite: float = clampf(launch_t / 3.0, 0.0, 1.0)
	for flame in player_flames:
		(flame as MeshInstance3D).scale = Vector3(1.0, 1.0, 0.5 + ignite * 2.0 + 0.1 * sin(time_s * 40.0))
	# The camera trails the ship, so the station shrinks behind it.
	camera.position = player_ship.position + Vector3(0.0, 3.5, -12.0) + Vector3(sin(time_s * 30.0) * 0.02, 0.0, 0.0)
	camera.look_at(player_ship.position + Vector3(0.0, 0.0, 10.0), Vector3.UP)
	fade_rect.color.a = clampf((launch_t - (LAUNCH_SECONDS - 2.0)) / 2.0, 0.0, 1.0)
	if launch_t >= LAUNCH_SECONDS:
		get_tree().change_scene_to_file(MAIN_SCENE)


func _start_launch() -> void:
	if phase != "glide":
		return
	phase = "launch"
	launch_t = 0.0
	ui_column.visible = false
	player_ship = Node3D.new()
	player_ship.rotation.y = PI
	player_ship.position = DOCK_POS
	add_child(player_ship)
	var built: Dictionary = ShipModel.build(player_ship)
	player_flames = built["flames"]


# ---------------------------------------------------------------- station animation

func _animate_station(delta: float) -> void:
	station_root.rotation.y += delta * 0.01
	planet_node.rotate_y(delta * 0.02)
	for k in range(window_lights.size()):
		var lamp: StandardMaterial3D = window_lights[k]
		lamp.emission_energy_multiplier = 1.0 + 0.35 * sin(time_s * 1.3 + float(k) * 0.7)
	for beacon in beacons:
		var mat: StandardMaterial3D = beacon[0]
		mat.emission_energy_multiplier = 0.2 + 2.6 * pow(0.5 + 0.5 * sin(time_s * 2.4 + float(beacon[1])), 6.0)
	for i in range(panel_pivots.size()):
		var pivot: Node3D = panel_pivots[i]
		pivot.rotation.x = sin(time_s * 0.1 + float(i) * 1.7) * 0.45
	for shuttle in shuttles:
		var span: float = float(shuttle["speed"]) * time_s + float(shuttle["phase"])
		var u: float = absf(fposmod(span, 2.0) - 1.0)
		var forward: float = 1.0 if fposmod(span, 2.0) < 1.0 else -1.0
		var a: Vector3 = shuttle["a"]
		var b: Vector3 = shuttle["b"]
		var node: Node3D = shuttle["node"]
		node.position = a.lerp(b, smoothstep(0.0, 1.0, u))
		_face(node, (b - a) * forward)
	for drone in drones:
		var angle: float = time_s * float(drone["speed"]) + float(drone["phase"])
		var r: float = float(drone["radius"])
		var dnode: Node3D = drone["node"]
		dnode.position = Vector3(cos(angle) * r, float(drone["y"]) + sin(angle * 3.0) * 1.5, sin(angle) * r)


# ---------------------------------------------------------------- scene

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.014, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.34)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 0.7
	env.glow_bloom = 0.05
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	add_child(sun)

	var sky := MeshInstance3D.new()
	var sky_mesh := SphereMesh.new()
	sky_mesh.radius = 1200.0
	sky_mesh.height = 2400.0
	sky.mesh = sky_mesh
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/galaxy_sky.gdshader") as Shader
	sky_mat.set_shader_parameter("sun_dir", SUN_DIRECTION.normalized())
	sky.material_override = sky_mat
	add_child(sky)


func _build_planet() -> void:
	# A blue world below the station, lit by the sun, with cloud layers and an atmosphere.
	var data: Dictionary = RouteBuilder.earth_data()
	data["radius"] = 240.0
	var view: Dictionary = PlanetView.build(data)
	planet_node = view["root"]
	planet_node.position = Vector3(170.0, -240.0, -520.0)
	add_child(planet_node)


func _build_station() -> void:
	station_root = Node3D.new()
	add_child(station_root)
	var built: Dictionary = StationModel.build(station_root)
	window_lights = built["windows"]
	beacons = built["beacons"]
	panel_pivots = built["panels"]
	station_pads = built["pads"]


func _build_traffic() -> void:
	# Cargo shuttles fly between the docking arms and the hub, back and forth.
	var lanes: Array = [
		[Vector3(-58.0, 6.0, 20.0), Vector3(-22.0, 4.0, -8.0)],
		[Vector3(42.0, -4.0, -40.0), Vector3(14.0, 2.0, 18.0)],
		[Vector3(-30.0, 12.0, -54.0), Vector3(30.0, 8.0, -24.0)],
	]
	for i in range(lanes.size()):
		var node := Node3D.new()
		node.scale = Vector3.ONE * 0.55
		add_child(node)
		var built: Dictionary = ShipModel.build(node)
		_box(node, Vector3(1.6, 0.8, 1.6), Vector3(0.0, -0.9, 0.0), _plain(Color(0.45, 0.4, 0.3), 0.7, 0.2))
		shuttles.append({
			"node": node,
			"a": lanes[i][0],
			"b": lanes[i][1],
			"speed": 0.05 + 0.02 * float(i),
			"phase": float(i) * 0.7,
			"flames": built["flames"],
		})
	# Service drones circle the station, each with a small blue light.
	for i in range(10):
		var drone := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.28
		sphere.height = 0.56
		drone.mesh = sphere
		drone.material_override = _glow(Color(0.35, 0.8, 1.0), 1.6)
		add_child(drone)
		drones.append({
			"node": drone,
			"radius": 44.0 + float(i % 4) * 4.0,
			"speed": 0.06 + 0.012 * float(i % 5),
			"phase": float(i) * 0.9,
			"y": -4.0 + float(i % 3) * 4.0,
		})


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 56.0
	camera.near = 0.3
	camera.far = 4000.0
	add_child(camera)
	camera.current = true
	camera.position = GLIDE_KEYS[0]


func _build_ui(balance: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	ui_column = VBoxContainer.new()
	ui_column.position = Vector2(60.0, 120.0)
	ui_column.custom_minimum_size = Vector2(520.0, 0.0)
	ui_column.add_theme_constant_override("separation", 14)
	root.add_child(ui_column)
	ui_column.add_child(_label("ASTROVAEL", 60, Color(0.97, 0.94, 0.88)))
	ui_column.add_child(_label("ORBITAL STATION   ·   MISSION CONTROL", 14, AMBER))
	var body := _label("Commander, a survivor on a distant world has sent a distress signal. Fly there, land, defend the survivor from the hostile craft, and bring them aboard. Every rescue pays $10,000.", 15, CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(500.0, 0.0)
	ui_column.add_child(body)
	balance_label = _label("BALANCE   $%s" % HudScript.commas(balance), 20, GOLD)
	ui_column.add_child(balance_label)
	var start := _button("START MISSION", _on_start)
	ui_column.add_child(start)
	ui_column.add_child(_button("BACK TO MENU", _on_back))
	start.grab_focus.call_deferred()

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)


func _on_start() -> void:
	_start_launch()


func _on_back() -> void:
	get_tree().change_scene_to_file(COVER_SCENE)


# Patrol craft and freighters fly around the station, and shuttles land on its pads.
func _build_flyers() -> void:
	traffic = StationTraffic.new()
	add_child(traffic)
	traffic.setup(station_root, station_pads)


# ---------------------------------------------------------------- helpers

func _face(node: Node3D, dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var up: Vector3 = Vector3.UP
	if absf(dir.normalized().y) > 0.98:
		up = Vector3.FORWARD
	node.look_at(node.global_position + dir, up)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = mat
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = mat
	parent.add_child(node)
	return node


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node


func _plain(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(caption: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(300.0, 46.0)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
	button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.08, 0.06, 0.72), Color(0.85, 0.65, 0.40, 0.45)))
	button.add_theme_stylebox_override("hover", _style(Color(0.24, 0.17, 0.02, 0.75), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color(0.24, 0.17, 0.02, 0.75), GOLD))
	button.pressed.connect(handler)
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
