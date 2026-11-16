extends RefCounted
# The orbital station, version 30: a command tower of stacked decks with a blue light spine and spires, a glass
# observation dome, a long landing area with six pads, hangar bays, gantries, cargo containers, an outer ring of lit
# modules, docking spires and solar arrays. Returns the window lights, the beacons, the solar pivots and the pad positions.

const RING_RADIUS: float = 46.0
const DECK_Y: float = -5.8


static func build(parent: Node3D) -> Dictionary:
	var hull := _metal(Color(0.7, 0.73, 0.78), 0.3, 0.6)
	var hull_dark := _metal(Color(0.2, 0.22, 0.26), 0.5, 0.5)
	var deck := _metal(Color(0.14, 0.15, 0.18), 0.5, 0.4)
	var deck_mark := _glow(Color(1.0, 0.82, 0.3), 1.6)
	var panel := _metal(Color(0.06, 0.11, 0.24), 0.2, 0.8)
	panel.emission_enabled = true
	panel.emission = Color(0.05, 0.13, 0.36)
	panel.emission_energy_multiplier = 0.5
	var blue := _glow(Color(0.35, 0.75, 1.0), 2.2)
	var amber := _glow(Color(1.0, 0.78, 0.45), 1.2)
	var windows: Array = []
	var beacons: Array = []
	var panels: Array = []
	var pads: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030

	# Command tower: stacked decks that narrow as they rise, each with a band of light.
	var tiers: Array = [[11.0, 3.0, 0.0], [9.0, 3.0, 3.6], [7.5, 2.6, 6.8], [6.0, 2.4, 9.8], [4.2, 2.0, 12.6]]
	for tier in tiers:
		_cyl(parent, float(tier[0]), float(tier[1]), Vector3(0.0, float(tier[2]) + float(tier[1]) * 0.5, 0.0), Vector3.ZERO, hull)
		var band := _glow(Color(0.7, 0.9, 1.0), 1.0)
		_cyl(parent, float(tier[0]) + 0.15, 0.35, Vector3(0.0, float(tier[2]) + float(tier[1]) * 0.45, 0.0), Vector3.ZERO, band)
		windows.append(band)
	_box(parent, Vector3(1.0, 26.0, 0.6), Vector3(0.0, 13.0, 4.7), blue)
	for k in range(4):
		var sa: float = float(k) * TAU / 4.0
		_cyl2(parent, 0.22, 0.02, 9.0, Vector3(cos(sa) * 2.2, 18.5, sin(sa) * 2.2), Vector3.ZERO, hull_dark)
	var tower_top := _glow(Color(0.4, 0.8, 1.0), 1.6)
	_sphere(parent, 0.7, Vector3(0.0, 27.5, 0.0), tower_top)
	beacons.append([tower_top, 0.0])
	for k in range(3):
		var ma: float = float(k) * TAU / 3.0 + 0.4
		var mast_base := Vector3(cos(ma) * 4.0, 14.0, sin(ma) * 4.0)
		_cyl2(parent, 0.12, 0.12, 14.0, mast_base + Vector3(0.0, 7.0, 0.0), Vector3.ZERO, hull_dark)
		var mast_tip := _glow(Color(1.0, 0.3, 0.25), 1.2)
		_sphere(parent, 0.3, mast_base + Vector3(0.0, 14.4, 0.0), mast_tip)
		beacons.append([mast_tip, float(k) * 2.1])

	# Glass observation dome on the right, lit from within.
	var dome := _sphere(parent, 13.0, Vector3(26.0, 3.0, 4.0), _glass())
	dome.scale = Vector3(1.0, 0.55, 1.0)
	var dome_light := _glow(Color(1.0, 0.85, 0.6), 1.3)
	_cyl(parent, 12.0, 0.4, Vector3(26.0, 3.2, 4.0), Vector3.ZERO, dome_light)
	windows.append(dome_light)

	# Landing area: a long deck with yellow markings, six landing pads with corner lights, and a row of hangar bays.
	_box(parent, Vector3(124.0, 2.0, 42.0), Vector3(18.0, -7.0, 0.0), deck)
	_box(parent, Vector3(120.0, 0.3, 38.0), Vector3(18.0, DECK_Y + 0.05, 0.0), hull_dark)
	for k in range(9):
		_box(parent, Vector3(0.4, 0.1, 34.0), Vector3(-36.0 + float(k) * 12.0, DECK_Y + 0.12, 0.0), deck_mark)
	for k in range(6):
		var pad_pos := Vector3(-40.0 + float(k) * 16.0, DECK_Y, -8.0)
		_box(parent, Vector3(8.0, 0.1, 8.0), pad_pos + Vector3(0.0, 0.08, 0.0), deck_mark)
		_box(parent, Vector3(5.6, 0.12, 5.6), pad_pos + Vector3(0.0, 0.1, 0.0), deck)
		for corner in [Vector3(4.2, 0.0, 4.2), Vector3(-4.2, 0.0, 4.2), Vector3(4.2, 0.0, -4.2), Vector3(-4.2, 0.0, -4.2)]:
			_sphere(parent, 0.22, pad_pos + corner + Vector3(0.0, 0.2, 0.0), amber)
		pads.append(pad_pos)
	for k in range(3):
		var bx: float = -30.0 + float(k) * 30.0
		_box(parent, Vector3(14.0, 7.0, 1.2), Vector3(bx, -2.0, 20.6), hull_dark)
		_box(parent, Vector3(10.0, 4.0, 0.2), Vector3(bx, -2.0, 20.0), amber)
	for gz in [-14.0, 14.0]:
		_box(parent, Vector3(120.0, 1.2, 1.2), Vector3(18.0, 4.0, gz), hull_dark)
		for gx in [-40.0, 76.0]:
			_box(parent, Vector3(1.4, 8.0, 1.4), Vector3(gx, 0.0, gz), hull_dark)
	var container_colors: Array = [Color(0.85, 0.45, 0.15), Color(0.6, 0.62, 0.66), Color(0.2, 0.45, 0.75), Color(0.9, 0.9, 0.92)]
	for k in range(24):
		var cx: float = rng.randf_range(-36.0, 66.0)
		var cz: float = rng.randf_range(-16.0, 16.0)
		if absf(cz + 8.0) < 6.0 and absf(cx - round((cx + 40.0) / 16.0) * 16.0 + 40.0) < 6.0:
			continue
		var container := _metal(container_colors[k % container_colors.size()], 0.45, 0.35)
		_box(parent, Vector3(4.2, 2.5, 2.2), Vector3(cx, DECK_Y + 1.3, cz), container, Vector3(0.0, rng.randf_range(-6.0, 6.0), 0.0))

	# The outer ring: lit modules in two levels, joined by struts and spokes.
	var segments: int = 56
	for level in [-2.6, 2.6]:
		for i in range(segments):
			var a: float = float(i) / float(segments) * TAU
			var pos := Vector3(cos(a) * RING_RADIUS, float(level), sin(a) * RING_RADIUS)
			var rot := Vector3(0.0, -rad_to_deg(a), 0.0)
			_box(parent, Vector3(5.2, 3.2, 4.4), pos, hull if i % 3 != 0 else hull_dark, rot)
			var strip := _glow(Color(1.0, 0.86, 0.62), 1.0) if i % 2 == 0 else blue
			_box(parent, Vector3(4.8, 0.35, 0.16), pos + Vector3(cos(a) * 2.25, 0.8, sin(a) * 2.25), strip, rot)
			windows.append(strip)
	for k in range(16):
		var sa: float = float(k) * TAU / 16.0
		_box(parent, Vector3(1.2, 5.6, 1.2), Vector3(cos(sa) * RING_RADIUS, 0.0, sin(sa) * RING_RADIUS), hull_dark)

	# Docking spires hang below the ring, with blue lights.
	for k in range(6):
		var da: float = float(k) * TAU / 6.0 + 0.3
		var spire_pos := Vector3(cos(da) * (RING_RADIUS - 6.0), -12.0, sin(da) * (RING_RADIUS - 6.0))
		_cyl2(parent, 2.2, 0.8, 16.0, spire_pos, Vector3.ZERO, hull_dark)
		var spire_light := _glow(Color(0.35, 0.8, 1.0), 1.4)
		_sphere(parent, 0.5, spire_pos + Vector3(0.0, -8.6, 0.0), spire_light)
		beacons.append([spire_light, float(k) * 1.3])

	# Two solar arrays on booms at the back, each on a pivot that turns to face the sun.
	for k in [0, 1]:
		var pivot := Node3D.new()
		var side: float = -1.0 if k == 0 else 1.0
		pivot.position = Vector3(-52.0, 0.0, side * 16.0)
		parent.add_child(pivot)
		panels.append(pivot)
		_box(pivot, Vector3(0.6, 0.6, 14.0), Vector3(0.0, 0.0, 0.0), hull_dark)
		_box(pivot, Vector3(18.0, 0.2, 7.0), Vector3(0.0, 0.0, 9.0), panel)
		_box(pivot, Vector3(18.0, 0.2, 7.0), Vector3(0.0, 0.0, -9.0), panel)

	return {"windows": windows, "beacons": beacons, "panels": panels, "pads": pads}


static func _glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.6, 0.8, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.6
	glass.roughness = 0.05
	return glass


static func _metal(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = load("res://assets/metal_station_albedo.png")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/metal_station_normal.png")
	material.roughness_texture = load("res://assets/metal_station_roughness.png")
	material.roughness = roughness
	material.metallic = metallic
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = mat
	parent.add_child(node)
	return node


static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	return _cyl2(parent, radius, radius, height, pos, rot, mat)


static func _cyl2(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rot
	node.material_override = mat
	parent.add_child(node)
	return node


static func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
