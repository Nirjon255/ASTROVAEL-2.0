extends RefCounted
# The endless route. One route unit = 1,000 miles.
# Stops are visited in order. The first six are the real planets from Venus outward
# (Venus is the closest approach from Earth, 23.7 million miles). Every later stop is generated
# from a fixed seed, so the route never runs out and always comes out the same.
# The gap between stops after Venus is shortened, so a planet arrives every few minutes.
# Each galaxy is STOPS_PER_GALAXY stops; the gap between galaxies is a warp segment.

const UNIT_MILES: float = 1000.0
const Campaign = preload("res://scripts/campaign.gd")
const WARP_GAP_UNITS: float = 2600.0
const STOPS_PER_GALAXY: int = 6

const REAL_STOPS := [
	{
		"name": "VENUS", "type": "Volcanic cloud world", "seg": 23700.0, "radius": 120.0,
		"gravity": 0.90, "temp": 464, "moons": 0,
		"texture": "res://assets/venus_surface.png", "cloud": "", "tint": Color(1, 1, 1),
		"atmos": Color(1.0, 0.82, 0.45), "atmos_i": 1.9, "tilt": 177.4, "ring": false,
		"fog": Color(0.95, 0.76, 0.42), "fog_d": 0.00022, "ambient": Color(1.0, 0.86, 0.6), "spin": 0.012,
	},
	{
		"name": "MARS", "type": "Dusty red desert world", "seg": 9000.0, "radius": 90.0,
		"gravity": 0.38, "temp": -63, "moons": 2,
		"texture": "res://assets/mars_surface.png", "cloud": "", "tint": Color(1, 1, 1),
		"atmos": Color(0.95, 0.56, 0.36), "atmos_i": 0.9, "tilt": 25.2, "ring": false,
		"fog": Color(0.80, 0.48, 0.32), "fog_d": 0.00010, "ambient": Color(0.9, 0.6, 0.45), "spin": 0.03,
	},
	{
		"name": "JUPITER", "type": "Gas giant", "seg": 18000.0, "radius": 420.0,
		"gravity": 2.53, "temp": -110, "moons": 95,
		"texture": "res://assets/jupiter_surface.png", "cloud": "", "tint": Color(1, 1, 1),
		"atmos": Color(0.95, 0.80, 0.60), "atmos_i": 1.0, "tilt": 3.1, "ring": false,
		"fog": Color(0.60, 0.50, 0.38), "fog_d": 0.00005, "ambient": Color(0.95, 0.85, 0.7), "spin": 0.05,
	},
	{
		"name": "SATURN", "type": "Ringed gas giant", "seg": 16000.0, "radius": 360.0,
		"gravity": 1.07, "temp": -178, "moons": 146,
		"texture": "res://assets/saturn_surface.png", "cloud": "", "tint": Color(1, 1, 1),
		"atmos": Color(0.95, 0.88, 0.60), "atmos_i": 0.8, "tilt": 26.7, "ring": true,
		"fog": Color(0.80, 0.72, 0.50), "fog_d": 0.00005, "ambient": Color(0.95, 0.9, 0.7), "spin": 0.04,
	},
	{
		"name": "URANUS", "type": "Ice giant, tilted on its side", "seg": 18000.0, "radius": 200.0,
		"gravity": 0.89, "temp": -195, "moons": 28,
		"texture": "res://assets/uranus_surface.png", "cloud": "", "tint": Color(1, 1, 1),
		"atmos": Color(0.50, 0.90, 0.95), "atmos_i": 1.1, "tilt": 97.8, "ring": false,
		"fog": Color(0.45, 0.85, 0.90), "fog_d": 0.00012, "ambient": Color(0.6, 0.9, 0.95), "spin": 0.03,
	},
	{
		"name": "NEPTUNE", "type": "Deep blue ice giant", "seg": 20000.0, "radius": 190.0,
		"gravity": 1.14, "temp": -200, "moons": 16,
		"texture": "res://assets/neptune_surface.png", "cloud": "", "tint": Color(1, 1, 1),
		"atmos": Color(0.25, 0.45, 1.0), "atmos_i": 1.2, "tilt": 28.3, "ring": false,
		"fog": Color(0.20, 0.40, 0.95), "fog_d": 0.00012, "ambient": Color(0.5, 0.6, 1.0), "spin": 0.03,
	},
]

const GALAXY_NAMES := ["MILKY WAY", "ANDROMEDA REACH", "VELA SPIRAL", "LYRA DRIFT", "PERSEUS VOID", "CENTAURUS SHOAL"]
const SYLLABLES := ["VAEL", "ORIS", "KEPRA", "THAL", "NYX", "SORA", "DRAX", "LUMEN", "HELIO", "QUAR", "ZEPH", "ILUN", "ASTRA", "VORN", "MYRA", "TAURO"]
const PROC_TYPES := [
	{"type": "Ocean world", "texture": "res://assets/planet_surface_1.png", "cloud": "res://assets/planet_clouds_1.png", "atmos": Color(0.25, 0.6, 1.0), "tint": Color(0.7, 0.85, 1.0)},
	{"type": "Crystal desert", "texture": "res://assets/planet_surface_2.png", "cloud": "", "atmos": Color(1.0, 0.7, 0.4), "tint": Color(1.0, 0.8, 0.6)},
	{"type": "Frozen world", "texture": "res://assets/planet_surface_3.png", "cloud": "", "atmos": Color(0.6, 0.85, 1.0), "tint": Color(0.85, 0.95, 1.0)},
	{"type": "Lava world", "texture": "res://assets/planet_surface_2.png", "cloud": "", "atmos": Color(1.0, 0.4, 0.2), "tint": Color(1.0, 0.45, 0.25)},
	{"type": "Methane world", "texture": "res://assets/planet_surface_3.png", "cloud": "res://assets/planet_clouds_2.png", "atmos": Color(0.75, 0.6, 1.0), "tint": Color(0.75, 0.65, 0.95)},
]

var _planets: Array = []
var _units: Array = []


static func earth_data() -> Dictionary:
	return {
		"name": "EARTH", "radius": 340.0,
		"texture": "res://assets/earth_surface.png", "cloud": "res://assets/earth_clouds.png",
		"tint": Color(1, 1, 1), "atmos": Color(0.30, 0.62, 1.0), "atmos_i": 1.6,
		"tilt": 23.4, "ring": false, "spin": 0.02,
	}


func planet(index: int) -> Dictionary:
	_extend_to(index)
	return _planets[index]


# Route units from the start to the arrival at planet `index`.
func units(index: int) -> float:
	_extend_to(index)
	return float(_units[index])


func galaxy_name(galaxy: int) -> String:
	if galaxy < GALAXY_NAMES.size():
		return GALAXY_NAMES[galaxy]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + galaxy * 131
	return "%s REACH %d" % [SYLLABLES[rng.randi_range(0, SYLLABLES.size() - 1)], galaxy + 1]


# Colours and band direction for the galaxy sky. Milky Way keeps the original look.
func galaxy_palette(galaxy: int) -> Dictionary:
	if galaxy == 0:
		return {
			"band_normal": Vector3(0.32, 0.92, 0.22),
			"band_color": Color(0.52, 0.47, 0.40),
			"nebula": Color(0.34, 0.18, 0.22),
			"star_a": Color(0.96, 0.88, 0.76),
			"star_b": Color(1.0, 0.86, 0.66),
			"accent": Color(0.96, 0.74, 0.46),
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + galaxy * 997
	var hue: float = fposmod(0.1 + float(galaxy) * 0.381966, 1.0)
	var normal := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	return {
		"band_normal": normal,
		"band_color": Color.from_hsv(hue, 0.3, 0.6),
		"nebula": Color.from_hsv(fposmod(hue + 0.15, 1.0), 0.5, 0.5),
		"star_a": Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.2, 0.92),
		"star_b": Color.from_hsv(hue, 0.4, 1.0),
		"accent": Color.from_hsv(fposmod(hue + 0.08, 1.0), 0.6, 0.85),
	}


func _extend_to(index: int) -> void:
	while _planets.size() <= index:
		var i: int = _planets.size()
		var data: Dictionary = _make_stop(i)
		var previous: float = 0.0 if i == 0 else float(_units[i - 1])
		data["units"] = previous + float(data["seg"])
		_units.append(data["units"])
		_planets.append(data)


func _make_stop(i: int) -> Dictionary:
	var galaxy: int = i / STOPS_PER_GALAXY
	var warp: bool = i > 0 and i % STOPS_PER_GALAXY == 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i * 7919
	var data: Dictionary
	if i < REAL_STOPS.size():
		data = REAL_STOPS[i].duplicate(true)
	else:
		data = _procedural(i, rng)
	data["index"] = i
	data["galaxy"] = galaxy
	data["warp_before"] = warp
	data["seg"] = WARP_GAP_UNITS if warp else float(data["seg"])
	# The route passes each planet to one side, never through it.
	data["lane_x"] = rng.randf_range(170.0, 240.0) * (-1.0 if i % 2 == 0 else 1.0)
	data["lane_y"] = rng.randf_range(30.0, 120.0)
	return Campaign.apply_to_stop(i, data)


func _procedural(i: int, rng: RandomNumberGenerator) -> Dictionary:
	var kind: Dictionary = PROC_TYPES[rng.randi_range(0, PROC_TYPES.size() - 1)]
	var syllable: String = SYLLABLES[rng.randi_range(0, SYLLABLES.size() - 1)]
	var atmos: Color = kind["atmos"]
	var tint: Color = kind["tint"]
	return {
		"name": "%s-%03d" % [syllable, i + 1],
		"type": kind["type"],
		"seg": rng.randf_range(6000.0, 14000.0),
		"radius": rng.randf_range(90.0, 230.0),
		"gravity": rng.randf_range(0.4, 2.2),
		"temp": rng.randi_range(-150, 180),
		"moons": rng.randi_range(0, 6),
		"texture": kind["texture"],
		"cloud": kind["cloud"],
		"tint": tint,
		"atmos": atmos,
		"atmos_i": rng.randf_range(0.8, 1.6),
		"tilt": rng.randf_range(0.0, 40.0),
		"ring": rng.randf() < 0.15,
		"fog": atmos * 0.8,
		"fog_d": 0.00008,
		"ambient": tint,
		"spin": rng.randf_range(0.01, 0.05),
	}
