extends Node3D
# The landing site on each planet: a textured terrain built from noise, a landing pad with markings, the planet overhead,
# a military survivor with a signal flare, the Rift Raiders and the big alien villain.
# The ship lands here and takes off from here. The battle is flown from the air, and main.gd drives the ship.

const PlanetView = preload("res://scripts/planet_view.gd")
const RaiderModel = preload("res://scripts/raider_model.gd")
const AlienBossModel = preload("res://scripts/alien_boss_model.gd")

const GROUND_Y: float = -4.9
const LANDED_HEIGHT: float = -4.1
const SURVIVOR_XZ: Vector3 = Vector3(4.0, 0.0, -56.0)
const BOSS_XZ: Vector3 = Vector3(-7.0, 0.0, -96.0)
const BOSS_STANDOFF: float = 30.0
const BOSS_WALK_SPEED: float = 3.2
const BOARD_POS: Vector3 = Vector3(0.0, -4.9, -3.2)
const SPAWN_Z: float = -140.0
const RAIDER_SPEED: float = 9.5
const RAIDER_HIT_RANGE: float = 3.4
const BOLT_SPEED: float = 110.0
const BOLT_HIT_RANGE: float = 3.0
const BOSS_HIT_RANGE: float = 9.0
const FIRE_COOLDOWN: float = 0.2
const BOSS_HIT_DAMAGE: float = 5.0
const BOSS_STOMP_SECONDS: float = 4.0
const BOSS_PLASMA_SECONDS: float = 3.6
const PLASMA_TRAVEL: float = 1.4
const PLASMA_HIT_DAMAGE: float = 12.0
const SHIP_X_HIT: float = 4.0
const SIGNAL_SECONDS: float = 4.5
const BOARD_SECONDS: float = 4.0
const RAIDER_BEAM_DAMAGE: float = 4.0
const SURVIVOR_STOMP_DAMAGE: float = 25.0
const SPAWN_INTERVAL: float = 2.4

var outcome: String = "active"
var boarded: bool = false
var survivor_health: float = 100.0
var boss_health: float = 100.0
var boss_alive: bool = false
var impact_serial: int = 0
var phase: String = "idle"
var phase_timer: float = 0.0
var time_s: float = 0.0
var spawn_timer: float = 0.0
var fire_cooldown: float = 0.0
var stomp_timer: float = 0.0
var plasma_timer: float = 0.0
var raiders_total: int = 0
var raiders_spawned: int = 0
var raiders: Array = []
var bolts: Array = []
var plasmas: Array = []
var pending_damage: float = 0.0
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var style: String = ""
var survivor_color: Color = Color(0.4, 0.5, 0.4)
var dust_color: Color = Color(0.7, 0.6, 0.5)
var raider_armour: Color = Color(0.09, 0.09, 0.11)
var raider_lights: Color = Color(1.0, 0.12, 0.1)
var planet_spin: float = 0.02
var sky_planet: Node3D
var survivor: Node3D
var survivor_arm: Node3D
var survivor_legs: Array = []
var survivor_light: OmniLight3D
var flare: MeshInstance3D
var flare_light: OmniLight3D
var board_from: Vector3 = Vector3.ZERO
var boss_root: Node3D
var boss: Dictionary = {}
var boss_walk: float = 0.0
var boss_fall: float = 0.0
var landing_dust: CPUParticles3D
var takeoff_dust: CPUParticles3D
var cloud_layers: Array = []
var gear_nodes: Array = []
var landing_p: float = 0.0
var landing_takeoff: bool = false
var gear_extended: float = 0.0


# ---------------------------------------------------------------- setup

func setup(planet: Dictionary, raider_count: int) -> void:
	raiders_total = raider_count
	style = String(planet.get("style", ""))
	rng.seed = hash(String(planet["name"]))
	noise.seed = absi(int(rng.seed)) % 100000
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	survivor_color = planet.get("survivor_suit", planet["atmos"])
	dust_color = survivor_color.lerp(Color(0.5, 0.45, 0.4), 0.5)
	var raider: Dictionary = planet.get("raider", {})
	raider_armour = raider.get("armour", Color(0.09, 0.09, 0.11))
	raider_lights = raider.get("lights", Color(1.0, 0.12, 0.1))
	planet_spin = float(planet.get("spin", 0.02))
	_build_terrain(planet)
	_build_horizon()
	_build_sky_planet(planet)
	_build_pad()
	_build_survivor()
	_build_boss()
	_build_dust()
	_build_style()
	_build_scatter()
	_build_cloud_layers(planet)


# The height of the ground at a point: flat around the landing pad, rolling and rocky further out.
func _ground_y(x: float, z: float) -> float:
	var distance: float = Vector2(x, z).length()
	var flat: float = clampf((distance - 16.0) / 26.0, 0.0, 1.0)
	var big: float = noise.get_noise_2d(x * 0.006, z * 0.006) * 14.0
	var small: float = noise.get_noise_2d(x * 0.03, z * 0.03) * 1.6
	return GROUND_Y + (big + small) * flat


func _terrain_color(planet: Dictionary) -> Color:
	var tint: Color = planet.get("tint", Color(1.0, 1.0, 1.0))
	return tint * 0.85


func _build_terrain(planet: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extent: float = 520.0
	var steps: int = 88
	var step: float = extent / float(steps)
	var base: Color = _terrain_color(planet)
	for i in range(steps):
		for j in range(steps):
			var x0: float = -extent * 0.5 + float(i) * step
			var z0: float = -extent * 0.5 + float(j) * step
			var x1: float = x0 + step
			var z1: float = z0 + step
			var p00 := Vector3(x0, _ground_y(x0, z0), z0)
			var p10 := Vector3(x1, _ground_y(x1, z0), z0)
			var p01 := Vector3(x0, _ground_y(x0, z1), z1)
			var p11 := Vector3(x1, _ground_y(x1, z1), z1)
			_tri(st, p00, p01, p10, base)
			_tri(st, p10, p01, p11, base)
	st.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	ground.material_override = mat
	add_child(ground)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, base: Color) -> void:
	for p in [a, b, c]:
		var lift: float = clampf((p.y - GROUND_Y) / 14.0, -1.0, 1.0)
		st.set_color(base * (0.85 + 0.2 * lift))
		st.add_vertex(p)


func _build_horizon() -> void:
	var mat := _plain(survivor_color * 0.25, 0.9, 0.0)
	for i in range(14):
		var a: float = float(i) / 14.0 * TAU
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(50.0, 110.0)
		cone.height = rng.randf_range(90.0, 200.0)
		peak.mesh = cone
		peak.position = Vector3(cos(a) * 360.0, GROUND_Y + cone.height * 0.5 - 6.0, sin(a) * 360.0)
		peak.material_override = mat
		add_child(peak)


func _build_sky_planet(planet: Dictionary) -> void:
	var data: Dictionary = planet.duplicate()
	data["radius"] = 150.0
	var view: Dictionary = PlanetView.build(data)
	sky_planet = view["root"]
	sky_planet.position = Vector3(-160.0, 170.0, -1000.0)
	add_child(sky_planet)


func _build_pad() -> void:
	var pad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14.0, 0.4, 14.0)
	pad.mesh = box
	pad.position = Vector3(0.0, GROUND_Y + 0.2, 0.0)
	pad.material_override = _plain(Color(0.28, 0.29, 0.31), 0.55, 0.4)
	add_child(pad)
	var marking := _glow(Color(1.0, 0.8, 0.35), 1.6)
	_box(Vector3(12.0, 0.06, 0.25), Vector3(0.0, GROUND_Y + 0.43, 0.0), marking)
	_box(Vector3(0.25, 0.06, 12.0), Vector3(0.0, GROUND_Y + 0.43, 0.0), marking)
	_box(Vector3(12.0, 0.06, 0.25), Vector3(0.0, GROUND_Y + 0.43, 5.5), marking)
	_box(Vector3(12.0, 0.06, 0.25), Vector3(0.0, GROUND_Y + 0.43, -5.5), marking)
	var lamp := _glow(Color(1.0, 0.7, 0.35), 1.8)
	for corner in [Vector3(6.6, 0.0, 6.6), Vector3(-6.6, 0.0, 6.6), Vector3(6.6, 0.0, -6.6), Vector3(-6.6, 0.0, -6.6)]:
		var light := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		light.mesh = sphere
		light.position = Vector3(corner.x, GROUND_Y + 0.5, corner.z)
		light.material_override = lamp
		add_child(light)


func _build_survivor() -> void:
	survivor = Node3D.new()
	var ground: float = _ground_y(SURVIVOR_XZ.x, SURVIVOR_XZ.z)
	survivor.position = Vector3(SURVIVOR_XZ.x, ground, SURVIVOR_XZ.z)
	add_child(survivor)
	var camo := _plain(survivor_color * 0.55, 0.85, 0.05)
	var vest := _plain(Color(0.13, 0.14, 0.12), 0.7, 0.2)
	var skin := _plain(Color(0.76, 0.58, 0.46), 0.6, 0.0)
	var helmet := _plain(Color(0.1, 0.11, 0.1), 0.45, 0.3)
	var visor := _glow(survivor_color, 1.2)
	var boot := _plain(Color(0.07, 0.06, 0.05), 0.7, 0.1)
	# Legs on hip pivots, with boots.
	survivor_legs.clear()
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.2 * side, 1.05, 0.0)
		survivor.add_child(hip)
		survivor_legs.append(hip)
		var leg := CapsuleMesh.new()
		leg.radius = 0.15
		leg.height = 0.9
		_part(hip, leg, Vector3(0.0, -0.5, 0.0), camo)
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.26, 0.2, 0.42)
		_part(hip, boot_mesh, Vector3(0.0, -1.05, -0.06), boot)
	# Torso in camouflage, a plate vest with pouches, and a backpack.
	var torso := CapsuleMesh.new()
	torso.radius = 0.34
	torso.height = 1.0
	_part(survivor, torso, Vector3(0.0, 1.25, 0.0), camo)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.8, 0.7, 0.5)
	_part(survivor, plate, Vector3(0.0, 1.35, -0.05), vest)
	for k in range(3):
		var pouch := BoxMesh.new()
		pouch.size = Vector3(0.18, 0.2, 0.12)
		_part(survivor, pouch, Vector3(-0.22 + float(k) * 0.22, 1.05, -0.3), vest)
	var pack := BoxMesh.new()
	pack.size = Vector3(0.6, 0.8, 0.3)
	_part(survivor, pack, Vector3(0.0, 1.3, 0.42), vest)
	# Head, helmet and visor.
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.52
	_part(survivor, head, Vector3(0.0, 2.1, 0.0), skin)
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.32
	helmet_mesh.height = 0.64
	var helmet_node := _part(survivor, helmet_mesh, Vector3(0.0, 2.25, 0.0), helmet)
	helmet_node.scale = Vector3(1.0, 0.7, 1.0)
	var visor_box := BoxMesh.new()
	visor_box.size = Vector3(0.5, 0.12, 0.08)
	_part(survivor, visor_box, Vector3(0.0, 2.12, -0.3), visor)
	# Arms on shoulder pivots. The right arm carries the signal flare, and the rifle sits across the chest.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.46 * side, 1.6, 0.0)
		survivor.add_child(shoulder)
		var arm := CapsuleMesh.new()
		arm.radius = 0.12
		arm.height = 0.8
		_part(shoulder, arm, Vector3(0.0, -0.4, 0.0), camo)
		var glove := SphereMesh.new()
		glove.radius = 0.12
		glove.height = 0.24
		_part(shoulder, glove, Vector3(0.0, -0.85, 0.0), _plain(Color(0.08, 0.08, 0.08), 0.8, 0.0))
		if side > 0.0:
			survivor_arm = shoulder
	var rifle := BoxMesh.new()
	rifle.size = Vector3(0.12, 0.18, 1.0)
	_part(survivor, rifle, Vector3(0.22, 1.32, -0.6), _plain(Color(0.06, 0.06, 0.07), 0.5, 0.6))
	# The signal flare, held in the right hand, and its light.
	flare = MeshInstance3D.new()
	var flare_mesh := CylinderMesh.new()
	flare_mesh.top_radius = 0.07
	flare_mesh.bottom_radius = 0.07
	flare_mesh.height = 0.45
	flare.mesh = flare_mesh
	flare.position = Vector3(0.0, -0.95, -0.15)
	flare.material_override = _glow(Color(1.0, 0.25, 0.2), 3.0)
	flare.visible = false
	survivor_arm.add_child(flare)
	flare_light = OmniLight3D.new()
	flare_light.light_color = Color(1.0, 0.3, 0.25)
	flare_light.light_energy = 0.0
	flare_light.omni_range = 16.0
	flare_light.position = Vector3(0.0, -0.95, -0.15)
	survivor_arm.add_child(flare_light)
	survivor_light = OmniLight3D.new()
	survivor_light.light_color = survivor_color
	survivor_light.light_energy = 0.6
	survivor_light.omni_range = 9.0
	survivor_light.position = Vector3(0.0, 2.6, 0.0)
	survivor.add_child(survivor_light)


func _build_boss() -> void:
	boss_root = Node3D.new()
	var ground: float = _ground_y(BOSS_XZ.x, BOSS_XZ.z)
	boss_root.position = Vector3(BOSS_XZ.x, ground + 2.8, BOSS_XZ.z)
	add_child(boss_root)
	boss = AlienBossModel.build(boss_root, raider_armour * 0.9, raider_lights)
	boss_alive = true


func _build_dust() -> void:
	landing_dust = _make_dust(180, 2.8, 3.0, 9.0, 6.0, dust_color)
	landing_dust.position = Vector3(0.0, GROUND_Y + 0.4, 0.0)
	add_child(landing_dust)
	takeoff_dust = _make_dust(300, 3.0, 10.0, 20.0, 9.0, dust_color)
	takeoff_dust.position = Vector3(0.0, GROUND_Y + 0.4, 0.0)
	add_child(takeoff_dust)


# Planet-specific scenery.
func _build_style() -> void:
	if style == "ocean":
		var foam := _glow(Color(0.85, 0.95, 1.0), 0.6)
		for k in range(12):
			_box(Vector3(rng.randf_range(8.0, 20.0), 0.06, 0.3), Vector3(rng.randf_range(-70.0, 70.0), _ground_y(0.0, -60.0) + 0.05, rng.randf_range(-150.0, -40.0)), foam)
	elif style == "crystal":
		var crystal_mat := _glow(Color(0.7, 0.45, 1.0), 1.8)
		for k in range(40):
			_crystal(Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-130.0, -12.0)), rng.randf_range(2.5, 7.0), crystal_mat)
	elif style == "ice":
		var ice := _plain(Color(0.78, 0.92, 1.0), 0.15, 0.1)
		ice.albedo_color = Color(0.78, 0.92, 1.0, 0.75)
		ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for k in range(30):
			var x: float = rng.randf_range(-60.0, 60.0)
			var z: float = rng.randf_range(-130.0, -14.0)
			if absf(x) < 9.0 and absf(z) < 9.0:
				continue
			var pillar := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.1
			cyl.bottom_radius = rng.randf_range(0.4, 1.0)
			cyl.height = rng.randf_range(3.0, 9.0)
			cyl.radial_segments = 8
			pillar.mesh = cyl
			pillar.position = Vector3(x, _ground_y(x, z) + cyl.height * 0.5, z)
			pillar.material_override = ice
			add_child(pillar)
	elif style == "lava":
		var crack := _glow(Color(1.0, 0.42, 0.08), 2.4)
		for k in range(40):
			var x: float = rng.randf_range(-80.0, 80.0)
			var z: float = rng.randf_range(-150.0, -20.0)
			if absf(x) < 8.0 and absf(z) < 8.0:
				continue
			var seam := _box(Vector3(rng.randf_range(3.0, 9.0), 0.08, 0.25), Vector3(x, _ground_y(x, z) + 0.07, z), crack)
			seam.rotation_degrees = Vector3(0.0, rng.randf_range(0.0, 180.0), 0.0)


func _crystal(pos: Vector3, height: float, mat: Material) -> void:
	var crystal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = rng.randf_range(0.35, 0.8)
	cyl.height = height
	cyl.radial_segments = 6
	crystal.mesh = cyl
	crystal.position = Vector3(pos.x, _ground_y(pos.x, pos.z) + height * 0.5 - 0.4, pos.z)
	crystal.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 360.0), rng.randf_range(-8.0, 8.0))
	crystal.material_override = mat
	add_child(crystal)


# ---------------------------------------------------------------- landing and take-off

# The ship's height during a landing: a long approach from high above, the two cloud layers, the hover, the final approach
# over the pad, and the touchdown. t runs from 0 (the start of the landing) to 1 (the ship on the pad).
func landing_height(t: float) -> float:
	var p: float = clampf(t, 0.0, 1.0)
	if p < 0.35:
		return lerpf(16.0, 6.0, smoothstep(0.0, 1.0, p / 0.35))
	if p < 0.6:
		return lerpf(6.0, 1.5, smoothstep(0.0, 1.0, (p - 0.35) / 0.25))
	if p < 0.85:
		return lerpf(1.5, -2.5, smoothstep(0.0, 1.0, (p - 0.6) / 0.25))
	return lerpf(-2.5, LANDED_HEIGHT, smoothstep(0.0, 1.0, (p - 0.85) / 0.15))


# The ship's height during a take-off: spool up on the pad, lift off, climb through the cloud layers, and rise out of the air.
func takeoff_height(t: float) -> float:
	var p: float = clampf(t, 0.0, 1.0)
	if p < 0.2:
		return LANDED_HEIGHT
	if p < 0.5:
		return lerpf(LANDED_HEIGHT, -2.5, smoothstep(0.0, 1.0, (p - 0.2) / 0.3))
	if p < 0.8:
		return lerpf(-2.5, 6.0, smoothstep(0.0, 1.0, (p - 0.5) / 0.3))
	return lerpf(6.0, 16.0, smoothstep(0.0, 1.0, (p - 0.8) / 0.2))


# Called every frame of a landing or a take-off: it drives the gear, the dust and the cloud layers.
func set_landing_progress(t: float, takeoff: bool) -> void:
	landing_p = clampf(t, 0.0, 1.0)
	landing_takeoff = takeoff
	if takeoff:
		gear_extended = 1.0 - clampf((landing_p - 0.2) / 0.3, 0.0, 1.0)
		landing_dust.emitting = false
		takeoff_dust.emitting = landing_p < 0.6
	else:
		gear_extended = clampf((landing_p - 0.55) / 0.3, 0.0, 1.0)
		takeoff_dust.emitting = false
		landing_dust.emitting = landing_p > 0.7
	for node in gear_nodes:
		if is_instance_valid(node):
			(node as Node3D).scale = Vector3(1.0, lerpf(0.45, 1.0, gear_extended), 1.0)


# Landing gear: four struts with feet, folded under the hull and extended on the approach. They are children of the ship.
func attach_gear(ship_node: Node3D) -> void:
	for corner in [Vector3(0.9, -0.2, -1.1), Vector3(-0.9, -0.2, -1.1), Vector3(0.9, -0.2, 1.4), Vector3(-0.9, -0.2, 1.4)]:
		var pivot := Node3D.new()
		pivot.position = corner
		ship_node.add_child(pivot)
		var strut := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.05
		cyl.height = 1.0
		strut.mesh = cyl
		strut.position = Vector3(0.0, -0.5, 0.0)
		strut.material_override = _plain(Color(0.22, 0.23, 0.25), 0.5, 0.6)
		pivot.add_child(strut)
		var foot := MeshInstance3D.new()
		var foot_box := BoxMesh.new()
		foot_box.size = Vector3(0.36, 0.08, 0.5)
		foot.mesh = foot_box
		foot.position = Vector3(0.0, -1.0, 0.0)
		foot.material_override = _plain(Color(0.14, 0.15, 0.17), 0.6, 0.4)
		pivot.add_child(foot)
		gear_nodes.append(pivot)
	set_landing_progress(landing_p, landing_takeoff)


# Cloud layers the ship descends through: unshaded planes with the planet's cloud texture.
func _build_cloud_layers(planet: Dictionary) -> void:
	var path: String = String(planet.get("cloud", ""))
	if path == "":
		path = "res://assets/earth_clouds.png"
	for layer_y in [11.0, 4.0]:
		var layer := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(900.0, 900.0)
		layer.mesh = plane
		layer.position = Vector3(0.0, layer_y, -120.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(path)
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
		layer.material_override = mat
		add_child(layer)
		cloud_layers.append(layer)


# Scenery for the landing site: a forest of trees on the forest world, and mesas on the desert world.
func _build_scatter() -> void:
	if style == "forest":
		var trunk_mat := _plain(Color(0.3, 0.2, 0.12), 0.9, 0.0)
		var leaf_mat := _plain(Color(0.18, 0.42, 0.2), 0.8, 0.0)
		for k in range(70):
			var x: float = rng.randf_range(-130.0, 130.0)
			var z: float = rng.randf_range(-170.0, -18.0)
			if absf(x) < 14.0 and absf(z) < 14.0:
				continue
			var base_y: float = _ground_y(x, z)
			var height: float = rng.randf_range(4.0, 8.0)
			var trunk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.4
			cyl.height = height
			trunk.mesh = cyl
			trunk.position = Vector3(x, base_y + height * 0.5, z)
			trunk.material_override = trunk_mat
			add_child(trunk)
			var crown := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			var r: float = rng.randf_range(1.8, 2.8)
			sphere.radius = r
			sphere.height = r * 2.0
			crown.mesh = sphere
			crown.position = Vector3(x, base_y + height + r * 0.4, z)
			crown.material_override = leaf_mat
			add_child(crown)
	elif style == "desert":
		var rock_mat := _plain(Color(0.45, 0.28, 0.18), 0.95, 0.0)
		for k in range(14):
			var x: float = rng.randf_range(-120.0, 120.0)
			var z: float = rng.randf_range(-160.0, -22.0)
			if absf(x) < 12.0 and absf(z) < 12.0:
				continue
			var h: float = rng.randf_range(4.0, 14.0)
			var mesa := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(rng.randf_range(6.0, 14.0), h, rng.randf_range(6.0, 14.0))
			mesa.mesh = box
			mesa.position = Vector3(x, _ground_y(x, z) + h * 0.5, z)
			mesa.material_override = rock_mat
			add_child(mesa)


func _exit_tree() -> void:
	for node in gear_nodes:
		if is_instance_valid(node):
			(node as Node3D).queue_free()
	gear_nodes.clear()


# ---------------------------------------------------------------- phases

func start_landing() -> void:
	phase = "landing"
	phase_timer = 0.0
	landing_dust.emitting = true


# The survivor is found and signals: the flare goes up, and the battle begins when the signal has been seen.
func start_rescue() -> void:
	phase = "signal"
	phase_timer = 0.0
	landing_dust.emitting = false
	flare.visible = true


func start_boarding() -> void:
	phase = "boarding"
	phase_timer = 0.0
	board_from = survivor.position
	flare.visible = false
	flare_light.light_energy = 0.0


func start_takeoff() -> void:
	phase = "takeoff"
	phase_timer = 0.0
	takeoff_dust.emitting = true
	landing_dust.emitting = false
	survivor.visible = false


func take_hull_damage() -> float:
	var amount: float = pending_damage
	pending_damage = 0.0
	return amount


func update(delta: float, ship_pos: Vector3, fire: bool) -> void:
	time_s += delta
	phase_timer += delta
	sky_planet.rotate_y(planet_spin * delta)
	for layer in cloud_layers:
		(layer as Node3D).rotate_y(delta * 0.01)
	_animate_survivor()
	_animate_boss(delta)
	match phase:
		"signal":
			if phase_timer >= SIGNAL_SECONDS:
				_start_battle()
		"battle":
			_update_battle(delta, ship_pos, fire)
		"boarding":
			_update_boarding()


func _start_battle() -> void:
	phase = "battle"
	phase_timer = 0.0
	spawn_timer = 1.0
	stomp_timer = 2.5
	plasma_timer = 3.5
	flare_light.light_energy = 0.0


# The survivor breathes, raises the flare to signal, and raises the rifle in the battle.
func _animate_survivor() -> void:
	survivor.scale = Vector3.ONE * (1.0 + 0.01 * sin(time_s * 2.2))
	if phase == "signal":
		survivor_arm.rotation.z = 2.7 + sin(time_s * 6.0) * 0.2
		flare_light.light_energy = 2.2 + 1.2 * sin(time_s * 14.0)
	elif phase == "battle":
		survivor_arm.rotation.z = 0.4
		survivor_light.light_energy = 0.4 + 0.6 * sin(time_s * 6.0)
	elif phase == "landing" or phase == "takeoff":
		survivor_arm.rotation.z = 0.4 + sin(time_s * 2.0) * 0.05
	if phase != "boarding":
		survivor_legs[0].rotation.x = 0.0
		survivor_legs[1].rotation.x = 0.0


# The villain walks toward the survivor, stomps, and fires plasma. When it is hit it falls.
func _animate_boss(delta: float) -> void:
	if boss_alive and phase == "battle":
		var to_survivor: Vector3 = Vector3(SURVIVOR_XZ.x, 0.0, SURVIVOR_XZ.z) - Vector3(boss_root.position.x, 0.0, boss_root.position.z)
		if to_survivor.length() > BOSS_STANDOFF:
			var step: Vector3 = to_survivor.normalized() * BOSS_WALK_SPEED * delta
			boss_root.position.x += step.x
			boss_root.position.z += step.z
			boss_walk += delta * 4.0
		else:
			boss_walk += delta * 0.5
		boss_root.position.y = _ground_y(boss_root.position.x, boss_root.position.z) + 2.8
		boss_root.rotation.y = atan2(-to_survivor.x, -to_survivor.z)
		var swing: float = sin(boss_walk) * 0.35
		var legs: Array = boss["legs"]
		legs[0].rotation.x = swing
		legs[1].rotation.x = -swing
		var arms: Array = boss["arms"]
		arms[0].rotation.x = -swing * 0.6
		arms[1].rotation.x = swing * 0.6
	elif not boss_alive:
		boss_fall = minf(boss_fall + delta * 0.5, 1.0)
		boss_root.rotation.x = -boss_fall * 1.2
	var eye: StandardMaterial3D = boss["eye"]
	var pulse: float = 2.4 + 1.2 * sin(time_s * 3.0) if boss_alive else 0.3
	eye.emission_energy_multiplier = pulse


func _update_battle(delta: float, ship_pos: Vector3, fire: bool) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	spawn_timer -= delta
	if raiders_spawned < raiders_total and spawn_timer <= 0.0:
		spawn_timer = SPAWN_INTERVAL
		_spawn_raider()
	_update_raiders(delta)
	if boss_alive:
		stomp_timer -= delta
		if stomp_timer <= 0.0:
			stomp_timer = BOSS_STOMP_SECONDS
			_stomp()
		plasma_timer -= delta
		if plasma_timer <= 0.0:
			plasma_timer = BOSS_PLASMA_SECONDS
			_fire_plasma()
	if fire and fire_cooldown <= 0.0:
		fire_cooldown = FIRE_COOLDOWN
		_fire(ship_pos)
	_update_bolts(delta, ship_pos)
	_update_plasmas(delta, ship_pos)
	if survivor_health <= 0.0:
		survivor_health = 0.0
		outcome = "lost"
	elif not boss_alive and raiders_spawned >= raiders_total and raiders.is_empty():
		outcome = "rescued"


func _spawn_raider() -> void:
	raiders_spawned += 1
	var node := Node3D.new()
	add_child(node)
	RaiderModel.build(node, raider_armour, raider_lights)
	var pos := Vector3(rng.randf_range(-16.0, 16.0), GROUND_Y + rng.randf_range(6.0, 9.0), SPAWN_Z)
	node.position = pos
	raiders.append({"node": node, "pos": pos, "phase": rng.randf() * TAU, "shot": rng.randf_range(1.0, 2.5)})


func _update_raiders(delta: float) -> void:
	var goal: Vector3 = Vector3(SURVIVOR_XZ.x, GROUND_Y + 1.5, SURVIVOR_XZ.z)
	for raider in raiders.duplicate():
		var pos: Vector3 = raider["pos"]
		var to_goal: Vector3 = goal - pos
		var dist: float = to_goal.length()
		if dist < RAIDER_HIT_RANGE:
			survivor_health -= RAIDER_BEAM_DAMAGE * 4.0
			impact_serial += 1
			_explode(pos)
			_remove_raider(raider)
			continue
		var offset: float = float(raider["phase"])
		var wobble := Vector3(sin(time_s * 2.3 + offset), cos(time_s * 1.7 + offset) * 0.5, 0.0)
		pos += (to_goal / dist * RAIDER_SPEED + wobble) * delta
		raider["pos"] = pos
		var node: Node3D = raider["node"]
		node.position = pos
		node.rotation.y = atan2(-to_goal.x, -to_goal.z)
		raider["shot"] = float(raider["shot"]) - delta
		if float(raider["shot"]) <= 0.0 and dist < 95.0:
			raider["shot"] = rng.randf_range(2.4, 3.4)
			_raider_beam(pos)


# A red laser from a raider to the survivor: it hurts, and the impact shakes the camera.
func _raider_beam(from: Vector3) -> void:
	var target: Vector3 = SURVIVOR_XZ + Vector3(0.0, GROUND_Y + 2.0, 0.0)
	var beam := Node3D.new()
	beam.position = (from + target) * 0.5
	add_child(beam)
	beam.look_at(target, Vector3.UP)
	var core := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = from.distance_to(target)
	core.mesh = cyl
	core.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	core.material_override = _glow(Color(1.0, 0.12, 0.1), 3.0)
	beam.add_child(core)
	survivor_health -= RAIDER_BEAM_DAMAGE
	impact_serial += 1
	get_tree().create_timer(0.18).timeout.connect(beam.queue_free)


func _remove_raider(raider: Dictionary) -> void:
	for i in range(raiders.size()):
		if is_same(raiders[i], raider):
			raiders.remove_at(i)
			break
	var node: Node3D = raider["node"]
	if is_instance_valid(node):
		node.queue_free()


# The villain's stomp shakes the ground: the camera shakes, and the survivor is hurt if close.
func _stomp() -> void:
	impact_serial += 1
	var reach: float = Vector2(boss_root.position.x - SURVIVOR_XZ.x, boss_root.position.z - SURVIVOR_XZ.z).length()
	if reach < 16.0:
		survivor_health -= SURVIVOR_STOMP_DAMAGE
		_explode(survivor.position + Vector3(0.0, 0.5, 0.0))


# The villain's plasma: a slow bright orb that flies at the ship. It hits only if the ship is still in its path.
func _fire_plasma() -> void:
	var from: Vector3 = boss_root.position + Vector3(0.0, 15.0, -3.0)
	var target: Vector3 = Vector3(clampf(rng.randf_range(-7.0, 7.0), -7.0, 7.0), 0.0, 0.0)
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.8
	node.mesh = sphere
	node.material_override = _glow(Color(0.5, 1.0, 0.7), 3.0)
	add_child(node)
	node.position = from
	plasmas.append({"node": node, "from": from, "target": target, "t": 0.0})


func _update_plasmas(delta: float, ship_pos: Vector3) -> void:
	for plasma in plasmas.duplicate():
		plasma["t"] = float(plasma["t"]) + delta / PLASMA_TRAVEL
		var t: float = clampf(float(plasma["t"]), 0.0, 1.0)
		var from: Vector3 = plasma["from"]
		var target: Vector3 = plasma["target"]
		var node: Node3D = plasma["node"]
		node.position = from.lerp(target, t)
		if t >= 1.0:
			if absf(ship_pos.x - target.x) < SHIP_X_HIT:
				pending_damage += PLASMA_HIT_DAMAGE
				impact_serial += 1
			_explode(target)
			_remove_plasma(plasma)


func _remove_plasma(plasma: Dictionary) -> void:
	for i in range(plasmas.size()):
		if is_same(plasmas[i], plasma):
			plasmas.remove_at(i)
			break
	var node: Node3D = plasma["node"]
	if is_instance_valid(node):
		node.queue_free()


func _fire(ship_pos: Vector3) -> void:
	var origin: Vector3 = ship_pos + Vector3(0.0, 0.16, -3.0)
	var aim := Vector3(0.0, 0.0, -1.0)
	var best: float = 1.0e9
	for raider in raiders:
		var rpos: Vector3 = raider["pos"]
		var d: float = rpos.distance_to(origin)
		if d < best:
			best = d
			aim = (rpos - origin).normalized()
	if boss_alive:
		var bpos: Vector3 = boss_root.position + Vector3(0.0, 12.0, 0.0)
		if bpos.distance_to(origin) < best:
			aim = (bpos - origin).normalized()
	var node := MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.22
	orb.height = 0.44
	node.mesh = orb
	node.material_override = _glow(Color(0.95, 0.85, 0.6), 1.8)
	node.position = origin
	add_child(node)
	bolts.append({"node": node, "pos": origin, "vel": aim * BOLT_SPEED})


func _update_bolts(delta: float, ship_pos: Vector3) -> void:
	for bolt in bolts.duplicate():
		var bpos: Vector3 = bolt["pos"]
		bpos += bolt["vel"] * delta
		bolt["pos"] = bpos
		var bnode: Node3D = bolt["node"]
		bnode.position = bpos
		var hit: bool = false
		for raider in raiders.duplicate():
			if (raider["pos"] as Vector3).distance_to(bpos) < BOLT_HIT_RANGE:
				_explode(raider["pos"])
				_remove_raider(raider)
				hit = true
				break
		if not hit and boss_alive:
			var center: Vector3 = boss_root.position + Vector3(0.0, 12.0, 0.0)
			if center.distance_to(bpos) < BOSS_HIT_RANGE:
				boss_health -= BOSS_HIT_DAMAGE
				impact_serial += 1
				_explode(bpos)
				hit = true
				if boss_health <= 0.0:
					_boss_down()
		if hit or bpos.distance_to(ship_pos) > 240.0:
			_remove_bolt(bolt)


func _boss_down() -> void:
	boss_alive = false
	boss_health = 0.0
	impact_serial += 2
	_explode(boss_root.position + Vector3(0.0, 12.0, 0.0))


func _remove_bolt(bolt: Dictionary) -> void:
	for i in range(bolts.size()):
		if is_same(bolts[i], bolt):
			bolts.remove_at(i)
			break
	var node: Node3D = bolt["node"]
	if is_instance_valid(node):
		node.queue_free()


# ---------------------------------------------------------------- boarding and take-off

func _update_boarding() -> void:
	var t: float = clampf(phase_timer / BOARD_SECONDS, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, t)
	var step: float = sin(phase_timer * 7.0)
	var target: Vector3 = Vector3(BOARD_POS.x, _ground_y(BOARD_POS.x, BOARD_POS.z), BOARD_POS.z)
	survivor.position = board_from.lerp(target, eased) + Vector3(0.0, absf(step) * 0.05, 0.0)
	for i in range(survivor_legs.size()):
		var leg: Node3D = survivor_legs[i]
		leg.rotation.x = step * 0.45 * (1.0 if i == 1 else -1.0)
	survivor_arm.rotation.x = -step * 0.35
	var dir: Vector3 = target - board_from
	if dir.length() > 0.01:
		survivor.rotation.y = atan2(dir.x, dir.z)
	if t >= 1.0:
		boarded = true


# ---------------------------------------------------------------- helpers

func _make_dust(amount: int, lifetime: float, v_min: float, v_max: float, radius: float, color: Color) -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	dust.amount = amount
	dust.lifetime = lifetime
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = radius
	dust.direction = Vector3.UP
	dust.spread = 65.0
	dust.initial_velocity_min = v_min
	dust.initial_velocity_max = v_max
	dust.gravity = Vector3(0.0, -1.0, 0.0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 3.0
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	var puff_mat := StandardMaterial3D.new()
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_mat
	dust.mesh = puff
	dust.emitting = false
	return dust


func _explode(pos: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 40
	burst.lifetime = 0.9
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.4
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 11.0
	burst.gravity = Vector3(0.0, -4.0, 0.0)
	var spark := SphereMesh.new()
	spark.radius = 0.12
	spark.height = 0.24
	burst.mesh = spark
	burst.material_override = _glow(Color(1.0, 0.55, 0.2), 2.6)
	burst.position = pos
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(1.6).timeout.connect(burst.queue_free)


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	add_child(node)
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
