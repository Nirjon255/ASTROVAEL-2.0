extends Node3D
# ASTROVAEL 30.0 - 3D cover / main menu.
# Builds its own 3D backdrop (Earth, moon, ship, star sky, drifting dust) and a
# 2D menu overlay laid out like the reference cover. START GAME opens main.tscn.

const GAME_TITLE: String = "ASTROVAEL"
const MAIN_SCENE: String = "res://scenes/Main.tscn"
const SaveData = preload("res://scripts/save_data.gd")
const RouteBuilder = preload("res://scripts/route.gd")
const PlanetView = preload("res://scripts/planet_view.gd")
const ShipModel = preload("res://scripts/ship_model.gd")
const SUN_DIRECTION: Vector3 = Vector3(-0.78, 0.30, 0.55)
const CYAN: Color = Color(0.18, 0.88, 1.0)
const GOLD: Color = Color(1.0, 0.80, 0.32)

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

const SHIP_CATALOG := [
	{"id": "ASTRA_01", "name": "ASTRA-01", "price": 0, "role": "Starter craft"},
	{"id": "VANGUARD_X", "name": "VANGUARD X", "price": 350, "role": "Balanced interceptor"},
	{"id": "PHANTOM_9", "name": "PHANTOM 9", "price": 900, "role": "High-mobility fighter"},
	{"id": "TITAN_VAEL", "name": "TITAN VAEL", "price": 1800, "role": "Heavy advanced craft"}
]

var time_elapsed: float = 0.0
var camera: Camera3D
var planet_mesh: MeshInstance3D
var cloud_mesh: MeshInstance3D
var ship_root: Node3D
var ship_base: Vector3 = Vector3(1.1, -0.35, -8.0)
var engine_flames: Array = []
var emblem: Control
var panel: PanelContainer
var panel_title: Label
var panel_actions: VBoxContainer
var panel_body: Label
var menu_buttons: Array[Button] = []
var parallax_target: Vector2 = Vector2.ZERO
var parallax_current: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_world()
	_build_ship()
	_build_dust()
	_build_ui()
	menu_buttons[0].grab_focus.call_deferred()


func _process(delta: float) -> void:
	time_elapsed += delta
	var t: float = time_elapsed
	parallax_current = parallax_current.lerp(parallax_target, 1.0 - exp(-3.0 * delta))
	# Camera drifts slowly and follows the mouse a little, so the scene reads as 3D.
	camera.position = Vector3(
		parallax_current.x * 0.7 + sin(t * 0.12) * 0.18,
		0.3 - parallax_current.y * 0.4 + sin(t * 0.17) * 0.07,
		0.0)
	camera.look_at(Vector3(1.6, -0.4, -10.0), Vector3.UP)
	planet_mesh.rotate_y(delta * 0.03)
	cloud_mesh.rotate_y(delta * 0.04)
	ship_root.position = ship_base + Vector3(sin(t * 0.37) * 0.7, sin(t * 0.9) * 0.10, cos(t * 0.23) * 0.5)
	ship_root.rotation_degrees = Vector3(sin(t * 0.8) * 2.0, 18.0 + sin(t * 0.37) * 9.0, -sin(t * 0.37) * 6.0)
	for i in range(engine_flames.size()):
		engine_flames[i].scale = Vector3(1.0, 1.0, 0.92 + 0.14 * sin(t * 38.0 + float(i) * 1.7))
	emblem.queue_redraw()


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		parallax_target = motion.position / viewport_size - Vector2(0.5, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if panel.visible:
			_hide_panel()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 3D backdrop

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/nebula_backdrop.png")
	sky_mat.energy_multiplier = 0.9
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.28, 0.48)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.15
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.25
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = false
	world_env.environment = env
	add_child(world_env)

	# Same sun direction as the flight game, so lit faces agree with the sky glare.
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.9
	sun.shadow_enabled = false
	add_child(sun)

	# Camera-centred star sky (the sphere sits on the origin, the camera barely moves).
	var sky_sphere := MeshInstance3D.new()
	sky_sphere.mesh = _sphere(900.0)
	var sky_shader := ShaderMaterial.new()
	sky_shader.shader = load("res://shaders/star_sky.gdshader") as Shader
	sky_shader.set_shader_parameter("sun_dir", SUN_DIRECTION.normalized())
	sky_sphere.material_override = sky_shader
	add_child(sky_sphere)

	camera = Camera3D.new()
	camera.fov = 55.0
	camera.near = 0.05
	camera.far = 4000.0
	camera.position = Vector3(0.0, 0.3, 0.0)
	add_child(camera)
	camera.current = true

	# Earth, tilted, with clouds and a soft atmosphere.
	var earth_data: Dictionary = RouteBuilder.earth_data()
	earth_data["radius"] = 3.6
	var earth_view: Dictionary = PlanetView.build(earth_data)
	var planet_root: Node3D = earth_view["root"]
	planet_root.position = Vector3(3.8, -1.0, -17.0)
	add_child(planet_root)
	planet_mesh = earth_view["body"]
	cloud_mesh = earth_view["clouds"]


	# A small grey moon in the upper background.
	var moon := MeshInstance3D.new()
	moon.mesh = _sphere(0.9)
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_texture = load("res://assets/moon_surface.png")
	moon_mat.roughness = 0.95
	moon.material_override = moon_mat
	moon.position = Vector3(-2.2, 2.6, -12.0)
	add_child(moon)


func _build_ship() -> void:
	ship_root = Node3D.new()
	ship_root.position = ship_base
	ship_root.rotation_degrees = Vector3(0.0, 18.0, 0.0)
	add_child(ship_root)
	var built: Dictionary = ShipModel.build(ship_root)
	engine_flames = built["flames"]


func _part(mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot_deg
	node.material_override = mat
	ship_root.add_child(node)
	return node


func _build_dust() -> void:
	# Small bright specks drift toward the camera to give the cover depth.
	var dust := CPUParticles3D.new()
	dust.amount = 140
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(9.0, 5.0, 10.0)
	dust.position = Vector3(0.0, 0.0, -9.0)
	dust.direction = Vector3(0.0, 0.0, 1.0)
	dust.spread = 8.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.6
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.2
	dust.local_coords = false
	var speck := SphereMesh.new()
	speck.radius = 0.025
	speck.height = 0.05
	speck.radial_segments = 6
	speck.rings = 3
	var speck_mat := StandardMaterial3D.new()
	speck_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	speck_mat.albedo_color = Color(0.75, 0.88, 1.0)
	speck.material = speck_mat
	dust.mesh = speck
	dust.emitting = true
	add_child(dust)


# ---------------------------------------------------------------- 2D overlay

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Dark fade on the left so the title and emblem read clearly over the 3D scene.
	var shade := Control.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_shade.bind(shade))
	root.add_child(shade)

	# Emblem: glowing ring with the title inside it.
	emblem = Control.new()
	emblem.anchor_left = 0.28
	emblem.anchor_right = 0.28
	emblem.anchor_top = 0.33
	emblem.anchor_bottom = 0.33
	emblem.offset_left = -150.0
	emblem.offset_right = 150.0
	emblem.offset_top = -150.0
	emblem.offset_bottom = 150.0
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(_draw_emblem)
	root.add_child(emblem)

	var title := _cover_label(GAME_TITLE, 40, Color(0.96, 0.99, 1.0))
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.35, 0.55, 0.9))
	emblem.add_child(title)

	var subtitle := _cover_label("THE GALACTIC RESCUE CAMPAIGN", 11, CYAN)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subtitle.anchor_top = 0.62
	subtitle.anchor_bottom = 0.72
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_child(subtitle)

	# Main menu, right of the emblem.
	var menu := VBoxContainer.new()
	menu.anchor_left = 0.71
	menu.anchor_right = 0.71
	menu.anchor_top = 0.22
	menu.anchor_bottom = 0.22
	menu.offset_right = 250.0
	menu.offset_bottom = 320.0
	menu.add_theme_constant_override("separation", 12)
	root.add_child(menu)
	menu_buttons.append(_menu_button(menu, "START GAME", _on_start))
	menu_buttons.append(_menu_button(menu, "LOAD GAME", _on_load))
	menu_buttons.append(_menu_button(menu, "MAP SELECT", _on_map))
	menu_buttons.append(_menu_button(menu, "SETTINGS", _on_settings))
	menu_buttons.append(_menu_button(menu, "ABOUT US", _on_about))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 16.0)
	menu.add_child(spacer)
	menu_buttons.append(_menu_button(menu, "QUIT GAME", _on_quit))

	# Top-right: bookmark (map) and profile (pilot stats).
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.anchor_left = 1.0
	top_row.anchor_right = 1.0
	top_row.offset_left = -128.0
	top_row.offset_right = -24.0
	top_row.offset_top = 22.0
	top_row.offset_bottom = 66.0
	root.add_child(top_row)
	_icon_button(top_row, "bookmark", _on_map)
	_icon_button(top_row, "profile", _on_profile)

	# Bottom-left: settings, about, ship catalog.
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	bottom_row.anchor_top = 1.0
	bottom_row.anchor_bottom = 1.0
	bottom_row.offset_left = 40.0
	bottom_row.offset_right = 320.0
	bottom_row.offset_top = -70.0
	bottom_row.offset_bottom = -24.0
	root.add_child(bottom_row)
	_icon_button(bottom_row, "gear", _on_settings)
	_icon_button(bottom_row, "info", _on_about)
	_icon_button(bottom_row, "ship", _on_ships)

	var version := _cover_label("ASTROVAEL 30.0   ·   ANSWER THE SIGNAL · CROSS THE STARS · BRING THEM HOME", 11, Color(0.43, 0.70, 0.85))
	version.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	version.anchor_top = 1.0
	version.offset_top = -34.0
	version.offset_bottom = -10.0
	version.offset_left = -700.0
	version.offset_right = -24.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(version)

	# Information panel, shared by every menu item.
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(540.0, 0.0)
	var panel_style := _box(Color(0.02, 0.06, 0.10, 0.94), Color(0.0, 0.7, 0.95, 0.8), 8)
	panel_style.set_content_margin_all(22.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.visible = false
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	panel_title = _cover_label("", 20, GOLD)
	column.add_child(panel_title)
	panel_body = _cover_label("", 13, Color(0.82, 0.93, 1.0))
	panel_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.custom_minimum_size = Vector2(490.0, 0.0)
	column.add_child(panel_body)
	panel_actions = VBoxContainer.new()
	panel_actions.add_theme_constant_override("separation", 10)
	column.add_child(panel_actions)
	_menu_button(column, "CLOSE", _hide_panel)


func _draw_shade(shade: Control) -> void:
	var w: float = shade.size.x
	var h: float = shade.size.y
	var points := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w * 0.62, 0.0), Vector2(w * 0.62, h), Vector2(0.0, h)
	])
	var near := Color(0.0, 0.02, 0.05, 0.80)
	var far := Color(0.0, 0.02, 0.05, 0.0)
	shade.draw_polygon(points, PackedColorArray([near, far, far, near]))


func _draw_emblem() -> void:
	var c: Vector2 = emblem.size * 0.5
	var r: float = 116.0
	var t: float = time_elapsed
	# Soft outer glow.
	for i in range(8):
		var alpha: float = 0.20 - float(i) * 0.022
		emblem.draw_arc(c, r + float(i) * 3.5, 0.0, TAU, 128, Color(0.08, 0.85, 1.0, alpha), 2.0, true)
	# Dark glass disc with a lit upper-left edge.
	emblem.draw_circle(c, r - 4.0, Color(0.02, 0.09, 0.16, 0.80))
	emblem.draw_circle(c + Vector2(-26.0, -30.0), r * 0.62, Color(0.10, 0.42, 0.62, 0.14))
	# Rotating segmented ring.
	for k in range(12):
		var start: float = t * 0.6 + float(k) * TAU / 12.0
		emblem.draw_arc(c, r + 18.0, start, start + TAU / 26.0, 6, Color(0.2, 0.95, 1.0, 0.95), 2.5, true)
	# Counter-rotating gold arcs.
	for k in range(3):
		var s2: float = -t * 0.25 + float(k) * TAU / 3.0
		emblem.draw_arc(c, r + 30.0, s2, s2 + TAU * 0.22, 40, Color(1.0, 0.80, 0.32, 0.7), 1.6, true)
	# Marker orbiting the ring.
	var angle: float = t * 0.9
	emblem.draw_circle(c + Vector2(cos(angle), sin(angle)) * (r + 18.0), 4.0, Color(1.0, 0.85, 0.42))


func _draw_icon(icon: Control, kind: String) -> void:
	var c: Vector2 = icon.size * 0.5
	match kind:
		"bookmark":
			icon.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-6.0, -9.0), c + Vector2(6.0, -9.0), c + Vector2(6.0, 9.0),
				c + Vector2(0.0, 4.0), c + Vector2(-6.0, 9.0)
			]), CYAN)
		"profile":
			icon.draw_arc(c + Vector2(0.0, -4.0), 5.0, 0.0, TAU, 24, CYAN, 2.0, true)
			icon.draw_arc(c + Vector2(0.0, 11.0), 9.0, PI, TAU, 24, CYAN, 2.0, true)
		"gear":
			icon.draw_arc(c, 6.0, 0.0, TAU, 32, CYAN, 2.4, true)
			for i in range(8):
				var a: float = float(i) * TAU / 8.0
				var d: Vector2 = Vector2(cos(a), sin(a))
				icon.draw_line(c + d * 7.5, c + d * 10.0, CYAN, 2.6, true)
		"info":
			icon.draw_arc(c, 10.0, 0.0, TAU, 32, CYAN, 1.8, true)
			icon.draw_circle(c + Vector2(0.0, -4.5), 1.6, CYAN)
			icon.draw_line(c + Vector2(0.0, -1.0), c + Vector2(0.0, 5.5), CYAN, 2.2, true)
		"ship":
			icon.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0.0, -10.0), c + Vector2(7.0, 8.0), c + Vector2(0.0, 4.0), c + Vector2(-7.0, 8.0)
			]), CYAN)


func _icon_button(parent: Container, kind: String, handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _round_box(Color(0.03, 0.14, 0.22, 0.72), Color(0.0, 0.7, 0.95, 0.6)))
	button.add_theme_stylebox_override("hover", _round_box(Color(0.24, 0.17, 0.02, 0.75), GOLD))
	button.add_theme_stylebox_override("pressed", _round_box(Color(0.30, 0.21, 0.03, 0.9), GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := Control.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, kind))
	button.add_child(icon)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _menu_button(parent: Container, caption: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(240.0, 40.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _box(Color(0.02, 0.14, 0.22, 0.55), Color(0.0, 0.7, 0.95, 0.55)))
	button.add_theme_stylebox_override("hover", _box(Color(0.24, 0.17, 0.02, 0.7), GOLD))
	button.add_theme_stylebox_override("focus", _box(Color(0.24, 0.17, 0.02, 0.7), GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color(0.30, 0.21, 0.03, 0.85), GOLD))
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


# ---------------------------------------------------------------- actions

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/Station.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _on_map() -> void:
	_show_panel("MAP SELECT",
		"THE ROUTE NEVER ENDS\n"
		+ "Start at Earth. The first stop is VENUS, 38.1 million km away.\n"
		+ "Then MARS, JUPITER, SATURN, URANUS and NEPTUNE.\n\n"
		+ "After Neptune the ship warps into a new galaxy. Each galaxy has its own\n"
		+ "sky, and every planet changes the air, light and fog as you pass it.\n\n"
		+ "Every 50 million km a BLACK HOLE opens ahead. Enter it and reach the next destination in 1 minute.\n\n"
		+ "The NEAREST PLANET box shows the million km you have travelled and the million km to go.")


func _on_settings() -> void:
	_show_panel("SETTINGS",
		"CONTROLS\n"
		+ "A / LEFT        steer left\n"
		+ "D / RIGHT       steer right\n"
		+ "SPACE           boost\n"
		+ "F               fire\n"
		+ "TAB             show or hide the route ahead\n"
		+ "ESC             pause and resume\n"
		+ "M               return to this cover (when paused or after a crash)\n"
		+ "R               redeploy after a crash\n\n"
		+ "Audio and display options arrive in a later version.")


func _on_about() -> void:
	_show_panel("ABOUT US",
		"ASTROVAEL is an endless space flight game. There is no finish line. "
		+ "Fly past the planets of the solar system, cross into new galaxies and keep going. "
		+ "Dodge asteroid fields, shoot down hostile craft and collect diamonds as you travel.\n\n"
		+ "Version 30.0 is the endless remake, with speed options and black holes.")


func _on_profile() -> void:
	var data: Dictionary = SaveData.load_data()
	_show_panel("PILOT PROFILE",
		"PERSONAL BEST      %s million km\n" % ("%.2f" % (float(int(data.get("best_miles", 0))) * 1.609344 / 1000000.0))
		+ "TOTAL ENERGY       %s\n" % _commas(int(data.get("total_energy", 0)))
		+ "DIAMONDS           %s\n\n" % _commas(int(data.get("total_diamonds", 0)))
		+ "These values come from your saved progress and update after each flight.")


func _commas(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _on_load() -> void:
	_show_panel("LOAD GAME", "Choose a save slot. The ship continues from the exact place it was saved.")
	for slot in range(1, 4):
		var info: Dictionary = SaveData.read_slot(slot)
		var label: String = "SLOT %d   ·   EMPTY" % slot
		if not info.is_empty():
			label = "SLOT %d   ·   %s   ·   %s" % [slot, info["summary"], info["saved_at"]]
		var button := _menu_button(panel_actions, label, _on_load_slot.bind(slot))
		button.disabled = info.is_empty()


func _on_load_slot(slot: int) -> void:
	SaveData.pending_slot = slot
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_ships() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for entry in SHIP_CATALOG:
		var price_text: String = "FREE" if int(entry["price"]) == 0 else "%d diamonds" % int(entry["price"])
		lines.append("%s   ·   %s   ·   %s" % [String(entry["name"]), String(entry["role"]), price_text])
	lines.append("")
	lines.append("Buying ships arrives in a later version. ASTRA-01 is the craft you fly now.")
	_show_panel("SHIP CATALOG", "\n".join(lines))


func _show_panel(title_text: String, body_text: String) -> void:
	for child in panel_actions.get_children():
		panel_actions.remove_child(child)
		child.queue_free()
	panel_title.text = title_text
	panel_body.text = body_text
	panel.visible = true


func _hide_panel() -> void:
	panel.visible = false


# ---------------------------------------------------------------- helpers

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 96
	mesh.rings = 48
	return mesh


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _shader_from(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader


func _box(background: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _round_box(background: Color, border: Color) -> StyleBoxFlat:
	var style := _box(background, border, 22)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _cover_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
