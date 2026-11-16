extends Node3D
# ASTROVAEL 30.0 - endless flight.
#
# The ship and camera stay near the origin and the universe moves past them. Every object keeps its
# route position (a double-precision number) and its scene position is rebuilt each frame relative
# to the ship. This keeps the scene precise however far the ship travels, and the route never ends.
#
# Route:  one unit = 1,000 miles. Stops are planets in order (Venus first). Each planet has a
#         "lane" offset, so the ship flies past it rather than through it. When the ship passes a
#         planet, the environment blends to the next one. Every six stops the ship enters a warp
#         segment and arrives in a new galaxy with a new sky.

const RouteBuilder = preload("res://scripts/route.gd")
const HudScript = preload("res://scripts/hud.gd")
const PlanetView = preload("res://scripts/planet_view.gd")
const ShipModel = preload("res://scripts/ship_model.gd")
const SaveData = preload("res://scripts/save_data.gd")

const COVER_SCENE: String = "res://scenes/Cover.tscn"
const UNIT_MILES: float = 1000.0
const CRUISE_SPEED: float = 120.0          # 120,000 mi/s
const BOOST_SPEED: float = 170.0           # 170,000 mi/s
const WARP_SPEED: float = 260.0            # warp segment between galaxies
const SHIP_RESTING_Y: float = 0.85
const SIDE_LIMIT: float = 7.8
const SIDE_RESPONSE: float = 8.5
const TILE_LENGTH: float = 100.0
const TILES_BEHIND: int = 2
const TILES_AHEAD: int = 16
const PASS_MARGIN: float = 60.0
const ZONE_RANGE: float = 2200.0
const SKY_RADIUS: float = 24000.0
const FAR_PLANE: float = 26000.0
const HAZARD_RADIUS: float = 1.45
const PICKUP_RADIUS: float = 1.05
const ALIEN_RADIUS: float = 2.15
const SHIP_RADIUS: float = 1.0
const BOLT_RADIUS: float = 0.42
const BOLT_SPEED: float = 105.0
const ALIEN_SPEED: float = 13.5
const LANES := [-5.2, 0.0, 5.2]
const SUN_DIRECTION: Vector3 = Vector3(-0.78, 0.30, 0.55)
const BASE_AMBIENT: Color = Color(0.30, 0.27, 0.24)
# Speed levels for the whole universe: 0 = Slow, 1 = Medium, 2 = Fast.
const SPEED_SCALES: Array = [0.45, 0.7, 1.0]
# Black holes: one every 50 million km of travel (50e6 km / 1,609.344 km per unit).
const BH_INTERVAL_UNITS: float = 50000000.0 / 1609.344
# A black hole always carries the ship at least 29 million km, so the jump is always very fast.
const BH_JUMP_MIN_UNITS: float = 18000.0
const BH_TRANSIT_SECONDS: float = 60.0
const QUICK_SECONDS: float = 1.0
const RescueSurface = preload("res://scripts/rescue_surface.gd")
const RaiderModel = preload("res://scripts/raider_model.gd")
const SoundMixer = preload("res://scripts/sound_mixer.gd")
const CampaignScript = preload("res://scripts/campaign.gd")
const StationModel = preload("res://scripts/station_model.gd")
const MISSION_RESCUE_RANGE: float = 1500.0
const MISSION_REWARD: int = 10000
const BRIEF_SECONDS: float = 4.5
const LANDING_SECONDS: float = 24.0
const TAKEOFF_SECONDS: float = 26.0
const PASSED_DELAY: float = 4.0
const ALARM_SECONDS: float = 3.5
const FAIL_DELAY: float = 3.0
const LANDED_Y: float = -4.1
const SHADOWS_ENABLED: bool = true
const AIRSPACE_SPEED: float = 18.0
const AIRSPACE_STOP: float = 800.0
const ENEMY_HIT_DAMAGE: float = 9.0
const HULL_MAX: float = 100.0
const REPAIR_HULL: float = 60.0
const ALT_LIMIT: float = 2.5
const BATTLE_Y: float = -1.3
const MISSION_SPEED_FACTOR: float = 0.6
const STATION_BEHIND_Z: float = 55.0
const CURVE_AMPLITUDE: float = 5.0
const DEPART_SECONDS: float = 8.0
const DEPART_SPEED: float = 40.0
const RETURN_SECONDS: float = 14.0
const RETURN_SPEED: float = 260.0
const DOCK_SECONDS: float = 12.0
const DOCK_SPEED: float = 20.0

var route
var rng := RandomNumberGenerator.new()
var hud
var env: Environment
var sun: DirectionalLight3D
var sky_sphere: MeshInstance3D
var sky_material: ShaderMaterial
var ship: Node3D
var ship_flames: Array = []
var camera: Camera3D
var streaks: CPUParticles3D
var rock_material: StandardMaterial3D
var station_material: StandardMaterial3D

var movers: Array = []
var tile_entries: Dictionary = {}
var planet_entries: Dictionary = {}
var hazards: Array = []
var pickups: Array = []
var aliens: Array = []
var bolts: Array = []

var ship_route_z: float = 0.0
var nearest_index: int = 0
var palette_galaxy: int = 0
var current_palette: Dictionary = {}
var target_palette: Dictionary = {}
var zone_density: float = 0.0
var zone_fog: Color = Color(0.5, 0.5, 0.5)
var zone_ambient: Color = BASE_AMBIENT
var warp_active: bool = false
var current_speed: float = CRUISE_SPEED
var steer_value: float = 0.0
var target_x: float = 0.0
var boost_energy: float = 100.0
var boost_active: bool = false
var energy: int = 0
var total_energy: int = 0
var total_diamonds: int = 0
var best_miles: int = 0
var fire_cooldown: float = 0.0
var hazard_clock: float = 0.0
var pickup_clock: float = 0.0
var alien_clock: float = 0.0
var game_over: bool = false
var paused: bool = false
var shake: float = 0.0
var elapsed: float = 0.0
var message_time: float = 0.0
var speed_level: int = 0
var time_scale: float = 0.45
var bh_state: String = "none"
var bh_units: float = 0.0
var bh_dest: int = 0
var next_bh_units: float = BH_INTERVAL_UNITS
var transit_start: float = 0.0
var transit_distance: float = 0.0
var transit_timer: float = 0.0
var black_hole_entry: Dictionary = {}
var black_hole_disk: MeshInstance3D = null
var repair_phase: String = ""
var repair_timer: float = 0.0
var repair_ring: MeshInstance3D = null
var repair_sparks: CPUParticles3D = null
var save_return: String = "pause_menu"
var camera_roll: float = 0.0
var pilot_view: bool = false
var sound: Node = null
var quick_start: float = 0.0
var quick_distance: float = 0.0
var quick_timer: float = 0.0
var quick_dest: int = 0
var mission_phase: String = "brief"
var mission_timer: float = 0.0
var mission_target: int = 0
var mission_start_units: float = 0.0
var mission_start_nearest: int = 0
var mission_clock: float = 0.0
var missions_done: int = 0
var balance: int = 0
var surface = null
var ship_base_y: float = SHIP_RESTING_Y
var surface_impacts_seen: int = 0
var hull: float = HULL_MAX
var alt_offset: float = 0.0
var airspace_left: int = 0
var airspace_spawn_timer: float = 0.0
var enemy_beams: Array = []
var ship_nav: Array = []
var station_entry: Dictionary = {}
var station_windows: Array = []
var station_beacons: Array = []
var mission_side: float = 1.0
var mission_auto_x: float = 0.0
var mission_auto_bank: float = 0.0
var mission_travel_seconds: float = 0.0
var return_from: float = 0.0
var dock_from: float = 0.0
var dock_to: float = 0.0
var cine_blend: float = 0.0
var ship_dust: CPUParticles3D = null


func _ready() -> void:
	rng.randomize()
	sound = SoundMixer.new()
	add_child(sound)
	var saved: Dictionary = SaveData.load_data()
	best_miles = int(saved["best_miles"])
	total_energy = int(saved["total_energy"])
	total_diamonds = int(saved["total_diamonds"])
	balance = int(saved["balance"])
	missions_done = int(saved["missions_done"])
	speed_level = clampi(int(saved["speed_level"]), 0, SPEED_SCALES.size() - 1)
	time_scale = float(SPEED_SCALES[speed_level])

	route = RouteBuilder.new()
	rock_material = _plain_material(Color(0.30, 0.28, 0.26), 0.95)
	station_material = _plain_material(Color(0.055, 0.085, 0.13), 0.2)
	_build_environment()
	_build_sky()
	_build_ship()
	_build_camera()
	_build_streaks()
	_build_dust()

	hud = HudScript.new()
	add_child(hud)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.speed_selected.connect(_on_speed_selected)
	hud.menu_choice.connect(_on_menu_choice)
	hud.set_route(route)
	_build_station_mover()
	hud.set_speed_level(speed_level)

	palette_galaxy = 0
	current_palette = route.galaxy_palette(0)
	target_palette = current_palette
	_apply_palette()
	var pending: int = SaveData.pending_slot
	SaveData.pending_slot = -1
	var loaded: bool = pending >= 1 and _apply_slot(pending)
	_sync_world()
	if loaded:
		_show_message("LOADED SAVE SLOT %d\n\nBack in flight, from the same place" % pending, 5.0)
	else:
		pass
	_begin_mission_brief(false)


# ---------------------------------------------------------------- setup

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.014, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = BASE_AMBIENT
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.02
	env.adjustment_saturation = 0.92
	env.adjustment_brightness = 0.92
	env.glow_enabled = true
	env.ssao_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 0.7
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = false
	env.fog_sky_affect = 0.3
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(-SUN_DIRECTION.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.5
	sun.shadow_enabled = SHADOWS_ENABLED
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)


func _build_sky() -> void:
	sky_sphere = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = SKY_RADIUS
	mesh.height = SKY_RADIUS * 2.0
	mesh.radial_segments = 96
	mesh.rings = 48
	sky_sphere.mesh = mesh
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/galaxy_sky.gdshader") as Shader
	sky_material.set_shader_parameter("sun_dir", SUN_DIRECTION.normalized())
	sky_sphere.material_override = sky_material
	add_child(sky_sphere)


func _build_ship() -> void:
	ship = Node3D.new()
	ship.position = Vector3(0.0, SHIP_RESTING_Y, 0.0)
	add_child(ship)
	var built: Dictionary = ShipModel.build(ship)
	ship_flames = built["flames"]
	ship_nav = built["nav"]


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.3
	camera.far = FAR_PLANE
	camera.position = Vector3(0.0, 2.9, 7.2)
	add_child(camera)
	camera.current = true


func _build_streaks() -> void:
	# Light streaks rush toward the camera; their speed follows the ship's speed.
	streaks = CPUParticles3D.new()
	streaks.amount = 220
	streaks.lifetime = 2.4
	streaks.preprocess = 2.4
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(110.0, 60.0, 160.0)
	streaks.position = Vector3(0.0, 0.0, -140.0)
	streaks.direction = Vector3(0.0, 0.0, 1.0)
	streaks.spread = 0.0
	streaks.initial_velocity_min = CRUISE_SPEED
	streaks.initial_velocity_max = CRUISE_SPEED
	streaks.gravity = Vector3.ZERO
	streaks.local_coords = false
	var streak_mesh := BoxMesh.new()
	streak_mesh.size = Vector3(0.035, 0.035, 2.2)
	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.albedo_color = Color(0.95, 0.9, 0.8, 0.5)
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_mesh.material = streak_mat
	streaks.mesh = streak_mesh
	streaks.emitting = true
	add_child(streaks)


func _sync_world() -> void:
	_update_tiles()
	_update_planets()
	_apply_positions()


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	if paused:
		return
	elapsed += delta
	_update_message_timer(delta)
	_update_palette(delta)
	# Travel, spawns and enemies run on the chosen speed. Steering, boost, firing and HUD stay real-time.
	var dt: float = delta * time_scale
	_update_life(dt)
	_spin_planets(delta)
	_animate_station_mover(delta)

	if game_over:
		if repair_phase != "":
			_update_repair(delta)
		_apply_positions()
		_update_zone(delta)
		_animate_ship(delta, 0.0)
		_update_camera(delta)
		_update_hud()
		return

	_read_input(delta)
	if bh_state == "transit" or bh_state == "quick":
		if bh_state == "transit":
			_update_transit(delta)
		else:
			_update_quick(delta)
		_apply_positions()
		_animate_ship(delta, current_speed)
		_update_camera(delta)
		_update_streaks(current_speed)
		_update_hud()
		return

	# Briefing, landing, rescue, take-off, the return and the dock: the ship's world is run by the mission phase.
	if mission_phase != "flight" and mission_phase != "depart" and mission_phase != "airspace":
		_update_mission_frozen(delta)
		_apply_positions()
		_animate_ship(delta, current_speed)
		_update_camera(delta)
		_update_streaks(current_speed)
		_update_hud()
		return

	_update_black_hole(delta)
	if mission_phase == "depart":
		# Leaving the station: a calm, steady pace, with no obstacles.
		mission_timer += delta
		current_speed = DEPART_SPEED
		if mission_timer >= DEPART_SECONDS:
			mission_phase = "flight"
			mission_timer = 0.0
	elif mission_phase == "airspace":
		# Over the planet the ship holds back, and stops short of the surface.
		current_speed = AIRSPACE_SPEED if traveled() < float(route.units(mission_target)) - AIRSPACE_STOP else 0.0
	else:
		current_speed = _speed_now()
	ship_route_z -= current_speed * dt
	_update_passing()
	_update_tiles()
	_update_planets()
	if mission_phase == "flight":
		_update_spawns(dt)
	_update_zone(delta)
	_update_entities(dt)
	_update_enemy_fire(dt)
	_handle_fire(delta)
	_update_mission_flight(delta)
	_update_airspace(delta)
	_apply_positions()
	_animate_ship(delta, current_speed)
	_update_camera(delta)
	_update_streaks(current_speed)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			if not game_over:
				_set_paused(not paused)
		KEY_R:
			if game_over and repair_phase == "":
				_restart()
		KEY_M:
			if game_over or paused:
				get_tree().change_scene_to_file(COVER_SCENE)
		KEY_TAB:
			hud.toggle_route()
		KEY_N:
			_quick_arrive()
		KEY_2:
			_toggle_pilot_view()


func _read_input(delta: float) -> void:
	var steer: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or hud.touch_left:
		steer -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or hud.touch_right:
		steer += 1.0
	steer_value = clampf(steer, -1.0, 1.0)
	# Altitude (W climbs, S descends) is free in the flight and in the airspace fight; it settles at rest.
	if mission_phase == "flight" or mission_phase == "airspace" or mission_phase == "rescue":
		var climb: float = 0.0
		if Input.is_key_pressed(KEY_W):
			climb += 1.0
		if Input.is_key_pressed(KEY_S):
			climb -= 1.0
		alt_offset = clampf(alt_offset + climb * 3.0 * delta, -ALT_LIMIT, ALT_LIMIT)
	else:
		alt_offset = lerpf(alt_offset, 0.0, 1.0 - exp(-3.0 * delta))
	target_x = clampf(target_x + steer_value * 16.0 * delta, -SIDE_LIMIT, SIDE_LIMIT)
	ship.position.x = lerpf(ship.position.x, clampf(target_x + mission_auto_x, -SIDE_LIMIT, SIDE_LIMIT), 1.0 - exp(-SIDE_RESPONSE * delta))

	var boost_wanted: bool = (Input.is_key_pressed(KEY_SPACE) or hud.touch_boost) and not warp_active
	boost_active = boost_wanted and boost_energy > 0.5
	if boost_active:
		boost_energy = maxf(0.0, boost_energy - 30.0 * delta)
	else:
		boost_energy = minf(100.0, boost_energy + 19.0 * delta)


func _speed_now() -> float:
	if warp_active:
		return WARP_SPEED
	# Mission flights are a longer, steadier trip than the free flight.
	var factor: float = MISSION_SPEED_FACTOR if mission_phase == "flight" else 1.0
	return (BOOST_SPEED if boost_active else CRUISE_SPEED) * factor


func traveled() -> float:
	return -ship_route_z


# ---------------------------------------------------------------- route and planets

func _update_passing() -> void:
	while traveled() > float(route.units(nearest_index)) + PASS_MARGIN:
		var passed: Dictionary = route.planet(nearest_index)
		nearest_index += 1
		_on_passed(passed)
	var nearest: Dictionary = route.planet(nearest_index)
	warp_active = bool(nearest["warp_before"])
	var galaxy: int = int(nearest["galaxy"])
	if galaxy != palette_galaxy:
		palette_galaxy = galaxy
		target_palette = route.galaxy_palette(galaxy)


func _on_passed(passed: Dictionary) -> void:
	var next: Dictionary = route.planet(nearest_index)
	var new_galaxy: bool = int(next["galaxy"]) != int(passed["galaxy"])
	var to_next: float = maxf(0.0, float(next["units"]) - traveled())
	if new_galaxy:
		hud.set_flash(0.9)
		_show_message("LEFT %s\n\nWARP SPACE\nENTERING  %s" % [
			passed["name"], route.galaxy_name(int(next["galaxy"]))], 6.0)
	else:
		_show_message("PASSED %s\n\nNEXT STOP   %s\n%s to go" % [
			passed["name"], next["name"], HudScript.million_km(to_next)], 5.0)


func _update_tiles() -> void:
	var base: int = int(floor(traveled() / TILE_LENGTH))
	var first: int = base - TILES_BEHIND
	var last: int = base + TILES_AHEAD
	for k in range(first, last + 1):
		if not tile_entries.has(k):
			_build_tile(k)
	for k in tile_entries.keys():
		if k < first or k > last + 4:
			_remove_entry(tile_entries[k])
			tile_entries.erase(k)


func _build_tile(k: int) -> void:
	var center_z: float = -(float(k) + 0.5) * TILE_LENGTH
	var node := Node3D.new()
	add_child(node)
	var entry: Dictionary = _add_mover(node, 0.0, 0.0, center_z)
	tile_entries[k] = entry
	var galaxy: int = int(route.planet(_nearest_index_for(-center_z))["galaxy"])
	var pal: Dictionary = route.galaxy_palette(galaxy)
	var r := RandomNumberGenerator.new()
	r.seed = 100003 + k * 7919
	_build_tile_content(node, pal, r, k)


func _nearest_index_for(units_ahead: float) -> int:
	var i: int = nearest_index
	while float(route.units(i)) < units_ahead:
		i += 1
	return i


func _build_tile_content(parent: Node3D, pal: Dictionary, r: RandomNumberGenerator, k: int) -> void:
	var accent: Color = pal["accent"]
	var rail_dark := _plain_material(Color(0.10, 0.09, 0.08), 0.5)
	var rail_glow := _glow_material(accent, 0.7)
	var marker_glow := _glow_material(Color(0.85, 0.6, 0.35), 0.5)
	var lamp_glow := _glow_material(Color(1.0, 0.36, 0.08), 1.0)
	for side in [-1.0, 1.0]:
		_tile_box(parent, Vector3(side * 12.2, 0.2, 0.0), Vector3(0.16, 0.16, TILE_LENGTH), rail_dark)
		_tile_box(parent, Vector3(side * 12.2, 0.2, 0.0), Vector3(0.055, 0.055, TILE_LENGTH), rail_glow)
	for zz in range(-45, 46, 10):
		_tile_box(parent, Vector3(0.0, -0.35, float(zz)), Vector3(0.10, 0.10, 1.7), marker_glow)
	if k % 2 == 0:
		for side in [-1.0, 1.0]:
			_tile_box(parent, Vector3(side * 13.4, 0.4, -20.0), Vector3(0.5, 2.8, 1.1), station_material)
			_tile_box(parent, Vector3(side * 13.12, -0.45, -20.08), Vector3(0.08, 0.12, 0.5), lamp_glow)

	var side_pick: float = -1.0 if r.randf() < 0.5 else 1.0
	var station := Node3D.new()
	station.position = Vector3(side_pick * 20.0, r.randf_range(-1.5, 4.0), r.randf_range(-35.0, 35.0))
	parent.add_child(station)
	_tile_box(station, Vector3.ZERO, Vector3(5.8, 1.25, 3.4), station_material)
	_tile_box(station, Vector3(0.0, 0.72, -0.15), Vector3(3.7, 0.22, 2.5), station_material)
	for so in [-2.25, 2.25]:
		_tile_box(station, Vector3(so, 0.68, -0.1), Vector3(0.075, 0.045, 2.25), rail_glow)
		_tile_box(station, Vector3(so, 0.84, -1.25), Vector3(0.22, 0.10, 0.22), lamp_glow)

	for i in range(2):
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 1.0
		rock_mesh.height = 2.0
		rock_mesh.radial_segments = 12
		rock_mesh.rings = 6
		rock.mesh = rock_mesh
		var side_rock: float = -1.0 if i % 2 == 0 else 1.0
		rock.position = Vector3(side_rock * r.randf_range(15.0, 29.0), r.randf_range(-5.0, 10.0), r.randf_range(-48.0, 48.0))
		var s: float = r.randf_range(1.2, 3.2)
		rock.scale = Vector3(s * r.randf_range(0.8, 1.2), s * r.randf_range(0.6, 1.0), s * r.randf_range(0.8, 1.2))
		rock.material_override = rock_material
		parent.add_child(rock)


func _update_planets() -> void:
	var low: int = maxi(0, nearest_index - 1)
	var high: int = nearest_index + 3
	for i in range(low, high + 1):
		if not planet_entries.has(i):
			_build_planet(i)
	for i in planet_entries.keys():
		if i < low:
			_remove_entry(planet_entries[i]["entry"])
			planet_entries.erase(i)


func _build_planet(i: int) -> void:
	var data: Dictionary = route.planet(i)
	var view: Dictionary = PlanetView.build(data)
	var root: Node3D = view["root"]
	add_child(root)
	var entry: Dictionary = _add_mover(root, float(data["lane_x"]), float(data["lane_y"]), -float(data["units"]))
	planet_entries[i] = {"entry": entry, "body": view["body"], "clouds": view["clouds"], "pivots": view["pivots"], "spin": float(data["spin"]), "data": data}


func _spin_planets(delta: float) -> void:
	for key in planet_entries.keys():
		var p: Dictionary = planet_entries[key]
		var body: Node3D = p["body"]
		body.rotate_y(float(p["spin"]) * delta)
		var clouds: Node3D = p["clouds"]
		if is_instance_valid(clouds):
			clouds.rotate_y(float(p["spin"]) * delta * 1.3)
		for pivot in p["pivots"]:
			var moon_pivot: Node3D = pivot["node"]
			moon_pivot.rotate_y(float(pivot["speed"]) * delta)


# Environment blends toward the planet the ship is closest to, so fog, ambient light and sky change
# as it approaches and passes each world.
func _update_zone(delta: float) -> void:
	var best_blend: float = 0.0
	var best_data: Dictionary = {}
	for key in planet_entries.keys():
		var p: Dictionary = planet_entries[key]
		var rel: float = float(p["entry"]["z"]) - ship_route_z
		var blend: float = clampf(1.0 - absf(rel) / ZONE_RANGE, 0.0, 1.0)
		if blend > best_blend:
			best_blend = blend
			best_data = p["data"]
	var target_density: float = 0.0
	var target_fog: Color = zone_fog
	var target_ambient: Color = BASE_AMBIENT
	if not best_data.is_empty():
		target_density = float(best_data["fog_d"]) * best_blend
		target_fog = best_data["fog"]
		target_ambient = BASE_AMBIENT.lerp(best_data["ambient"], best_blend * 0.5)
	var t: float = 1.0 - exp(-2.0 * delta)
	zone_density = lerpf(zone_density, target_density, t)
	zone_fog = zone_fog.lerp(target_fog, t)
	zone_ambient = zone_ambient.lerp(target_ambient, t)
	env.fog_enabled = zone_density > 0.000005
	env.fog_density = zone_density
	env.fog_light_color = zone_fog
	env.ambient_light_color = zone_ambient


func _update_palette(delta: float) -> void:
	var t: float = 1.0 - exp(-1.2 * delta)
	for key in current_palette.keys():
		current_palette[key] = current_palette[key].lerp(target_palette[key], t)
	_apply_palette()


func _apply_palette() -> void:
	sky_material.set_shader_parameter("band_normal", _vec3(current_palette["band_normal"]))
	sky_material.set_shader_parameter("band_color", _vec3(current_palette["band_color"]))
	sky_material.set_shader_parameter("nebula_color", _vec3(current_palette["nebula"]))
	sky_material.set_shader_parameter("star_tint_a", _vec3(current_palette["star_a"]))
	sky_material.set_shader_parameter("star_tint_b", _vec3(current_palette["star_b"]))
	sky_material.set_shader_parameter("time_s", elapsed)


func _vec3(value) -> Vector3:
	if value is Color:
		return Vector3(value.r, value.g, value.b)
	return value


# ---------------------------------------------------------------- spawning

func _update_spawns(delta: float) -> void:
	# The flight starts calm: hostile craft wait until the pilot has been flying for a while.
	if warp_active:
		return
	hazard_clock += delta
	if hazard_clock >= 4.5:
		hazard_clock = 0.0
		if elapsed > 20.0 and rng.randf() < 0.6:
			_spawn_hazard()
	pickup_clock += delta
	if pickup_clock >= 2.2:
		pickup_clock = 0.0
		if rng.randf() < 0.8:
			_spawn_pickup()
	alien_clock += delta
	if alien_clock >= 14.0:
		alien_clock = 0.0
		if elapsed > 35.0 and rng.randf() < 0.45:
			_spawn_alien()


# The middle of the road is quiet: most obstacles come from the sides.
func _pick_lane() -> float:
	var r: float = rng.randf()
	if r < 0.12:
		return LANES[1]
	return LANES[0] if r < 0.56 else LANES[2]


func _toggle_pilot_view() -> void:
	pilot_view = not pilot_view
	hud.set_cockpit(pilot_view)


func _spawn_hazard() -> void:
	var lane: float = _pick_lane()
	var node := Node3D.new()
	add_child(node)
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 14
	rock_mesh.rings = 8
	rock.mesh = rock_mesh
	var size: float = rng.randf_range(0.95, 1.35)
	rock.scale = Vector3(size * rng.randf_range(0.9, 1.15), size * rng.randf_range(0.8, 1.05), size)
	rock.material_override = rock_material
	node.add_child(rock)
	# A smaller chunk beside the rock makes it look irregular.
	var chunk := MeshInstance3D.new()
	chunk.mesh = rock_mesh
	chunk.scale = Vector3(0.45, 0.4, 0.45) * size
	chunk.position = Vector3(size * 0.9, -size * 0.4, size * 0.3)
	chunk.material_override = rock_material
	node.add_child(chunk)
	_add_entry(node, lane, rng.randf_range(0.7, 1.6), ship_route_z - rng.randf_range(110.0, 150.0), "hazards",
		{"spin": Vector3(rng.randf(), rng.randf(), rng.randf()) * 0.6})


func _spawn_pickup() -> void:
	var lane: float = LANES[rng.randi_range(0, LANES.size() - 1)]
	var node := Node3D.new()
	add_child(node)
	var gem := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.9, 1.25, 0.9)
	gem.mesh = prism
	var gem_mat := _glow_material(Color(0.55, 0.9, 0.75), 1.2)
	gem.material_override = gem_mat
	node.add_child(gem)
	_add_entry(node, lane, 1.15, ship_route_z - rng.randf_range(86.0, 125.0), "pickups",
		{"base_y": 1.15, "phase": rng.randf() * TAU, "gem": gem_mat})


func _spawn_alien() -> void:
	var lane: float = _pick_lane()
	var node := Node3D.new()
	add_child(node)
	# A Rift Raider in the colours of the planet ahead.
	var palette: Dictionary = route.planet(nearest_index).get("raider", {})
	var built: Dictionary = RaiderModel.build(node, palette.get("armour", Color(0.09, 0.09, 0.11)), palette.get("lights", Color(1.0, 0.12, 0.1)))
	node.rotation.y = PI
	var base_y: float = rng.randf_range(0.8, 2.1)
	_add_entry(node, lane, base_y, ship_route_z - rng.randf_range(145.0, 178.0), "aliens",
		{"lane": lane, "base_y": base_y, "light": built["light"], "shot": rng.randf_range(1.5, 3.0)})


# ---------------------------------------------------------------- entities, collisions

func _update_entities(delta: float) -> void:
	var sweep_ship: float = current_speed * delta
	var sweep_alien: float = (current_speed + ALIEN_SPEED) * delta

	for alien in aliens.duplicate():
		if game_over:
			break
		alien["z"] = float(alien["z"]) + ALIEN_SPEED * delta
		alien["x"] = lerpf(float(alien["x"]), float(alien["lane"]), 1.8 * delta)
		alien["y"] = float(alien["base_y"]) + sin(elapsed * 2.2 + float(alien["lane"])) * 0.25
		(alien["light"] as StandardMaterial3D).emission_energy_multiplier = 1.0 + 0.8 * sin(elapsed * 5.0 + float(alien["lane"]))
		if float(alien["z"]) > ship_route_z + 24.0:
			_remove_entry(alien)
		elif _overlaps(float(alien["x"]), float(alien["y"]), float(alien["z"]), ALIEN_RADIUS, sweep_alien):
			_end_game()

	for hazard in hazards.duplicate():
		if float(hazard["z"]) > ship_route_z + 40.0:
			_remove_entry(hazard)
			continue
		var hazard_node: Node3D = hazard["node"]
		hazard_node.rotation += hazard["spin"] * delta
		if not game_over and _overlaps(float(hazard["x"]), float(hazard["y"]), float(hazard["z"]), HAZARD_RADIUS, sweep_ship):
			_end_game()

	for pickup in pickups.duplicate():
		if float(pickup["z"]) > ship_route_z + 40.0:
			_remove_entry(pickup)
			continue
		pickup["y"] = float(pickup["base_y"]) + sin(elapsed * 2.8 + float(pickup["phase"])) * 0.18
		(pickup["gem"] as StandardMaterial3D).emission_energy_multiplier = 1.0 + 0.6 * sin(elapsed * 4.0 + float(pickup["phase"]))
		var pickup_node: Node3D = pickup["node"]
		pickup_node.rotation.y += 1.8 * delta
		if _overlaps(float(pickup["x"]), float(pickup["y"]), float(pickup["z"]), PICKUP_RADIUS, sweep_ship):
			_collect(pickup)

	for bolt in bolts.duplicate():
		bolt["z"] = float(bolt["z"]) - BOLT_SPEED * delta
		if float(bolt["z"]) < ship_route_z - 260.0:
			_remove_entry(bolt)
			continue
		for alien in aliens.duplicate():
			var dx: float = float(bolt["x"]) - float(alien["x"])
			var dy: float = float(bolt["y"]) - float(alien["y"])
			var dz: float = absf(float(bolt["z"]) - float(alien["z"]))
			var reach: float = ALIEN_RADIUS + BOLT_RADIUS
			if dx * dx + dy * dy < reach * reach and dz < reach + (BOLT_SPEED + ALIEN_SPEED) * delta:
				_destroy_alien(alien)
				_remove_entry(bolt)
				break


func _overlaps(ex: float, ey: float, ez: float, radius: float, sweep: float) -> bool:
	var rel_z: float = ez - ship_route_z
	var reach: float = radius + SHIP_RADIUS
	if absf(rel_z) > reach + sweep:
		return false
	var dx: float = ex - ship.position.x
	var dy: float = ey - ship.position.y
	return dx * dx + dy * dy < reach * reach


func _handle_fire(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var wanted: bool = Input.is_key_pressed(KEY_F) or hud.touch_fire
	if not wanted or fire_cooldown > 0.0 or game_over:
		return
	fire_cooldown = 0.22
	sound.play("laser")
	for side in [-0.34, 0.34]:
		var node := Node3D.new()
		add_child(node)
		var orb := MeshInstance3D.new()
		var orb_mesh := SphereMesh.new()
		orb_mesh.radius = 0.22
		orb_mesh.height = 0.44
		orb.mesh = orb_mesh
		orb.material_override = _glow_material(Color(0.95, 0.85, 0.6), 1.8)
		node.add_child(orb)
		_add_entry(node, ship.position.x + side, ship.position.y + 0.16, ship_route_z - 3.0, "bolts")


func _collect(pickup: Dictionary) -> void:
	energy += 1
	total_energy += 1
	total_diamonds += 1
	_save()
	_remove_entry(pickup)


func _destroy_alien(alien: Dictionary) -> void:
	energy += 2
	total_energy += 2
	total_diamonds += 10
	_save()
	_spawn_explosion(float(alien["x"]), float(alien["y"]), float(alien["z"]))
	_remove_entry(alien)
	shake = maxf(shake, 0.35)
	sound.play("explosion")
	_show_message("HOSTILE DESTROYED   +10 DIAMONDS", 1.2)


func _spawn_explosion(x: float, y: float, z: float) -> void:
	var burst := CPUParticles3D.new()
	burst.local_coords = true
	burst.amount = 28
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.lifetime = 0.55
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.gravity = Vector3(0.0, -1.5, 0.0)
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 11.0
	burst.scale_amount_min = 0.08
	burst.scale_amount_max = 0.24
	var spark := SphereMesh.new()
	spark.radius = 0.1
	spark.height = 0.2
	burst.mesh = spark
	burst.material_override = _glow_material(Color(1.0, 0.55, 0.2), 2.8)
	add_child(burst)
	burst.emitting = true
	_add_mover(burst, x, y, z, 0.9)


func _end_game() -> void:
	if game_over:
		return
	game_over = true
	boost_active = false
	shake = 0.9
	sound.play("explosion")
	hud.set_flash(0.35)
	var final_miles: int = int(round(traveled() * UNIT_MILES))
	best_miles = maxi(best_miles, final_miles)
	_save()
	hud.set_pause_text("OPTIONS")
	_show_message("", 0.0)
	_show_crash_menu()


# ---------------------------------------------------------------- entry bookkeeping

func _add_mover(node: Node3D, x: float, y: float, z: float, life: float = -1.0) -> Dictionary:
	var entry: Dictionary = {"node": node, "x": x, "y": y, "z": z, "life": life}
	movers.append(entry)
	return entry


func _add_entry(node: Node3D, x: float, y: float, z: float, list_name: String, extra: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {"node": node, "x": x, "y": y, "z": z, "life": -1.0, "list_name": list_name}
	entry.merge(extra)
	movers.append(entry)
	_list_for(list_name).append(entry)
	return entry


func _remove_entry(entry: Dictionary) -> void:
	_erase_identical(movers, entry)
	if entry.has("list_name"):
		_erase_identical(_list_for(String(entry["list_name"])), entry)
	var node: Node3D = entry["node"]
	if is_instance_valid(node):
		node.queue_free()


func _list_for(list_name: String) -> Array:
	match list_name:
		"hazards":
			return hazards
		"pickups":
			return pickups
		"aliens":
			return aliens
	return bolts


# Erase by identity (is_same), not by content, so entries never compare equal by accident.
func _erase_identical(list: Array, entry: Dictionary) -> void:
	for i in range(list.size()):
		if is_same(list[i], entry):
			list.remove_at(i)
			return


func _update_life(delta: float) -> void:
	for entry in movers.duplicate():
		if float(entry["life"]) > 0.0:
			entry["life"] = float(entry["life"]) - delta
			if float(entry["life"]) <= 0.0:
				_remove_entry(entry)


func _apply_positions() -> void:
	for entry in movers:
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.position = Vector3(float(entry["x"]), float(entry["y"]), float(entry["z"]) - ship_route_z)


# ---------------------------------------------------------------- presentation

func _animate_ship(delta: float, speed: float) -> void:
	# Level flight: the bank is gentle, and the nose follows the path and the altitude.
	ship.rotation.z = lerpf(ship.rotation.z, -steer_value * 0.12 + mission_auto_bank * 0.08, 1.0 - exp(-6.0 * delta))
	var pitch_target: float = sin(elapsed * 1.5) * 0.008 + (-0.03 if boost_active else 0.0) - alt_offset * 0.02
	if mission_phase == "takeoff":
		pitch_target += 0.5 * smoothstep(0.0, 1.0, clampf(mission_timer / TAKEOFF_SECONDS, 0.0, 1.0))
	ship.rotation.x = lerpf(ship.rotation.x, pitch_target, 1.0 - exp(-3.0 * delta))
	sound.set_engine(clampf(speed / BOOST_SPEED, 0.0, 1.0), boost_active)
	sound.set_alarm(mission_phase == "alarm")
	# A fine buffet at high speed, and the slow bob at rest.
	var buffet: float = clampf(speed / BOOST_SPEED, 0.0, 1.0)
	ship.position.y = ship_base_y + alt_offset + sin(elapsed * 2.0) * 0.03 + sin(elapsed * 37.0) * 0.004 * buffet
	var power: float = 1.0
	if boost_active:
		power += 0.25
	if warp_active:
		power += 0.6
	if mission_phase == "takeoff":
		power += 1.6 * smoothstep(0.0, 1.0, clampf(mission_timer / TAKEOFF_SECONDS, 0.0, 1.0))
	elif mission_phase == "landing":
		power += 0.4 * (1.0 - clampf(mission_timer / LANDING_SECONDS, 0.0, 1.0))
	for i in range(ship_flames.size()):
		var flame: MeshInstance3D = ship_flames[i]
		flame.scale = Vector3(1.0, 1.0, power * (0.92 + 0.14 * sin(elapsed * 38.0 + float(i) * 1.7)))
	# The nav lights blink, out of step with each other.
	for light_entry in ship_nav:
		var mat: StandardMaterial3D = light_entry[0]
		var phase: float = float(light_entry[1])
		mat.emission_energy_multiplier = 0.25 + 2.2 * pow(0.5 + 0.5 * sin(elapsed * 5.0 + phase), 4.0)


func _update_camera(delta: float) -> void:
	var fov_target: float = 88.0 if warp_active else (76.0 if boost_active else 70.0)
	if pilot_view:
		fov_target = 88.0 if warp_active else (80.0 if boost_active else 68.0)
	if mission_phase == "landing" or mission_phase == "takeoff":
		fov_target = 62.0
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-3.0 * delta))
	shake = maxf(0.0, shake - 2.5 * delta)
	var jitter := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), 0.0) * shake * 0.35
	if pilot_view:
		# Cockpit: the eye sits just above the canopy. A slow head sway and engine rumble make it feel physical.
		var sway := Vector3(sin(elapsed * 0.9) * 0.012, sin(elapsed * 1.7) * 0.007, 0.0)
		var rumble: float = (0.010 if boost_active else 0.0) + (0.025 if warp_active else 0.0)
		var vib := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), 0.0) * rumble
		camera.position = Vector3(ship.position.x, ship.position.y + 0.42, -0.55) + sway + vib + jitter
		camera.look_at(Vector3(ship.position.x * 1.2, ship.position.y * 0.8 + 0.1 + ship.rotation.x * 2.0, -80.0), Vector3.UP)
		camera_roll = lerpf(camera_roll, -steer_value * 0.1 + ship.rotation.z * 0.5, 1.0 - exp(-6.0 * delta))
		camera.rotate_object_local(Vector3.BACK, camera_roll)
		cine_blend = 0.0
		return
	# Chase camera, and cinematic framings for the departure, the landing and the take-off.
	var chase_pos := Vector3(ship.position.x * 0.45, ship.position.y + 2.1, 7.2)
	var chase_look := Vector3(ship.position.x * 0.25, ship.position.y * 0.5 + 0.8, -60.0)
	var cine_pos: Vector3 = chase_pos
	var cine_look: Vector3 = chase_look
	var cinematic: bool = false
	if mission_phase == "landing":
		cinematic = true
		cine_pos = ship.position + Vector3(15.0, 2.8, 7.0)
		cine_look = ship.position + Vector3(0.0, -1.6, -2.0)
	elif mission_phase == "takeoff":
		cinematic = true
		var rise: float = clampf(mission_timer / TAKEOFF_SECONDS, 0.0, 1.0)
		cine_pos = ship.position + Vector3(-5.0, -2.2 + rise * 2.0, 13.0)
		cine_look = ship.position + Vector3(0.0, 4.0 + rise * 6.0, -12.0)
	elif mission_phase == "depart":
		cinematic = true
		var station_z: float = float(station_entry["z"]) - ship_route_z
		cine_pos = Vector3(0.0, 9.0, station_z + 30.0)
		cine_look = Vector3(0.0, 0.0, station_z * 0.5)
	cine_blend = lerpf(cine_blend, 1.0 if cinematic else 0.0, 1.0 - exp(-2.0 * delta))
	camera.position = chase_pos.lerp(cine_pos, cine_blend) + jitter
	camera.look_at(chase_look.lerp(cine_look, cine_blend), Vector3.UP)
	camera_roll = lerpf(camera_roll, -steer_value * 0.07 + mission_auto_bank * 0.05, 1.0 - exp(-4.0 * delta))
	camera.rotate_object_local(Vector3.BACK, camera_roll)


func _update_streaks(speed: float) -> void:
	streaks.speed_scale = 1.0 if (bh_state == "transit" or bh_state == "quick") else time_scale
	ship_dust.speed_scale = streaks.speed_scale
	ship_dust.initial_velocity_min = speed * 0.35
	ship_dust.initial_velocity_max = speed * 0.4
	streaks.initial_velocity_min = speed * 0.98
	streaks.initial_velocity_max = speed * 1.02


func _update_hud() -> void:
	var nearest: Dictionary = route.planet(nearest_index)
	var arrive_units: float = maxf(0.0, float(nearest["units"]) - traveled())
	var previous_units: float = 0.0 if nearest_index == 0 else float(route.units(nearest_index - 1))
	var span: float = maxf(1.0, float(nearest["units"]) - previous_units)
	var progress: float = clampf((traveled() - previous_units) / span, 0.0, 1.0)
	var lines: Array = []
	for k in range(0, 5):
		var p: Dictionary = route.planet(nearest_index + k)
		lines.append("%s   %s" % [p["name"], HudScript.million_km(maxf(0.0, float(p["units"]) - traveled()))])
	var jump: bool = bh_state == "transit" or bh_state == "quick"
	var speed_factor: float = 1.0 if jump else time_scale
	var speed_prefix: String = "BLACK HOLE   " if bh_state == "transit" else ("WARP   " if warp_active else "")
	hud.update({
		"speed_text": speed_prefix + HudScript.speed_km(current_speed * speed_factor),
		"travelled_text": HudScript.million_km(traveled()),
		"energy_text": HudScript.commas(energy),
		"diamonds_text": HudScript.commas(total_diamonds),
		"best_text": HudScript.million_km(float(best_miles) / UNIT_MILES),
		"balance_text": HudScript.commas(balance),
		"hull_ratio": hull / HULL_MAX,
		"boost_ratio": boost_energy / 100.0,
		"planet": {
			"name": nearest["name"],
			"type": nearest["type"],
			"gravity": nearest["gravity"],
			"temp": nearest["temp"],
			"moons": nearest["moons"],
			"galaxy_name": String(nearest.get("universe", route.galaxy_name(int(nearest["galaxy"])))),
		},
		"remaining_text": HudScript.million_km(arrive_units),
		"progress": progress,
		"route_lines": lines,
	})
	hud.set_map_state({
		"traveled": traveled(),
		"nearest": nearest_index,
		"target": mission_target,
		"bh_active": bh_state == "approach",
		"bh_units": bh_units,
	})
	hud.set_mission_line(_mission_line())
	var speed_norm: float = clampf((current_speed if jump else current_speed * time_scale) / BOOST_SPEED, 0.0, 1.0)
	hud.set_cockpit_state({
		"bank": ship.rotation.z,
		"pitch": ship.rotation.x,
		"speed_norm": speed_norm,
		"boosting": boost_active,
		"warp": warp_active or jump,
	})


func _show_message(text: String, seconds: float) -> void:
	hud.set_message(text)
	message_time = seconds


func _update_message_timer(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			hud.set_message("")


# ---------------------------------------------------------------- black holes

# Every 50 million km a black hole appears ahead. Entering it carries the ship to the next
# destination (at least 29 million km ahead) in exactly 1 minute of real time, whatever the speed setting.
func _update_black_hole(delta: float) -> void:
	if bh_state == "none":
		if not warp_active and traveled() >= next_bh_units and not _bh_blocked_by_mission():
			_start_approach()
	elif bh_state == "approach":
		if is_instance_valid(black_hole_disk):
			black_hole_disk.rotate_y(delta * 0.9)
		if traveled() >= bh_units - 10.0:
			_begin_transit()


# A black hole waits while the mission target is too close for a jump to be worth it.
func _bh_blocked_by_mission() -> bool:
	return mission_phase == "flight" and float(route.units(mission_target)) - traveled() < BH_JUMP_MIN_UNITS


func _jump_destination() -> int:
	# During a mission the jump takes the ship straight to the mission target.
	if mission_phase == "flight" and mission_target >= nearest_index and float(route.units(mission_target)) - traveled() >= BH_JUMP_MIN_UNITS:
		return mission_target
	for i in range(nearest_index, nearest_index + 200):
		var p: Dictionary = route.planet(i)
		if not bool(p["warp_before"]) and float(p["units"]) - traveled() >= BH_JUMP_MIN_UNITS:
			return i
	return nearest_index + 1


func _start_approach() -> void:
	bh_state = "approach"
	bh_dest = _jump_destination()
	bh_units = traveled() + 260.0
	var node := Node3D.new()
	add_child(node)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 7.0
	core_mesh.height = 14.0
	core.mesh = core_mesh
	var void_mat := StandardMaterial3D.new()
	void_mat.albedo_color = Color(0.0, 0.0, 0.0)
	void_mat.roughness = 1.0
	core.material_override = void_mat
	node.add_child(core)
	# A soft glow around the event horizon, instead of hard rings.
	black_hole_disk = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 9.5
	glow_mesh.height = 19.0
	black_hole_disk.mesh = glow_mesh
	var glow_shader := Shader.new()
	glow_shader.code = PlanetView.ATMOSPHERE_CODE
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = glow_shader
	glow_mat.set_shader_parameter("glow_color", Color(1.0, 0.55, 0.3))
	glow_mat.set_shader_parameter("intensity", 1.4)
	glow_mat.set_shader_parameter("falloff", 2.2)
	black_hole_disk.material_override = glow_mat
	node.add_child(black_hole_disk)
	black_hole_entry = _add_mover(node, 0.0, 0.0, -bh_units)
	_show_message("BLACK HOLE AHEAD\n\nENTER IT TO REACH %s IN 1 MINUTE" % route.planet(bh_dest)["name"], 6.0)


func _begin_transit() -> void:
	bh_state = "transit"
	transit_start = traveled()
	transit_distance = float(route.units(bh_dest)) - transit_start
	transit_timer = 0.0
	boost_active = false
	message_time = 0.0
	if not black_hole_entry.is_empty():
		_remove_entry(black_hole_entry)
		black_hole_entry = {}
	# Nothing else is shown during the jump: no stars, planets, asteroids or ships.
	for group in [hazards, pickups, aliens, bolts]:
		for entry in group.duplicate():
			_remove_entry(entry)
	for key in tile_entries.keys():
		_remove_entry(tile_entries[key])
	tile_entries.clear()
	for key in planet_entries.keys():
		_remove_entry(planet_entries[key]["entry"])
	planet_entries.clear()
	sky_sphere.visible = false
	var streak_box := streaks.mesh as BoxMesh
	if streak_box != null:
		streak_box.size = Vector3(0.05, 0.05, 7.0)
	streaks.amount = 420
	hud.set_flash(0.6)


func _update_transit(delta: float) -> void:
	transit_timer += delta
	var f: float = clampf(transit_timer / BH_TRANSIT_SECONDS, 0.0, 1.0)
	ship_route_z = -(transit_start + transit_distance * f)
	current_speed = transit_distance / BH_TRANSIT_SECONDS
	var remaining: int = int(ceil(maxf(0.0, BH_TRANSIT_SECONDS - transit_timer)))
	hud.set_message("BLACK HOLE JUMP\n\n%d:%02d remaining" % [remaining / 60, remaining % 60])
	if f >= 1.0:
		_end_transit()


func _end_transit() -> void:
	bh_state = "none"
	nearest_index = bh_dest
	ship_route_z = -float(route.units(bh_dest))
	next_bh_units = traveled() + BH_INTERVAL_UNITS
	sky_sphere.visible = true
	var streak_box := streaks.mesh as BoxMesh
	if streak_box != null:
		streak_box.size = Vector3(0.035, 0.035, 2.2)
	streaks.amount = 220
	current_speed = _speed_now()
	var dest: Dictionary = route.planet(bh_dest)
	hud.set_flash(0.5)
	_show_message("OUT OF THE BLACK HOLE\n\nARRIVED AT %s\n%s travelled in 1 minute" % [
		dest["name"], HudScript.million_km(transit_distance)], 7.0)


# ---------------------------------------------------------------- pause, restart, save

func _on_pause_pressed() -> void:
	if game_over:
		if repair_phase == "":
			_show_crash_menu()
		return
	_set_paused(not paused)


func _set_paused(value: bool) -> void:
	paused = value
	streaks.speed_scale = 0.0 if paused else time_scale
	if paused:
		boost_active = false
		hud.set_pause_text("RESUME")
		_show_message("", 0.0)
		_show_pause_menu()
	else:
		hud.set_pause_text("II  PAUSE")
		hud.hide_menu()
		_show_message("", 0.0)


func _on_speed_selected(index: int) -> void:
	speed_level = clampi(index, 0, SPEED_SCALES.size() - 1)
	time_scale = float(SPEED_SCALES[speed_level])
	hud.set_speed_level(speed_level)
	streaks.speed_scale = 0.0 if paused else time_scale
	_save()
	var names: Array = ["SLOW", "MEDIUM", "FAST"]
	_show_message("SPEED   %s" % names[speed_level], 1.5)


func _restart() -> void:
	get_tree().reload_current_scene()


func _save() -> void:
	SaveData.save_data({
		"best_miles": best_miles,
		"total_energy": total_energy,
		"total_diamonds": total_diamonds,
		"speed_level": speed_level,
		"balance": balance,
		"missions_done": missions_done,
	})


# ---------------------------------------------------------------- menus, save slots, repair

func _show_crash_menu() -> void:
	hud.show_menu("SHIP DAMAGED", "The ship was destroyed at %s travelled.\n\nRESTART begins a new flight from Earth.\nREPAIR TO PLAY repairs the ship and continues from this exact place.\nSAVE GAME keeps this place for later.\n\nEnergy and diamonds are kept." % HudScript.million_km(traveled()), [
		{"id": "restart", "text": "RESTART   (from Earth)", "enabled": true},
		{"id": "repair", "text": "REPAIR TO PLAY   (from this place)", "enabled": true},
		{"id": "save", "text": "SAVE GAME", "enabled": true},
		{"id": "menu", "text": "MAIN MENU", "enabled": true},
	])


func _show_pause_menu() -> void:
	hud.show_menu("FLIGHT PAUSED", "The universe is holding still.\n\nESC or RESUME continues the flight.", [
		{"id": "resume", "text": "RESUME", "enabled": true},
		{"id": "save", "text": "SAVE GAME", "enabled": true},
		{"id": "menu", "text": "MAIN MENU", "enabled": true},
	])


func _show_save_menu() -> void:
	var options: Array = []
	for slot in range(1, 4):
		var info: Dictionary = SaveData.read_slot(slot)
		var label: String = "SLOT %d   ·   EMPTY" % slot
		if not info.is_empty():
			label = "SLOT %d   ·   %s   ·   %s" % [slot, info["summary"], info["saved_at"]]
		options.append({"id": "slot_%d" % slot, "text": label, "enabled": true})
	options.append({"id": save_return, "text": "BACK", "enabled": true})
	hud.show_menu("SAVE GAME", "Choose a slot. Load it later from the main menu (LOAD GAME), and the ship continues from the same place.", options)


func _on_menu_choice(id: String) -> void:
	match id:
		"restart":
			_restart()
		"repair":
			_start_repair()
		"save":
			save_return = "crash_menu" if game_over else "pause_menu"
			_show_save_menu()
		"resume":
			_set_paused(false)
		"menu":
			get_tree().change_scene_to_file(COVER_SCENE)
		"crash_menu":
			_show_crash_menu()
		"pause_menu":
			_show_pause_menu()
		"slot_1", "slot_2", "slot_3":
			_save_to_slot(int(id.substr(5)))


func _save_to_slot(slot: int) -> void:
	if bh_state != "none" or repair_phase != "":
		_show_message("SAVING IS NOT AVAILABLE DURING A BLACK HOLE JUMP OR A REPAIR", 3.0)
		return
	var data: Dictionary = {
		"ship_route_z": ship_route_z,
		"nearest_index": nearest_index,
		"energy": energy,
		"speed_level": speed_level,
		"next_bh_units": next_bh_units,
		"ship_x": target_x,
		"summary": "%s   ·   next %s" % [HudScript.million_km(traveled()), route.planet(nearest_index)["name"]],
		"saved_at": "%s %s" % [Time.get_date_string_from_system(), Time.get_time_string_from_system()],
	}
	SaveData.write_slot(slot, data)
	_show_message("SAVED TO SLOT %d" % slot, 2.5)
	_show_save_menu()


func _apply_slot(slot: int) -> bool:
	var data: Dictionary = SaveData.read_slot(slot)
	if data.is_empty():
		return false
	ship_route_z = float(data["ship_route_z"])
	nearest_index = int(data["nearest_index"])
	energy = int(data["energy"])
	speed_level = clampi(int(data["speed_level"]), 0, SPEED_SCALES.size() - 1)
	time_scale = float(SPEED_SCALES[speed_level])
	next_bh_units = float(data["next_bh_units"])
	target_x = float(data["ship_x"])
	ship.position.x = target_x
	boost_energy = 100.0
	bh_state = "none"
	game_over = false
	hud.set_speed_level(speed_level)
	_clear_corridor()
	return true


func _start_repair() -> void:
	hud.hide_menu()
	repair_phase = "countdown"
	repair_timer = 0.0
	message_time = 0.0
	hud.set_message("SHIP DAMAGED   ·   REPAIR STARTING")
	hud.show_big("3")
	repair_sparks = CPUParticles3D.new()
	repair_sparks.local_coords = true
	repair_sparks.amount = 70
	repair_sparks.lifetime = 0.7
	repair_sparks.explosiveness = 0.2
	repair_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	repair_sparks.emission_sphere_radius = 1.8
	repair_sparks.direction = Vector3.UP
	repair_sparks.spread = 180.0
	repair_sparks.initial_velocity_min = 1.0
	repair_sparks.initial_velocity_max = 3.0
	repair_sparks.gravity = Vector3(0.0, -1.5, 0.0)
	var spark := SphereMesh.new()
	spark.radius = 0.06
	spark.height = 0.12
	repair_sparks.mesh = spark
	repair_sparks.material_override = _glow_material(Color(1.0, 0.75, 0.4), 2.5)
	repair_sparks.emitting = false
	ship.add_child(repair_sparks)
	repair_ring = MeshInstance3D.new()
	var shield := SphereMesh.new()
	shield.radius = 2.3
	shield.height = 4.6
	repair_ring.mesh = shield
	var shield_shader := Shader.new()
	shield_shader.code = PlanetView.ATMOSPHERE_CODE
	var shield_mat := ShaderMaterial.new()
	shield_mat.shader = shield_shader
	shield_mat.set_shader_parameter("glow_color", Color(0.55, 0.95, 0.7))
	shield_mat.set_shader_parameter("intensity", 1.3)
	shield_mat.set_shader_parameter("falloff", 2.5)
	repair_ring.material_override = shield_mat
	repair_ring.visible = false
	ship.add_child(repair_ring)


# Three seconds of countdown (3, 2, 1), then five seconds of repair with sparks and a rotating ring.
func _update_repair(delta: float) -> void:
	repair_timer += delta
	if repair_phase == "countdown":
		var left: int = int(ceil(3.0 - repair_timer))
		hud.show_big(str(maxi(left, 1)))
		if repair_timer >= 3.0:
			repair_phase = "repairing"
			repair_timer = 0.0
			hud.show_big("")
			repair_ring.visible = true
			repair_sparks.emitting = true
	elif repair_phase == "repairing":
		repair_ring.rotate_y(delta * 3.0)
		ship.visible = int(elapsed * 14.0) % 3 != 0
		var ratio: float = clampf(repair_timer / 5.0, 0.0, 1.0)
		hud.set_message("SHIP REPAIR IN PROGRESS\n\n%d%%   ·   %d s left" % [
			int(ratio * 100.0), int(ceil(maxf(0.0, 5.0 - repair_timer)))])
		if repair_timer >= 5.0:
			_finish_repair()


func _finish_repair() -> void:
	repair_phase = ""
	game_over = false
	shake = 0.0
	ship.visible = true
	hull = maxf(hull, REPAIR_HULL)
	if repair_ring != null:
		repair_ring.queue_free()
		repair_ring = null
	if repair_sparks != null:
		repair_sparks.queue_free()
		repair_sparks = null
	boost_energy = 100.0
	_clear_corridor()
	hud.set_pause_text("II  PAUSE")
	hud.show_big("")
	hud.set_flash(0.35)
	_show_message("SHIP REPAIRED\n\nBack in flight, from the same place", 4.0)


# Remove the obstacles right in front of the ship, so it does not hit the same object again.
func _clear_corridor() -> void:
	for h in hazards.duplicate():
		var hz: float = float(h["z"])
		if hz > ship_route_z - 120.0 and hz < ship_route_z + 6.0:
			_remove_entry(h)
	for a in aliens.duplicate():
		var az: float = float(a["z"])
		if az > ship_route_z - 90.0 and az < ship_route_z + 6.0:
			_remove_entry(a)
	for b in bolts.duplicate():
		_remove_entry(b)


func _build_dust() -> void:
	# Motes drifting past the ship (in the ship's own space), so flight has depth.
	ship_dust = CPUParticles3D.new()
	ship_dust.local_coords = true
	ship_dust.amount = 140
	ship_dust.lifetime = 4.0
	ship_dust.preprocess = 4.0
	ship_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ship_dust.emission_box_extents = Vector3(7.0, 3.5, 10.0)
	ship_dust.position = Vector3(0.0, 0.0, -6.0)
	ship_dust.direction = Vector3(0.0, 0.0, 1.0)
	ship_dust.spread = 4.0
	ship_dust.initial_velocity_min = 0.0
	ship_dust.initial_velocity_max = 0.0
	ship_dust.gravity = Vector3.ZERO
	ship_dust.scale_amount_min = 0.5
	ship_dust.scale_amount_max = 1.4
	var speck := SphereMesh.new()
	speck.radius = 0.03
	speck.height = 0.06
	speck.radial_segments = 6
	speck.rings = 3
	var speck_mat := StandardMaterial3D.new()
	speck_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	speck_mat.albedo_color = Color(0.9, 0.82, 0.7, 0.6)
	speck_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	speck.material = speck_mat
	ship_dust.mesh = speck
	ship_dust.emitting = true
	ship.add_child(ship_dust)


# ---------------------------------------------------------------- quick arrival (N)

# N: arrive at the nearest planet in one second. The obstacles on the way are cleared first.
func _quick_arrive() -> void:
	if game_over or paused or bh_state != "none" or repair_phase != "" or mission_phase != "flight":
		return
	# During a mission, N takes the ship straight to the mission target.
	var dest: int = mission_target
	if float(route.units(dest)) - traveled() < 40.0:
		dest += 1
	quick_dest = dest
	quick_start = traveled()
	quick_distance = float(route.units(dest)) - quick_start
	quick_timer = 0.0
	bh_state = "quick"
	boost_active = false
	message_time = 0.0
	_clear_ahead_to(-float(route.units(dest)))
	hud.set_flash(0.45)
	hud.set_message("ARRIVING AT %s" % route.planet(dest)["name"])


func _update_quick(delta: float) -> void:
	quick_timer += delta
	var f: float = clampf(quick_timer / QUICK_SECONDS, 0.0, 1.0)
	ship_route_z = -(quick_start + quick_distance * f)
	current_speed = quick_distance / QUICK_SECONDS
	_update_tiles()
	_update_planets()
	if f >= 1.0:
		_end_quick()


func _end_quick() -> void:
	bh_state = "none"
	if quick_dest == mission_target:
		# Stop just short of the target and begin the landing.
		ship_route_z = -(float(route.units(mission_target)) - MISSION_RESCUE_RANGE * 0.5)
		current_speed = _speed_now()
		_begin_airspace()
		return
	# Finish just past the planet, so normal flight registers the arrival.
	ship_route_z = -(float(route.units(quick_dest)) + PASS_MARGIN + 5.0)
	current_speed = _speed_now()
	hud.set_flash(0.3)


func _clear_ahead_to(dest_z: float) -> void:
	for list in [hazards, pickups, aliens, bolts]:
		for entry in list.duplicate():
			if float(entry["z"]) > dest_z - 80.0:
				_remove_entry(entry)


# ---------------------------------------------------------------- missions

func _begin_mission_brief(restart: bool) -> void:
	mission_phase = "brief"
	mission_timer = 0.0
	if not restart:
		# A new mission starts at the station, and its target is the next world in the campaign.
		mission_target = CampaignScript.stop_for_mission(missions_done)
		mission_start_units = traveled()
		mission_start_nearest = nearest_index
		mission_side = 1.0 if missions_done % 2 == 0 else -1.0
	var target: Dictionary = route.planet(mission_target)
	var distance: float = maxf(0.0, float(target["units"]) - traveled())
	mission_travel_seconds = distance / (CRUISE_SPEED * MISSION_SPEED_FACTOR * time_scale)
	# The rescue window grows with the trip: the trip time twice over, plus time for the battle.
	mission_clock = maxf(90.0, mission_travel_seconds * 2.0 + 90.0)
	hud.set_alarm(false)
	hud.show_menu("INCOMING SIGNAL", _brief_text(), [])
	sound.play("radio")
	_show_message("", 0.0)


func _brief_text() -> String:
	var target: Dictionary = route.planet(mission_target)
	var universe: String = String(target.get("universe", route.galaxy_name(int(target["galaxy"]))))
	var role: String = String(target.get("survivor_role", "SURVIVOR"))
	var brief: String = String(target.get("briefing", "A survivor is trapped on the surface and hostile craft are closing in."))
	var threat: String = String(target.get("threat", "Hostile craft are closing in."))
	return "PLANET     %s\nUNIVERSE   %s\nRESCUE     %s\nDISTANCE   %s\nTRAVEL     about %s at your speed\n\n%s\n\nTHREAT   %s\n\nRESCUE WINDOW   %s" % [
		target["name"], universe, role, HudScript.million_km(float(target["units"])),
		_clock_text(mission_travel_seconds), brief, threat, _clock_text(mission_clock)]


func _update_brief(delta: float) -> void:
	mission_timer += delta
	var remaining: float = BRIEF_SECONDS - mission_timer
	if remaining <= 3.0:
		hud.show_big(str(int(ceil(remaining))))
	if mission_timer >= BRIEF_SECONDS:
		hud.show_big("")
		hud.hide_menu()
		mission_phase = "depart"
		mission_timer = 0.0
		mission_auto_x = 0.0
		mission_auto_bank = 0.0
		var target: Dictionary = route.planet(mission_target)
		_show_message("DEPARTING STATION\n\nHEADING FOR %s   ·   %s" % [
			target["name"], HudScript.million_km(float(target["units"]))], 5.0)


func _update_mission_frozen(delta: float) -> void:
	if surface != null:
		_check_surface_impacts()
	match mission_phase:
		"brief":
			_update_brief(delta)
		"landing":
			mission_timer += delta
			_tick_clock(delta)
			var t: float = clampf(mission_timer / LANDING_SECONDS, 0.0, 1.0)
			ship_base_y = surface.landing_height(t)
			surface.set_landing_progress(t, false)
			surface.update(delta, ship.position, _fire_pressed())
			if t >= 1.0 and mission_phase == "landing":
				_begin_rescue()
		"rescue":
			# The battle: the ship hovers over the landing site and flies the fight.
			mission_timer += delta
			_tick_clock(delta)
			ship_base_y = lerpf(ship_base_y, BATTLE_Y, 1.0 - exp(-2.0 * delta))
			surface.update(delta, ship.position, _fire_pressed())
			var damage: float = surface.take_hull_damage()
			if damage > 0.0:
				_damage_hull(damage)
			if mission_phase == "rescue":
				if surface.outcome == "lost":
					_mission_fail("THE SURVIVOR WAS LOST")
				elif surface.outcome == "rescued":
					_begin_boarding()
		"boarding":
			mission_timer += delta
			_tick_clock(delta)
			ship_base_y = lerpf(ship_base_y, LANDED_Y, 1.0 - exp(-2.0 * delta))
			surface.update(delta, ship.position, false)
			if surface.boarded and mission_phase == "boarding":
				_begin_takeoff()
		"takeoff":
			mission_timer += delta
			surface.update(delta, ship.position, false)
			var t2: float = clampf(mission_timer / TAKEOFF_SECONDS, 0.0, 1.0)
			ship_base_y = surface.takeoff_height(t2)
			surface.set_landing_progress(t2, true)
			current_speed = 0.0
			if t2 >= 1.0:
				_end_takeoff()
		"passed":
			mission_timer += delta
			current_speed = 0.0
			ship_base_y = lerpf(ship_base_y, SHIP_RESTING_Y, 1.0 - exp(-1.5 * delta))
			if mission_timer >= PASSED_DELAY:
				_begin_return()
		"return":
			# Back to the station: a fast warp with the stars streaming past.
			mission_timer += delta
			var rt: float = clampf(mission_timer / RETURN_SECONDS, 0.0, 1.0)
			ship_route_z = lerpf(return_from, 0.0, smoothstep(0.0, 1.0, rt))
			current_speed = RETURN_SPEED
			if rt >= 1.0:
				_begin_dock()
		"dock":
			# The final approach to the station's docking arm.
			mission_timer += delta
			var dt2: float = clampf(mission_timer / DOCK_SECONDS, 0.0, 1.0)
			ship_route_z = lerpf(dock_from, dock_to, smoothstep(0.0, 1.0, dt2))
			current_speed = DOCK_SPEED
			if dt2 >= 1.0:
				_finish_dock()
		"alarm":
			mission_timer += delta
			current_speed = 0.0
			if mission_timer >= ALARM_SECONDS:
				hud.set_alarm(false)
				_begin_mission_brief(false)
		"failed":
			mission_timer += delta
			current_speed = 0.0
			if mission_timer >= FAIL_DELAY:
				_restart_mission()
	_update_streaks(current_speed)


func _update_mission_flight(delta: float) -> void:
	_tick_clock(delta)
	if mission_phase != "flight":
		return
	var target_units: float = float(route.units(mission_target))
	var progress: float = clampf(traveled() / maxf(1.0, target_units), 0.0, 1.0)
	# The route is not a straight line: the autopilot swings the ship left or right of it, and back to the lane.
	mission_auto_x = mission_side * CURVE_AMPLITUDE * sin(PI * progress)
	mission_auto_bank = -mission_side * cos(PI * progress)
	# Arriving over the planet starts the aerial fight. The landing waits until the raiders are cleared.
	if traveled() >= target_units - MISSION_RESCUE_RANGE:
		_begin_airspace()


func _tick_clock(delta: float) -> void:
	if mission_phase == "flight" or mission_phase == "airspace" or mission_phase == "landing" or mission_phase == "rescue" or mission_phase == "boarding":
		mission_clock -= delta
		if mission_clock <= 0.0:
			_mission_fail("TOO LATE: THE SURVIVOR WAS LOST")


func _begin_landing() -> void:
	mission_phase = "landing"
	mission_timer = 0.0
	mission_auto_x = 0.0
	mission_auto_bank = 0.0
	current_speed = 0.0
	alt_offset = 0.0
	airspace_left = 0
	_clear_world_for_surface()
	surface = RescueSurface.new()
	add_child(surface)
	surface.setup(route.planet(mission_target), mini(6 + missions_done, 14))
	surface.start_landing()
	surface.attach_gear(ship)
	streaks.emitting = false
	env.fog_enabled = true
	env.fog_density = 0.0035
	env.fog_light_color = route.planet(mission_target)["atmos"]
	zone_density = 0.0
	hud.set_flash(0.5)
	_show_message("LANDING ON %s\n\nHOLD ON" % route.planet(mission_target)["name"], 3.0)


func _begin_rescue() -> void:
	mission_phase = "rescue"
	mission_timer = 0.0
	surface.start_rescue()
	_show_message("SIGNAL RECEIVED\n\nTHE SURVIVOR HAS FOUND YOU. AN ALIEN VILLAIN IS COMING. FIGHT THROUGH THE RAIDERS", 6.0)


func _begin_boarding() -> void:
	mission_phase = "boarding"
	mission_timer = 0.0
	surface.start_boarding()
	_show_message("SURVIVOR SAFE\n\nBOARDING THE SHIP", 3.0)


func _begin_takeoff() -> void:
	mission_phase = "takeoff"
	mission_timer = 0.0
	surface.start_takeoff()
	_show_message("TAKE OFF", 3.0)


func _end_takeoff() -> void:
	if surface != null:
		surface.queue_free()
		surface = null
	streaks.emitting = true
	hud.set_flash(0.4)
	_sync_world()
	_mission_success()


func _mission_success() -> void:
	balance += MISSION_REWARD
	sound.play("mission")
	missions_done += 1
	_save()
	mission_phase = "passed"
	mission_timer = 0.0
	hud.set_flash(0.6)
	_show_message("MISSION PASSED\n\n+$%s added to your balance\n\nReturning to the station" % HudScript.commas(MISSION_REWARD), 4.0)


func _begin_alarm() -> void:
	mission_phase = "alarm"
	mission_timer = 0.0
	hud.set_alarm(true)
	_show_message("ALARM\n\nNEW RESCUE SIGNAL DETECTED", ALARM_SECONDS)


func _mission_fail(reason: String) -> void:
	if mission_phase == "failed":
		return
	mission_phase = "failed"
	mission_timer = 0.0
	hud.set_flash(0.5)
	_show_message("MISSION FAILED\n\n%s\n\nThe mission starts again." % reason, 0.0)


func _restart_mission() -> void:
	if surface != null:
		surface.queue_free()
		surface = null
	ship_base_y = SHIP_RESTING_Y
	ship_route_z = -mission_start_units
	nearest_index = mission_start_nearest
	streaks.emitting = true
	hull = HULL_MAX
	alt_offset = 0.0
	_clear_corridor()
	_sync_world()
	_show_message("", 0.0)
	_begin_mission_brief(true)


func _clear_world_for_surface() -> void:
	if bh_state == "approach":
		if not black_hole_entry.is_empty():
			_remove_entry(black_hole_entry)
			black_hole_entry = {}
		bh_state = "none"
	for group in [hazards, pickups, aliens, bolts]:
		for entry in group.duplicate():
			_remove_entry(entry)
	for key in tile_entries.keys():
		_remove_entry(tile_entries[key])
	tile_entries.clear()
	for key in planet_entries.keys():
		_remove_entry(planet_entries[key]["entry"])
	planet_entries.clear()


# Each impact on the surface (a raider beam or a dive into the survivor) shakes the camera.
func _check_surface_impacts() -> void:
	var serial: int = int(surface.impact_serial)
	if serial != surface_impacts_seen:
		shake = maxf(shake, 0.6)
		surface_impacts_seen = serial


func _fire_pressed() -> bool:
	return Input.is_key_pressed(KEY_F) or hud.touch_fire


func _clock_text(seconds: float) -> String:
	var s: int = int(ceil(maxf(0.0, seconds)))
	return "%02d:%02d" % [s / 60, s % 60]


func _mission_line() -> String:
	var planet_text: String = String(route.planet(mission_target)["name"])
	var number: int = missions_done + 1
	match mission_phase:
		"brief":
			return "MISSION %d  ·  %s  ·  STANDBY" % [number, planet_text]
		"depart":
			return "MISSION %d  ·  DEPARTING STATION" % number
		"flight":
			return "MISSION %d  ·  %s  ·  RESCUE IN %s" % [number, planet_text, _clock_text(mission_clock)]
		"airspace":
			return "MISSION %d  ·  AERIAL COMBAT  ·  RAIDERS %d  ·  RESCUE IN %s" % [number, airspace_left + aliens.size(), _clock_text(mission_clock)]
		"landing", "boarding":
			var health: float = surface.survivor_health if surface != null else 100.0
			return "MISSION %d  ·  SURVIVOR %d%%  ·  RESCUE IN %s" % [number, int(health), _clock_text(mission_clock)]
		"rescue":
			var health_now: float = surface.survivor_health if surface != null else 100.0
			var line: String = "MISSION %d  ·  SURVIVOR %d%%  ·  RESCUE IN %s" % [number, int(health_now), _clock_text(mission_clock)]
			if surface != null and surface.boss_alive:
				line += "  ·  ALIEN VILLAIN %d%%" % int(surface.boss_health)
			return line
		"takeoff":
			return "MISSION %d  ·  TAKE OFF" % number
		"passed":
			return "MISSION %d  ·  PASSED" % number
		"return":
			return "RETURNING TO STATION"
		"dock":
			return "DOCKING AT STATION"
		"alarm":
			return "ALARM"
		"failed":
			return "MISSION FAILED"
	return ""


# ---------------------------------------------------------------- the station and the return

func _build_station_mover() -> void:
	var node := Node3D.new()
	add_child(node)
	var built: Dictionary = StationModel.build(node)
	station_entry = _add_mover(node, 0.0, 0.0, STATION_BEHIND_Z)
	station_windows = built["windows"]
	station_beacons = built["beacons"]


func _animate_station_mover(delta: float) -> void:
	if station_windows.is_empty():
		return
	for k in range(station_windows.size()):
		var lamp: StandardMaterial3D = station_windows[k]
		lamp.emission_energy_multiplier = 1.0 + 0.35 * sin(elapsed * 1.3 + float(k) * 0.7)
	for beacon in station_beacons:
		var mat: StandardMaterial3D = beacon[0]
		mat.emission_energy_multiplier = 0.2 + 2.6 * pow(0.5 + 0.5 * sin(elapsed * 2.4 + float(beacon[1])), 6.0)


func _begin_return() -> void:
	mission_phase = "return"
	mission_timer = 0.0
	return_from = ship_route_z
	_clear_world_for_surface()
	station_entry["node"].visible = false
	streaks.direction = Vector3(0.0, 0.0, -1.0)
	streaks.emitting = true
	hud.set_flash(0.5)
	_show_message("RETURNING TO STATION", 4.0)


func _begin_dock() -> void:
	mission_phase = "dock"
	mission_timer = 0.0
	dock_from = ship_route_z
	# The station waits ahead; the ship docks at the arm on its near side.
	var station_z: float = dock_from - 150.0
	station_entry["z"] = station_z
	station_entry["node"].visible = true
	dock_to = station_z + 55.0
	streaks.emitting = false
	_show_message("STATION AHEAD\n\nDOCKING", 3.0)


func _finish_dock() -> void:
	# The station becomes the origin again: it sits behind the ship at the arm, ready for the next departure.
	station_entry["z"] = STATION_BEHIND_Z
	ship_route_z = 0.0
	nearest_index = 0
	mission_start_units = 0.0
	mission_start_nearest = 0
	streaks.direction = Vector3(0.0, 0.0, 1.0)
	streaks.emitting = true
	hud.set_flash(0.4)
	_sync_world()
	mission_phase = "alarm"
	mission_timer = 0.0
	current_speed = 0.0
	hud.set_alarm(true)
	_show_message("DOCKED AT STATION\n\nNEW RESCUE SIGNAL INCOMING", ALARM_SECONDS)


# ---------------------------------------------------------------- aerial combat over the planet

func _begin_airspace() -> void:
	mission_phase = "airspace"
	mission_timer = 0.0
	airspace_left = mini(6 + missions_done, 12)
	airspace_spawn_timer = 1.5
	hud.set_flash(0.4)
	_show_message("AERIAL COMBAT\n\nRIFT RAIDERS ARE ATTACKING. DESTROY THEM", 4.0)


func _update_airspace(delta: float) -> void:
	if mission_phase != "airspace":
		return
	mission_timer += delta
	airspace_spawn_timer -= delta
	if airspace_left > 0 and airspace_spawn_timer <= 0.0:
		airspace_spawn_timer = 2.8
		airspace_left -= 1
		_spawn_alien()
	if airspace_left <= 0 and aliens.is_empty():
		hud.set_flash(0.4)
		_show_message("AIRSPACE CLEAR\n\nLANDING ON %s" % route.planet(mission_target)["name"], 3.0)
		_begin_landing()


# Each raider fires a red laser when it is ahead and in range. A shot is a hit unless the ship has moved sideways out of its line.
func _update_enemy_fire(delta: float) -> void:
	for alien in aliens:
		alien["shot"] = float(alien["shot"]) - delta
		var ahead: float = float(alien["z"]) - ship_route_z
		if float(alien["shot"]) <= 0.0 and ahead < -20.0 and ahead > -150.0:
			alien["shot"] = rng.randf_range(1.8, 3.2)
			_fire_enemy_beam(alien)
	for beam in enemy_beams.duplicate():
		beam["life"] = float(beam["life"]) - delta
		_place_beam(beam)
		if float(beam["life"]) <= 0.0:
			_remove_beam(beam)


func _fire_enemy_beam(alien: Dictionary) -> void:
	var beam_node := Node3D.new()
	var cylinder := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.07
	mesh.height = 1.0
	cylinder.mesh = mesh
	cylinder.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	cylinder.material_override = _glow_material(Color(1.0, 0.15, 0.1), 3.0)
	beam_node.add_child(cylinder)
	add_child(beam_node)
	sound.play("enemy_laser")
	var beam: Dictionary = {"node": beam_node, "alien": alien, "life": 0.16, "last": Vector3.ZERO}
	enemy_beams.append(beam)
	_place_beam(beam)
	if absf(float(alien["x"]) - ship.position.x) < 2.6:
		_damage_hull(ENEMY_HIT_DAMAGE)


func _place_beam(beam: Dictionary) -> void:
	var alien: Dictionary = beam["alien"]
	var from: Vector3 = beam["last"]
	if is_instance_valid(alien["node"]):
		from = Vector3(float(alien["x"]), float(alien["y"]), float(alien["z"]) - ship_route_z)
		beam["last"] = from
	var to: Vector3 = Vector3(ship.position.x, ship.position.y, 0.0)
	var span: Vector3 = to - from
	var length: float = span.length()
	if length < 0.01:
		return
	var beam_node: Node3D = beam["node"]
	beam_node.position = (from + to) * 0.5
	beam_node.look_at(beam_node.position + span, Vector3.UP)
	beam_node.scale = Vector3(1.0, 1.0, length)


func _remove_beam(beam: Dictionary) -> void:
	for i in range(enemy_beams.size()):
		if is_same(enemy_beams[i], beam):
			enemy_beams.remove_at(i)
			break
	var beam_node: Node3D = beam["node"]
	if is_instance_valid(beam_node):
		beam_node.queue_free()


func _damage_hull(amount: float) -> void:
	if game_over:
		return
	hull = maxf(0.0, hull - amount)
	sound.play("hit")
	shake = maxf(shake, 0.35)
	if hull <= 0.0:
		_end_game()


# ---------------------------------------------------------------- materials

func _plain_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.4
	return material


func _glow_material(color: Color, energy_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy_value
	return material


func _tile_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
