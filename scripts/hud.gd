extends CanvasLayer
# Flight HUD. Two panels: FLIGHT SYSTEM (left) and NEAREST PLANET (right).
# The arrow on each panel's header folds it to a short view and opens it again.
# The cockpit frame appears in pilot view. Menus, countdown and messages are shared with main.gd.

signal pause_pressed
signal speed_selected(index: int)
signal menu_choice(id: String)

const UniverseMap = preload("res://scripts/universe_map.gd")
const TEXT: Color = Color(0.90, 0.86, 0.78)
const ACCENT: Color = Color(0.96, 0.76, 0.50)
const GOLD: Color = Color(0.98, 0.84, 0.58)
const MUTED: Color = Color(0.70, 0.66, 0.60)
const SPEED_NAMES: Array = ["SLOW", "MEDIUM", "FAST"]
const UNIT_KM: float = 1609.344
const MAP_OPEN: float = 200.0
const MAP_FOLDED: float = 150.0
const FADE_TIME: float = 0.25

var touch_left: bool = false
var touch_right: bool = false
var touch_boost: bool = false
var touch_fire: bool = false

var left_panel: PanelContainer
var right_panel: PanelContainer
var left_arrow: Button
var right_arrow: Button
var left_open: bool = true
var right_open: bool = true
var left_folding: Array = []
var right_folding: Array = []

var speed_label: Label
var speed_right: Label
var travelled_label: Label
var energy_label: Label
var diamond_label: Label
var best_label: Label
var boost_title: Label
var boost_bar: ProgressBar
var map_title: Label
var map_view
var map_readout: Label
var map_toggle: Button
var planet_name: Label
var planet_type: Label
var planet_facts: Label
var arrive_box: Label
var travelled_box: Label
var progress_bar: ProgressBar
var right_separator: HSeparator
var speed_button: Button
var speed_row: HBoxContainer
var speed_buttons: Array = []
var route_panel: PanelContainer
var route_label: Label
var message_label: Label
var big_label: Label
var pause_button: Button
var flash_rect: ColorRect
var flash_alpha: float = 0.0
var cockpit: Control
var cockpit_on: bool = false
var cockpit_state: Dictionary = {}
var last_remaining: String = ""
var menu_panel: PanelContainer
var menu_title: Label
var menu_body: Label
var menu_options: VBoxContainer
var balance_label: Label
var hull_bar: ProgressBar
var mission_label: Label
var alarm_on: bool = false
var alarm_time: float = 0.0


# Distances in million km. units = route units (1 unit = 1,000 miles).
static func million_km(units: float) -> String:
	return "%.2f million km" % (units * UNIT_KM / 1000000.0)


# Speed in km/s. units_per_second = route units per second.
static func speed_km(units_per_second: float) -> String:
	return "%s km/s" % commas(int(round(units_per_second * UNIT_KM)))


static func commas(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out


func _ready() -> void:
	layer = 6
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0.95, 0.88, 0.78, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	cockpit = Control.new()
	cockpit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cockpit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cockpit.visible = false
	cockpit.draw.connect(_draw_cockpit)
	root.add_child(cockpit)

	_build_left(root)
	_build_right(root)

	# Route list, toggled with TAB.
	route_panel = PanelContainer.new()
	route_panel.add_theme_stylebox_override("panel", _panel_style(16.0))
	route_panel.anchor_left = 1.0
	route_panel.anchor_right = 1.0
	route_panel.offset_left = -344.0
	route_panel.offset_right = -24.0
	route_panel.offset_top = 330.0
	route_panel.visible = false
	root.add_child(route_panel)
	var route_col := VBoxContainer.new()
	route_panel.add_child(route_col)
	route_col.add_child(_label("ROUTE AHEAD   (TAB)", 11, ACCENT))
	route_label = _label("", 13, TEXT)
	route_col.add_child(route_label)

	# Centre message.
	message_label = _label("", 17, ACCENT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.offset_left = -330.0
	message_label.offset_right = 330.0
	message_label.offset_top = 120.0
	message_label.custom_minimum_size = Vector2(660.0, 0.0)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(message_label)

	# Big countdown / repair text in the middle of the screen.
	big_label = _label("", 72, GOLD)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_label.anchor_left = 0.5
	big_label.anchor_right = 0.5
	big_label.anchor_top = 0.5
	big_label.anchor_bottom = 0.5
	big_label.offset_left = -240.0
	big_label.offset_right = 240.0
	big_label.offset_top = -80.0
	big_label.offset_bottom = 80.0
	root.add_child(big_label)

	# Mission line under the top centre.
	mission_label = _label("", 12, ACCENT)
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.anchor_left = 0.5
	mission_label.anchor_right = 0.5
	mission_label.offset_left = -300.0
	mission_label.offset_right = 300.0
	mission_label.offset_top = 60.0
	root.add_child(mission_label)
	# Pause / options button at the top centre.
	pause_button = Button.new()
	pause_button.text = "II  PAUSE"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.anchor_left = 0.5
	pause_button.anchor_right = 0.5
	pause_button.offset_left = -70.0
	pause_button.offset_right = 70.0
	pause_button.offset_top = 22.0
	pause_button.offset_bottom = 56.0
	pause_button.add_theme_font_size_override("font_size", 13)
	pause_button.add_theme_color_override("font_color", TEXT)
	pause_button.add_theme_stylebox_override("normal", _panel_style(8.0))
	pause_button.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_button)

	# Touch controls, bottom left.
	var touch := HBoxContainer.new()
	touch.add_theme_constant_override("separation", 10)
	touch.anchor_top = 1.0
	touch.anchor_bottom = 1.0
	touch.offset_left = 24.0
	touch.offset_right = 460.0
	touch.offset_top = -74.0
	touch.offset_bottom = -22.0
	root.add_child(touch)
	_touch_button(touch, "LEFT", func(v: bool): touch_left = v)
	_touch_button(touch, "RIGHT", func(v: bool): touch_right = v)
	_touch_button(touch, "BOOST", func(v: bool): touch_boost = v)
	_touch_button(touch, "FIRE", func(v: bool): touch_fire = v)

	# Key hints, bottom right.
	var hint := _label("A / D steer   ·   SPACE boost   ·   F fire   ·   TAB route   ·   ESC pause   ·   M menu", 11, MUTED)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -760.0
	hint.offset_right = -24.0
	hint.offset_top = -34.0
	hint.offset_bottom = -12.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	# Menus (pause, crash, save slots). Shown in the middle of the screen.
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _panel_style(22.0))
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu_panel.custom_minimum_size = Vector2(480.0, 0.0)
	menu_panel.visible = false
	root.add_child(menu_panel)
	var menu_col := VBoxContainer.new()
	menu_col.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_col)
	menu_title = _label("", 20, GOLD)
	menu_col.add_child(menu_title)
	menu_body = _label("", 13, TEXT)
	menu_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_body.custom_minimum_size = Vector2(440.0, 0.0)
	menu_col.add_child(menu_body)
	menu_options = VBoxContainer.new()
	menu_options.add_theme_constant_override("separation", 8)
	menu_col.add_child(menu_options)


func _build_left(root: Control) -> void:
	left_panel = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", _panel_style(16.0))
	left_panel.position = Vector2(24.0, 22.0)
	left_panel.custom_minimum_size = Vector2(300.0, 0.0)
	root.add_child(left_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	left_panel.add_child(col)

	var header := HBoxContainer.new()
	var title := _label("FLIGHT SYSTEM", 11, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	left_arrow = _arrow_button(_on_left_arrow)
	header.add_child(left_arrow)
	col.add_child(header)

	speed_label = _label("", 15, TEXT)
	col.add_child(speed_label)
	# Energy and diamonds sit side by side to keep the folded view short.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 12)
	energy_label = _label("", 13, TEXT)
	energy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(energy_label)
	diamond_label = _label("", 13, TEXT)
	diamond_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(diamond_label)
	col.add_child(pair)
	travelled_label = _label("", 13, TEXT)
	col.add_child(travelled_label)
	best_label = _label("", 12, MUTED)
	col.add_child(best_label)
	balance_label = _label("", 13, GOLD)
	col.add_child(balance_label)
	col.add_child(_label("HULL", 11, ACCENT))
	hull_bar = _bar(Color(0.55, 0.85, 0.6))
	col.add_child(hull_bar)

	boost_title = _label("BOOST", 11, ACCENT)
	col.add_child(boost_title)
	boost_bar = _bar(ACCENT)
	col.add_child(boost_bar)

	map_title = _label("UNIVERSE MAP   (drag to turn · wheel to zoom)", 11, ACCENT)
	col.add_child(map_title)
	map_view = UniverseMap.new()
	map_view.custom_minimum_size = Vector2(260.0, MAP_OPEN)
	col.add_child(map_view)
	map_readout = _label("", 11, TEXT)
	col.add_child(map_readout)
	map_toggle = Button.new()
	map_toggle.text = "SHOW WHOLE ROUTE"
	map_toggle.focus_mode = Control.FOCUS_NONE
	map_toggle.add_theme_font_size_override("font_size", 12)
	map_toggle.add_theme_color_override("font_color", TEXT)
	map_toggle.add_theme_stylebox_override("normal", _row_style())
	map_toggle.add_theme_stylebox_override("hover", _row_style())
	map_toggle.pressed.connect(_on_map_toggle)
	col.add_child(map_toggle)

	left_folding = [boost_title, boost_bar, map_title, map_readout, map_toggle]


func _build_right(root: Control) -> void:
	right_panel = PanelContainer.new()
	right_panel.add_theme_stylebox_override("panel", _panel_style(16.0))
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.offset_left = -344.0
	right_panel.offset_right = -24.0
	right_panel.offset_top = 22.0
	right_panel.custom_minimum_size = Vector2(320.0, 0.0)
	root.add_child(right_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	right_panel.add_child(col)

	var header := HBoxContainer.new()
	var title := _label("NEAREST PLANET", 11, ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	right_arrow = _arrow_button(_on_right_arrow)
	header.add_child(right_arrow)
	col.add_child(header)

	planet_name = _label("", 24, GOLD)
	col.add_child(planet_name)
	planet_type = _label("", 13, TEXT)
	col.add_child(planet_type)
	planet_facts = _label("", 12, MUTED)
	col.add_child(planet_facts)
	right_separator = HSeparator.new()
	col.add_child(right_separator)

	# TO ARRIVE and SPEED sit side by side, so the folded view stays short.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 10)
	arrive_box = _label("", 13, GOLD)
	arrive_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(arrive_box)
	speed_right = _label("", 13, TEXT)
	pair.add_child(speed_right)
	col.add_child(pair)

	travelled_box = _label("", 14, TEXT)
	col.add_child(travelled_box)
	progress_bar = _bar(GOLD)
	col.add_child(progress_bar)

	# Speed setting. Hidden until the line is clicked; choosing a speed hides the options again.
	speed_button = Button.new()
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	speed_button.add_theme_font_size_override("font_size", 13)
	speed_button.add_theme_color_override("font_color", TEXT)
	speed_button.add_theme_stylebox_override("normal", _row_style())
	speed_button.add_theme_stylebox_override("hover", _row_style())
	speed_button.add_theme_stylebox_override("pressed", _row_style())
	speed_button.pressed.connect(_toggle_speed_options)
	col.add_child(speed_button)
	speed_row = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	speed_row.visible = false
	col.add_child(speed_row)
	for i in range(SPEED_NAMES.size()):
		var option := Button.new()
		option.text = SPEED_NAMES[i]
		option.focus_mode = Control.FOCUS_NONE
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.add_theme_font_size_override("font_size", 12)
		option.add_theme_stylebox_override("normal", _row_style())
		option.add_theme_stylebox_override("hover", _row_style())
		option.pressed.connect(_pick_speed.bind(i))
		speed_row.add_child(option)
		speed_buttons.append(option)
	set_speed_level(0)

	right_folding = [planet_type, planet_facts, right_separator, travelled_box, progress_bar, speed_button]


func _process(delta: float) -> void:
	if alarm_on:
		alarm_time += delta
		var pulse: float = 0.5 + 0.5 * sin(alarm_time * 6.0)
		flash_rect.color = Color(0.9, 0.08, 0.05, 0.12 + 0.2 * pulse)
	elif flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - delta * 0.6)
		flash_rect.color = Color(0.95, 0.88, 0.78, flash_alpha)
	if cockpit_on:
		cockpit.queue_redraw()


func update(d: Dictionary) -> void:
	var speed_text: String = String(d.get("speed_text", ""))
	speed_label.text = speed_text
	speed_right.text = speed_text
	travelled_label.text = "TRAVELLED   %s" % d.get("travelled_text", "0")
	energy_label.text = "ENERGY   %s" % d.get("energy_text", "0")
	diamond_label.text = "DIAMONDS   %s" % d.get("diamonds_text", "0")
	best_label.text = "PERSONAL BEST   %s" % d.get("best_text", "0")
	boost_bar.value = float(d.get("boost_ratio", 1.0)) * 100.0
	balance_label.text = "BALANCE   $%s" % d.get("balance_text", "0")
	hull_bar.value = float(d.get("hull_ratio", 1.0)) * 100.0

	var planet: Dictionary = d.get("planet", {})
	planet_name.text = String(planet.get("name", ""))
	planet_type.text = String(planet.get("type", ""))
	planet_facts.text = "GRAVITY %.2f g   ·   SURFACE %d °C\nMOONS %d   ·   %s" % [
		float(planet.get("gravity", 0.0)), int(planet.get("temp", 0)),
		int(planet.get("moons", 0)), String(planet.get("galaxy_name", ""))]
	travelled_box.text = "TRAVELLED   %s" % d.get("travelled_text", "0")
	arrive_box.text = "TO ARRIVE   %s" % d.get("remaining_text", "0")
	last_remaining = String(d.get("remaining_text", "0"))
	progress_bar.value = float(d.get("progress", 0.0)) * 100.0

	var lines: Array = d.get("route_lines", [])
	route_label.text = "\n".join(PackedStringArray(lines))


func set_route(route) -> void:
	map_view.route = route


func set_map_state(s: Dictionary) -> void:
	map_view.update_state(s)
	map_readout.text = map_view.readout()


func set_cockpit(on: bool) -> void:
	cockpit_on = on
	if on:
		_set_shown(cockpit, true)
	else:
		cockpit.visible = false


func set_cockpit_state(s: Dictionary) -> void:
	cockpit_state = s


func set_mission_line(text: String) -> void:
	mission_label.text = text


func set_alarm(on: bool) -> void:
	alarm_on = on
	alarm_time = 0.0
	if not on:
		flash_rect.color = Color(0.95, 0.88, 0.78, 0.0)


func set_message(text: String) -> void:
	message_label.text = text


func show_big(text: String) -> void:
	big_label.text = text


func set_flash(alpha: float) -> void:
	flash_alpha = maxf(flash_alpha, alpha)


func toggle_route() -> void:
	route_panel.visible = not route_panel.visible


func set_pause_text(text: String) -> void:
	pause_button.text = text


func set_speed_level(index: int) -> void:
	speed_button.text = "SPEED  ·  %s   (click to change)" % SPEED_NAMES[index]
	for i in range(speed_buttons.size()):
		var option: Button = speed_buttons[i]
		var color: Color = GOLD if i == index else TEXT
		option.add_theme_color_override("font_color", color)
		option.add_theme_color_override("font_hover_color", GOLD)


# options: Array of {"id": String, "text": String, "enabled": bool}
func show_menu(title_text: String, body_text: String, options: Array) -> void:
	menu_title.text = title_text
	menu_body.text = body_text
	for child in menu_options.get_children():
		menu_options.remove_child(child)
		child.queue_free()
	for opt in options:
		var button := Button.new()
		button.text = String(opt["text"])
		button.disabled = not bool(opt.get("enabled", true))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(440.0, 40.0)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", TEXT)
		button.add_theme_color_override("font_hover_color", GOLD)
		button.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
		button.add_theme_stylebox_override("normal", _row_style())
		button.add_theme_stylebox_override("hover", _row_style())
		button.add_theme_stylebox_override("disabled", _row_style())
		button.pressed.connect(_emit_choice.bind(String(opt["id"])))
		menu_options.add_child(button)
	menu_panel.visible = true


func hide_menu() -> void:
	menu_panel.visible = false


func _emit_choice(id: String) -> void:
	menu_choice.emit(id)


# ---------------------------------------------------------------- folding panels

func _on_left_arrow() -> void:
	left_open = not left_open
	left_arrow.text = "^" if left_open else "v"
	map_view.custom_minimum_size = Vector2(260.0, MAP_OPEN if left_open else MAP_FOLDED)
	for node in left_folding:
		_set_shown(node, left_open)


func _on_right_arrow() -> void:
	right_open = not right_open
	right_arrow.text = "^" if right_open else "v"
	for node in right_folding:
		_set_shown(node, right_open)
	if not right_open:
		speed_row.visible = false


func _on_map_toggle() -> void:
	var following: bool = map_view.toggle_follow()
	map_toggle.text = "SHOW WHOLE ROUTE" if following else "FOLLOW THE SHIP"


func _set_shown(node: CanvasItem, shown: bool) -> void:
	if shown:
		node.visible = true
		node.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, FADE_TIME)
	else:
		node.visible = false


func _arrow_button(handler: Callable) -> Button:
	var button := Button.new()
	button.text = "^"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(28.0, 24.0)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", ACCENT)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _row_style())
	button.add_theme_stylebox_override("pressed", _row_style())
	button.pressed.connect(handler)
	return button


# ---------------------------------------------------------------- cockpit frame

func _draw_cockpit() -> void:
	var w: float = cockpit.size.x
	var h: float = cockpit.size.y
	var t: float = Time.get_ticks_msec() / 1000.0
	var frame := Color(0.04, 0.034, 0.03, 0.95)
	var edge := Color(0.55, 0.42, 0.28, 0.55)
	var amber := Color(0.98, 0.76, 0.48)
	var font: Font = ThemeDB.fallback_font
	var bank: float = float(cockpit_state.get("bank", 0.0))
	var pitch: float = float(cockpit_state.get("pitch", 0.0))
	var speed_norm: float = float(cockpit_state.get("speed_norm", 0.0))
	var boosting: bool = bool(cockpit_state.get("boosting", false))
	var pulse: float = 0.5 + 0.5 * sin(t * 2.0)

	# Canopy: side struts and the top frame.
	cockpit.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w * 0.085, 0.0), Vector2(w * 0.035, h), Vector2(0.0, h)]), frame)
	cockpit.draw_colored_polygon(PackedVector2Array([
		Vector2(w, 0.0), Vector2(w * 0.915, 0.0), Vector2(w * 0.965, h), Vector2(w, h)]), frame)
	cockpit.draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, h * 0.05), Vector2(0.0, h * 0.05)]), frame)

	# Glass reflection that slides slowly across the canopy.
	var sheen_x: float = fposmod(t * 0.12, 1.0) * w * 1.6 - w * 0.3
	cockpit.draw_colored_polygon(PackedVector2Array([
		Vector2(sheen_x, 0.0), Vector2(sheen_x + w * 0.12, 0.0),
		Vector2(sheen_x + w * 0.02, h * 0.6), Vector2(sheen_x - w * 0.1, h * 0.6)]), Color(0.9, 0.95, 1.0, 0.04))

	# Dashboard with a glowing top edge.
	cockpit.draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.035, h), Vector2(w * 0.965, h), Vector2(w * 0.8, h * 0.8), Vector2(w * 0.2, h * 0.8)]), frame)
	cockpit.draw_line(Vector2(w * 0.2, h * 0.8), Vector2(w * 0.8, h * 0.8),
		Color(edge.r, edge.g, edge.b, 0.35 + 0.35 * pulse), 2.0, true)

	# Left screen: attitude. The galactic plane is the horizon: it tilts with the bank and moves with the pitch.
	var left_rect := Rect2(w * 0.17, h * 0.84, w * 0.14, h * 0.13)
	_draw_screen(left_rect, font, "ATTITUDE")
	var lc: Vector2 = left_rect.get_center() + Vector2(0.0, 6.0)
	var radius: float = left_rect.size.y * 0.42
	var d := Vector2(cos(bank), sin(bank))
	var n := Vector2(-sin(bank), cos(bank))
	var off: float = clampf(pitch * radius * 12.0, -radius, radius)
	var mid: Vector2 = lc + n * off
	var half: float = sqrt(maxf(0.0, radius * radius - off * off))
	cockpit.draw_line(mid - d * half, mid + d * half, amber, 1.6, true)
	cockpit.draw_line(lc + Vector2(-14.0, 0.0), lc + Vector2(-5.0, 0.0), amber, 2.0, true)
	cockpit.draw_line(lc + Vector2(5.0, 0.0), lc + Vector2(14.0, 0.0), amber, 2.0, true)

	# Centre screen: speed and throttle.
	var mid_rect := Rect2(w * 0.37, h * 0.84, w * 0.26, h * 0.13)
	_draw_screen(mid_rect, font, "SPEED")
	cockpit.draw_string(font, mid_rect.position + Vector2(10.0, 46.0), speed_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, mid_rect.size.x - 20.0, 22, amber)
	var bar := Rect2(mid_rect.position + Vector2(10.0, mid_rect.size.y - 14.0), Vector2(mid_rect.size.x - 20.0, 7.0))
	cockpit.draw_rect(bar, Color(0.12, 0.1, 0.08, 0.9))
	var bar_color: Color = Color(1.0, 0.6, 0.3, 0.95) if boosting else Color(0.98, 0.8, 0.5, 0.9)
	cockpit.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(speed_norm, 0.0, 1.0), bar.size.y)), bar_color)

	# Right screen: bearing to the next stop, shown as a tape with the stop at the centre marker.
	var right_rect := Rect2(w * 0.67, h * 0.84, w * 0.14, h * 0.13)
	_draw_screen(right_rect, font, "")
	var rel: float = float(map_view.relative_bearing())
	var cx: float = right_rect.get_center().x
	var tape_y: float = right_rect.position.y + right_rect.size.y * 0.58
	var px_per_deg: float = right_rect.size.x / 80.0
	for k in range(-9, 10):
		var deg: float = float(k) * 10.0
		var x: float = cx + (deg - rel) * px_per_deg
		if absf(x - cx) > right_rect.size.x * 0.5 - 6.0:
			continue
		cockpit.draw_line(Vector2(x, tape_y), Vector2(x, tape_y - 7.0), edge, 1.0, true)
	cockpit.draw_colored_polygon(PackedVector2Array([
		Vector2(cx, tape_y + 1.0), Vector2(cx - 4.0, tape_y + 8.0), Vector2(cx + 4.0, tape_y + 8.0)]), amber)
	cockpit.draw_string(font, right_rect.position + Vector2(6.0, 14.0), "NEXT  " + planet_name.text,
		HORIZONTAL_ALIGNMENT_LEFT, right_rect.size.x - 12.0, 10, amber)
	cockpit.draw_string(font, Vector2(right_rect.position.x + 6.0, right_rect.end.y - 6.0),
		"%+.0f°  ·  %s" % [rel, last_remaining], HORIZONTAL_ALIGNMENT_LEFT, right_rect.size.x - 12.0, 9, MUTED)

	# Edge highlights and a centre reticle that glows while boosting.
	cockpit.draw_line(Vector2(w * 0.085, 0.0), Vector2(w * 0.035, h), edge, 1.5, true)
	cockpit.draw_line(Vector2(w * 0.915, 0.0), Vector2(w * 0.965, h), edge, 1.5, true)
	cockpit.draw_line(Vector2(0.0, h * 0.05), Vector2(w, h * 0.05), edge, 1.5, true)
	var c := Vector2(w * 0.5, h * 0.45)
	var reticle := Color(0.95, 0.8, 0.55, 0.3 + (0.35 * pulse if boosting else 0.0))
	cockpit.draw_line(c + Vector2(-12.0, 0.0), c + Vector2(-4.0, 0.0), reticle, 1.5, true)
	cockpit.draw_line(c + Vector2(4.0, 0.0), c + Vector2(12.0, 0.0), reticle, 1.5, true)
	cockpit.draw_line(c + Vector2(0.0, -12.0), c + Vector2(0.0, -4.0), reticle, 1.5, true)
	cockpit.draw_line(c + Vector2(0.0, 4.0), c + Vector2(0.0, 12.0), reticle, 1.5, true)


func _draw_screen(rect: Rect2, font: Font, title_text: String) -> void:
	cockpit.draw_rect(rect, Color(0.05, 0.04, 0.03, 0.88))
	cockpit.draw_rect(rect, Color(0.85, 0.65, 0.4, 0.5), false, 1.0)
	if title_text != "":
		cockpit.draw_string(font, rect.position + Vector2(6.0, 14.0), title_text,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12.0, 10, MUTED)


# ---------------------------------------------------------------- speed setting

func _toggle_speed_options() -> void:
	speed_row.visible = not speed_row.visible


func _pick_speed(index: int) -> void:
	speed_row.visible = false
	speed_selected.emit(index)


# ---------------------------------------------------------------- style helpers

func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.72)
	style.border_color = Color(0.85, 0.65, 0.40, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _panel_style(margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.045, 0.84)
	style.border_color = Color(0.85, 0.65, 0.40, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.14, 0.11, 0.09, 0.9)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _touch_button(parent: Container, caption: String, setter: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(96.0, 48.0)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(8.0))
	button.button_down.connect(func(): setter.call(true))
	button.button_up.connect(func(): setter.call(false))
	parent.add_child(button)
