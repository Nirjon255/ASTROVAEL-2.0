extends RefCounted
# Rift Raider, version 30: a hostile attack craft with a long armoured fuselage, a dorsal ridge with ribs, a canopy
# with a sensor bulge, swept wings with weapon pods, three engines with exhaust, and a sensor spike. The armour and the
# warning lights take the planet's colours. The nose points toward -Z. Returns the light material (so the caller can pulse
# it) and the exhaust plumes.

static func build(parent: Node3D, armour_color: Color = Color(0.09, 0.09, 0.11), light_color: Color = Color(1.0, 0.12, 0.1)) -> Dictionary:
	var armour := _metal(armour_color, 0.45, 0.6)
	var armour_dark := _metal(armour_color * 0.55, 0.6, 0.5)
	var panel := _metal(armour_color * 1.25, 0.4, 0.55)
	var canopy := StandardMaterial3D.new()
	canopy.albedo_color = Color(0.05, 0.1, 0.08)
	canopy.metallic = 0.9
	canopy.roughness = 0.05
	canopy.emission_enabled = true
	canopy.emission = light_color * 0.3
	canopy.emission_energy_multiplier = 0.8
	var warn := StandardMaterial3D.new()
	warn.albedo_color = light_color
	warn.emission_enabled = true
	warn.emission = light_color
	warn.emission_energy_multiplier = 1.8
	var exhaust := StandardMaterial3D.new()
	exhaust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	exhaust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	exhaust.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	exhaust.albedo_color = Color(light_color.r, light_color.g * 0.6, light_color.b * 0.4, 0.7)

	# Fuselage: a sharp nose, a broad middle, and a heavier rear section.
	_box(parent, Vector3(0.9, 0.5, 1.6), Vector3(0.0, 0.0, -2.6), armour)
	_box(parent, Vector3(0.5, 0.3, 0.9), Vector3(0.0, 0.02, -3.6), armour_dark)
	_box(parent, Vector3(1.3, 0.62, 2.6), Vector3(0.0, -0.02, -0.6), armour)
	_box(parent, Vector3(1.6, 0.8, 2.2), Vector3(0.0, -0.05, 1.6), armour_dark)
	# Dorsal ridge with ribs, and a sensor bulge on top.
	_box(parent, Vector3(0.4, 0.18, 4.2), Vector3(0.0, 0.38, -0.6), panel)
	for k in range(4):
		_box(parent, Vector3(0.52, 0.22, 0.12), Vector3(0.0, 0.36, -2.0 + float(k) * 1.1), armour_dark)
	var bulge := _sphere(parent, 0.34, Vector3(0.0, 0.42, -1.8), canopy)
	bulge.scale = Vector3(1.0, 0.7, 1.5)
	# Swept wings with weapon pods and a light along each leading edge.
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(2.7, 0.1, 1.6), Vector3(side * 1.55, -0.08, 0.2), panel, Vector3(0.0, side * -28.0, 0.0))
		_box(parent, Vector3(1.8, 0.05, 0.12), Vector3(side * 1.65, 0.0, -0.55), warn, Vector3(0.0, side * -28.0, 0.0))
		_box(parent, Vector3(0.32, 0.32, 1.7), Vector3(side * 1.9, -0.28, -0.4), armour_dark)
		_sphere(parent, 0.14, Vector3(side * 1.9, -0.28, -1.3), warn)
		_box(parent, Vector3(0.1, 0.7, 1.0), Vector3(side * 3.0, 0.3, 0.3), armour, Vector3(0.0, 0.0, -side * 14.0))
	# Three engines at the rear: a centre nozzle and two outer nozzles, each with a glowing core.
	var flames: Array = []
	for x in [-0.5, 0.0, 0.5]:
		var outer: float = absf(x) * 2.0
		_cyl(parent, 0.22 - outer * 0.02, 0.28, 0.9, Vector3(x, -0.05, 2.9), Vector3(90.0, 0.0, 0.0), armour_dark)
		_cyl(parent, 0.17, 0.17, 0.05, Vector3(x, -0.05, 3.4), Vector3(90.0, 0.0, 0.0), warn)
		var plume := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2
		cone.bottom_radius = 0.02
		cone.height = 1.2
		plume.mesh = cone
		plume.position = Vector3(x, -0.05, 4.0)
		plume.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		plume.material_override = exhaust
		parent.add_child(plume)
		flames.append(plume)
	# A sensor spike at the nose, and warning strips along the flanks.
	_cyl(parent, 0.02, 0.02, 1.2, Vector3(0.0, 0.1, -4.2), Vector3(-90.0, 0.0, 0.0), armour_dark)
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.04, 0.08, 2.2), Vector3(side * 0.66, 0.08, -0.4), warn)
	return {"light": warn, "flames": flames}


static func _metal(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = load("res://assets/metal_hull_albedo.png")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/metal_hull_normal.png")
	material.roughness_texture = load("res://assets/metal_hull_roughness.png")
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


static func _cyl(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
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
