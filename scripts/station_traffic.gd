extends Node3D
# Traffic around the orbital station, version 30: patrol craft and freighters fly lanes around the station, while shuttles
# come in on approach paths, land on the station's pads, wait, and take off again. Ships are built from the shared models.

const ShipModel = preload("res://scripts/ship_model.gd")
const LAND_SECONDS: float = 26.0
const PAUSE_SECONDS: float = 7.0
const TAKEOFF_SECONDS: float = 22.0
const REST_SECONDS: float = 6.0

var station_root: Node3D
var pads: Array = []
var time_s: float = 0.0
var lanes: Array = []
var shuttles: Array = []


# station_root is the station's rotating root; pad_positions are the pads' positions in that root's space.
func setup(root: Node3D, pad_positions: Array) -> void:
	station_root = root
	pads = pad_positions
	for i in range(8):
		var node := Node3D.new()
		add_child(node)
		var flames: Array = []
		if i % 3 == 2:
			_build_freighter(node)
		else:
			flames = ShipModel.build(node)["flames"]
		lanes.append({
			"node": node,
			"radius": 58.0 + float(i % 4) * 9.0,
			"height": -6.0 + float(i) * 2.0,
			"speed": 0.05 + 0.01 * float(i % 3),
			"phase": float(i) * 0.8,
			"flames": flames,
		})
	for k in range(pads.size()):
		var node := Node3D.new()
		add_child(node)
		var built: Dictionary = ShipModel.build(node)
		shuttles.append({
			"node": node,
			"pad": k,
			"timer": float(k) * 5.0,
			"flames": built["flames"],
		})


func _process(delta: float) -> void:
	time_s += delta
	for lane in lanes:
		var a: float = time_s * float(lane["speed"]) + float(lane["phase"])
		var r: float = float(lane["radius"])
		var node: Node3D = lane["node"]
		node.position = Vector3(cos(a) * r, float(lane["height"]) + sin(a * 2.0) * 1.5, sin(a) * r)
		_face(node, Vector3(-sin(a), 0.0, cos(a)))
		_pulse(lane["flames"])
	if station_root == null:
		return
	for shuttle in shuttles:
		_update_shuttle(shuttle, delta)


# One shuttle's cycle: an approach from high above, a landing on its pad, a pause, a take-off and a rest.
func _update_shuttle(s: Dictionary, delta: float) -> void:
	s["timer"] = float(s["timer"]) + delta
	var cycle: float = LAND_SECONDS + PAUSE_SECONDS + TAKEOFF_SECONDS + REST_SECONDS
	var t: float = fmod(float(s["timer"]), cycle)
	var node: Node3D = s["node"]
	var pad_world: Vector3 = station_root.to_global(pads[int(s["pad"])])
	var top: Vector3 = pad_world + Vector3(0.0, 10.0, 0.0)
	var far: Vector3 = pad_world + Vector3(0.0, 70.0, 150.0)
	var pos: Vector3 = pad_world
	node.visible = true
	if t < LAND_SECONDS:
		var p: float = t / LAND_SECONDS
		if p < 0.8:
			pos = far.lerp(top, smoothstep(0.0, 1.0, p / 0.8))
		else:
			pos = top.lerp(pad_world + Vector3(0.0, 0.8, 0.0), smoothstep(0.0, 1.0, (p - 0.8) / 0.2))
	elif t < LAND_SECONDS + PAUSE_SECONDS:
		pos = pad_world + Vector3(0.0, 0.8, 0.0)
	elif t < LAND_SECONDS + PAUSE_SECONDS + TAKEOFF_SECONDS:
		var q: float = (t - LAND_SECONDS - PAUSE_SECONDS) / TAKEOFF_SECONDS
		if q < 0.2:
			pos = pad_world + Vector3(0.0, 0.8, 0.0)
		elif q < 0.5:
			pos = (pad_world + Vector3(0.0, 0.8, 0.0)).lerp(top, smoothstep(0.0, 1.0, (q - 0.2) / 0.3))
		else:
			pos = top.lerp(far, smoothstep(0.0, 1.0, (q - 0.5) / 0.5))
	else:
		node.visible = false
		return
	var velocity: Vector3 = pos - node.position
	node.position = pos
	if velocity.length() > 0.001:
		_face(node, velocity)
	_pulse(s["flames"])


func _pulse(flames: Array) -> void:
	for flame in flames:
		(flame as Node3D).scale = Vector3(1.0, 1.0, 0.9 + 0.15 * sin(time_s * 30.0))


func _face(node: Node3D, dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var up: Vector3 = Vector3.UP
	if absf(dir.normalized().y) > 0.98:
		up = Vector3.FORWARD
	node.look_at(node.global_position + dir, up)


# A freighter: a long hull with cargo containers on its back and two engine pods.
func _build_freighter(node: Node3D) -> void:
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.5, 0.52, 0.56)
	hull.metallic = 0.5
	hull.roughness = 0.45
	_box(node, Vector3(2.4, 1.4, 9.0), Vector3.ZERO, hull)
	var colors: Array = [Color(0.85, 0.45, 0.15), Color(0.2, 0.45, 0.75), Color(0.6, 0.62, 0.66)]
	for k in range(3):
		var box := StandardMaterial3D.new()
		box.albedo_color = colors[k]
		box.metallic = 0.3
		box.roughness = 0.5
		_box(node, Vector3(1.9, 1.2, 2.4), Vector3(0.0, 1.2, -2.4 + float(k) * 2.4), box)
	var engine_glow := StandardMaterial3D.new()
	engine_glow.albedo_color = Color(0.5, 0.8, 1.0)
	engine_glow.emission_enabled = true
	engine_glow.emission = Color(0.5, 0.8, 1.0)
	engine_glow.emission_energy_multiplier = 2.0
	for side in [-0.9, 0.9]:
		var pod := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 2.2
		pod.mesh = cyl
		pod.position = Vector3(side, -0.1, 5.1)
		pod.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		pod.material_override = hull
		node.add_child(pod)
		var core := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.38
		disc.bottom_radius = 0.38
		disc.height = 0.06
		core.mesh = disc
		core.position = Vector3(side, -0.1, 6.25)
		core.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		core.material_override = engine_glow
		node.add_child(core)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node
