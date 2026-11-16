extends RefCounted
# The alien villain: a massive armoured biped with three glowing eyes, a plated torso, spiked shoulders and cannon
# arms. Returns the hip pivots (for walking), the arm pivots (for swinging) and the glow materials (for pulsing).

static func build(parent: Node3D, armour: Color, glow_color: Color) -> Dictionary:
	var plate := StandardMaterial3D.new()
	plate.albedo_color = armour
	plate.metallic = 0.5
	plate.roughness = 0.45
	var dark := StandardMaterial3D.new()
	dark.albedo_color = armour * 0.45
	dark.metallic = 0.4
	dark.roughness = 0.6
	var eye := StandardMaterial3D.new()
	eye.albedo_color = glow_color
	eye.emission_enabled = true
	eye.emission = glow_color
	eye.emission_energy_multiplier = 3.0
	var core := StandardMaterial3D.new()
	core.albedo_color = glow_color
	core.emission_enabled = true
	core.emission = glow_color
	core.emission_energy_multiplier = 1.8
	var legs: Array = []
	var arms: Array = []

	# Torso, waist and head.
	_box(parent, Vector3(7.0, 5.5, 4.4), Vector3(0.0, 13.0, 0.0), plate)
	_box(parent, Vector3(5.0, 2.0, 3.6), Vector3(0.0, 9.6, 0.0), dark)
	_box(parent, Vector3(3.2, 2.6, 2.8), Vector3(0.0, 17.8, 0.2), plate)
	_box(parent, Vector3(3.6, 0.7, 2.9), Vector3(0.0, 19.0, 0.15), dark)
	for ex in [-0.9, 0.0, 0.9]:
		_sphere(parent, 0.42, Vector3(ex, 17.9, -1.25), eye)
	# Plates down the spine.
	for k in range(5):
		_box(parent, Vector3(0.5, 1.2, 0.5), Vector3(0.0, 10.5 + float(k) * 1.6, 2.4), dark)
	# Shoulders with spikes.
	for side in [-1.0, 1.0]:
		_sphere(parent, 1.6, Vector3(side * 4.2, 15.2, 0.0), plate)
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.4
		cone.height = 2.4
		spike.mesh = cone
		spike.position = Vector3(side * 4.6, 17.0, 0.0)
		spike.rotation_degrees = Vector3(0.0, 0.0, -side * 20.0)
		spike.material_override = dark
		parent.add_child(spike)
	# Cannon arms: each on a shoulder pivot, with a fist and a glowing muzzle.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 4.6, 14.0, 0.0)
		parent.add_child(arm)
		arms.append(arm)
		_box(arm, Vector3(1.6, 5.0, 1.6), Vector3(0.0, -2.5, 0.0), plate)
		_box(arm, Vector3(1.8, 2.2, 1.8), Vector3(0.0, -5.8, -0.4), dark)
		var barrel := MeshInstance3D.new()
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.5
		barrel_mesh.bottom_radius = 0.5
		barrel_mesh.height = 4.0
		barrel.mesh = barrel_mesh
		barrel.position = Vector3(0.0, -6.0, -2.4)
		barrel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		barrel.material_override = dark
		arm.add_child(barrel)
		_sphere(arm, 0.6, Vector3(0.0, -6.0, -4.5), core)
	# Legs: each hip is a pivot, with a thigh, a shin and a broad foot.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 1.8, 8.4, 0.0)
		parent.add_child(hip)
		legs.append(hip)
		_box(hip, Vector3(2.4, 5.0, 2.4), Vector3(0.0, -2.5, 0.0), plate)
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -5.0, 0.0)
		hip.add_child(knee)
		_box(knee, Vector3(2.0, 5.0, 2.0), Vector3(0.0, -2.5, 0.0), dark)
		_box(knee, Vector3(3.4, 1.2, 4.2), Vector3(0.0, -5.4, -0.8), plate)

	return {"legs": legs, "arms": arms, "eye": eye, "core": core}


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
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
