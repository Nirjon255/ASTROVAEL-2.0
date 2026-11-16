extends RefCounted
# The AST-77 fighter, after the reference image: a long dark hull with swept wings, dorsal fins canted outward,
# twin plasma engines, underwing cannons, a dark canopy and nav lights. The nose points toward -Z.
# Returns the plume meshes, the engine lights and the nav lights (their materials blink in the flight).

const HULL: Color = Color(0.20, 0.22, 0.25)
const PLATE: Color = Color(0.36, 0.39, 0.43)
const DARK: Color = Color(0.09, 0.10, 0.12)


static func build(parent: Node3D) -> Dictionary:
	var hull := _plain(HULL, 0.42, 0.6)
	var plate := _plain(PLATE, 0.36, 0.55)
	var dark := _plain(DARK, 0.55, 0.45)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.03, 0.08, 0.14)
	glass.metallic = 0.9
	glass.roughness = 0.03
	glass.emission_enabled = true
	glass.emission = Color(0.06, 0.2, 0.36)
	glass.emission_energy_multiplier = 0.35
	var accent := _glow(Color(0.35, 0.75, 1.0), 1.0)
	var plasma_core := _glow(Color(0.5, 0.85, 1.0), 2.4)
	var red_nav := _glow(Color(1.0, 0.12, 0.08), 2.2)
	var green_nav := _glow(Color(0.25, 1.0, 0.4), 2.0)
	var strobe := _glow(Color(1.0, 1.0, 1.0), 2.4)
	var plume_mat := StandardMaterial3D.new()
	plume_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plume_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plume_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	plume_mat.albedo_color = Color(0.45, 0.8, 1.0, 0.65)
	var flames: Array = []
	var lights: Array = []
	var nav: Array = []

	# Fuselage in three sections: a sharp nose, a broad middle and a heavier tail.
	_box(parent, Vector3(0.9, 0.42, 1.4), Vector3(0.0, 0.0, -3.0), hull)
	_box(parent, Vector3(0.7, 0.3, 0.8), Vector3(0.0, 0.0, -3.9), plate)
	_box(parent, Vector3(1.2, 0.56, 2.4), Vector3(0.0, 0.0, -1.1), hull)
	_box(parent, Vector3(1.4, 0.7, 2.6), Vector3(0.0, -0.02, 1.8), hull)
	_box(parent, Vector3(1.0, 0.1, 5.5), Vector3(0.0, 0.33, -0.6), plate)
	_box(parent, Vector3(1.3, 0.12, 4.8), Vector3(0.0, -0.36, 0.6), dark)
	# Dark canopy, a stretched dome on the spine.
	var canopy := _sphere(parent, 0.3, Vector3(0.0, 0.36, -1.5), glass)
	canopy.scale = Vector3(0.9, 0.6, 2.2)
	# Dorsal fins, canted outward, with a light on each tip.
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.1, 1.2, 1.4), Vector3(side * 0.42, 0.7, 1.6), plate, Vector3(0.0, 0.0, -side * 18.0))
		var fin_tip := _sphere(parent, 0.07, Vector3(side * 0.9, 1.32, 2.0), red_nav if side < 0.0 else green_nav)
		nav.append([fin_tip.material_override, 0.9 if side < 0.0 else 2.3])
	# Swept wings, with a wing-tip pod and a nav light on each tip.
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(3.2, 0.12, 1.8), Vector3(side * 2.0, -0.04, 0.5), hull, Vector3(0.0, side * -22.0, 0.0))
		_box(parent, Vector3(2.2, 0.04, 0.26), Vector3(side * 2.1, 0.03, -0.4), accent, Vector3(0.0, side * -22.0, 0.0))
		_box(parent, Vector3(0.22, 0.22, 1.1), Vector3(side * 3.7, 0.0, 0.2), plate)
		var tip_nav: StandardMaterial3D = red_nav if side < 0.0 else green_nav
		_sphere(parent, 0.13, Vector3(side * 3.75, 0.0, -0.4), tip_nav)
		nav.append([tip_nav, 0.5 if side < 0.0 else 1.9])
		# Underwing cannon: a barrel with a housing, under each wing.
		_cyl2(parent, 0.09, 0.09, 2.4, Vector3(side * 1.7, -0.3, -0.8), Vector3(90.0, 0.0, 0.0), dark)
		_box(parent, Vector3(0.4, 0.3, 0.9), Vector3(side * 1.7, -0.26, 0.2), plate)
	# Twin plasma engines: a nacelle with an intake, a glowing core and a long blue plume.
	for side in [-1.0, 1.0]:
		var x: float = side * 1.0
		_cyl2(parent, 0.46, 0.4, 2.8, Vector3(x, -0.04, 2.5), Vector3(90.0, 0.0, 0.0), hull)
		_cyl2(parent, 0.4, 0.4, 0.14, Vector3(x, -0.04, 1.1), Vector3(90.0, 0.0, 0.0), dark)
		_cyl2(parent, 0.34, 0.34, 0.06, Vector3(x, -0.04, 3.95), Vector3(90.0, 0.0, 0.0), plasma_core)
		var plume := MeshInstance3D.new()
		var plume_mesh := CylinderMesh.new()
		plume_mesh.top_radius = 0.42
		plume_mesh.bottom_radius = 0.02
		plume_mesh.height = 1.6
		plume.mesh = plume_mesh
		plume.position = Vector3(x, -0.04, 4.8)
		plume.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		plume.material_override = plume_mat
		parent.add_child(plume)
		flames.append(plume)
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.8, 1.0)
		light.light_energy = 1.0
		light.omni_range = 4.5
		light.position = Vector3(x, -0.04, 4.0)
		parent.add_child(light)
		lights.append(light)
	# Blue strips along the flanks, and the AST-77 designation on the port side.
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.02, 0.05, 3.2), Vector3(side * 0.66, 0.02, 0.4), accent)
	var label := Label3D.new()
	label.text = "AST-77"
	label.font_size = 48
	label.pixel_size = 0.012
	label.modulate = Color(0.85, 0.9, 0.95)
	label.position = Vector3(0.66, 0.05, -0.6)
	label.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	parent.add_child(label)
	# Dorsal antenna with a blinking strobe.
	_cyl2(parent, 0.012, 0.012, 0.5, Vector3(0.0, 0.6, 0.6), Vector3.ZERO, dark)
	_sphere(parent, 0.05, Vector3(0.0, 0.86, 0.6), strobe)
	nav.append([strobe, 0.8])
	return {"flames": flames, "lights": lights, "nav": nav}


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


static func _plain(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	# A painted metal panel: the generated albedo, normal and roughness maps, tinted by the colour.
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


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
