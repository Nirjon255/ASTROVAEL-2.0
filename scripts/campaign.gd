extends RefCounted
# The campaign: rescue missions on named worlds, in the order the player reaches them. Each mission starts from the
# station, and its target is a route stop. Named worlds replace the first stops, so the planets, universes, survivors
# and threats match the design. Set USE_CAMPAIGN_NAMES to false to keep the route's own names and looks.

const USE_CAMPAIGN_NAMES: bool = true

const STOPS := [0, 1, 2, 3, 4, 5, 7, 8, 9, 10]

const MISSIONS := [
	{
		"stop": 0, "name": "AQUARIS", "universe": "ANDROMEDA REACH", "type": "Blue ocean world",
		"texture": "res://assets/earth_surface.png", "cloud": "res://assets/earth_clouds.png",
		"tint": Color(0.75, 0.9, 1.0), "atmos": Color(0.35, 0.75, 1.0), "atmos_i": 1.5,
		"fog": Color(0.2, 0.55, 0.85), "fog_d": 0.00012, "ambient": Color(0.5, 0.75, 0.95),
		"gravity": 1.0, "temp": 14, "moons": 1, "radius": 130.0, "tilt": 23.4, "ring": false, "spin": 0.02,
		"style": "ocean",
		"raider": {"armour": Color(0.1, 0.2, 0.24), "lights": Color(0.2, 0.95, 0.9)},
		"survivor_role": "SETTLEMENT ENGINEER", "survivor_suit": Color(0.2, 0.85, 0.85),
		"briefing": "A stranded engineer is keeping the last working emergency beacon alive, on floating platforms above the storm bands.",
		"threat": "Raider fighters are circling the settlement and trying to destroy the beacon.",
	},
	{
		"stop": 1, "name": "PYRAX", "universe": "ORION FRONTIER", "type": "Red desert frontier world",
		"texture": "res://assets/mars_surface.png", "cloud": "",
		"tint": Color(1.0, 0.85, 0.75), "atmos": Color(1.0, 0.5, 0.25), "atmos_i": 1.1,
		"fog": Color(0.8, 0.45, 0.28), "fog_d": 0.00016, "ambient": Color(0.95, 0.6, 0.42),
		"gravity": 0.6, "temp": -20, "moons": 2, "radius": 100.0, "tilt": 25.2, "ring": false, "spin": 0.03,
		"style": "desert",
		"raider": {"armour": Color(0.35, 0.25, 0.18), "lights": Color(1.0, 0.55, 0.15)},
		"survivor_role": "FIELD MEDIC", "survivor_suit": Color(1.0, 0.45, 0.2),
		"briefing": "A young field medic is sheltering injured colonists inside a remote research outpost, under a dust storm.",
		"threat": "Raider gunships and ground-to-space defence batteries.",
	},
	{
		"stop": 2, "name": "NYXARA", "universe": "VEIL NEBULA", "type": "Violet crystal world",
		"texture": "res://assets/planet_surface_3.png", "cloud": "res://assets/planet_clouds_2.png",
		"tint": Color(0.8, 0.65, 1.0), "atmos": Color(0.7, 0.45, 1.0), "atmos_i": 1.6,
		"fog": Color(0.45, 0.25, 0.75), "fog_d": 0.00014, "ambient": Color(0.7, 0.55, 1.0),
		"gravity": 1.1, "temp": 18, "moons": 3, "radius": 150.0, "tilt": 12.0, "ring": false, "spin": 0.025,
		"style": "crystal",
		"raider": {"armour": Color(0.18, 0.1, 0.28), "lights": Color(0.75, 0.4, 1.0)},
		"survivor_role": "SCIENTIST", "survivor_suit": Color(0.55, 0.35, 0.95),
		"briefing": "A local scientist may explain why the hostile force is attacking remote settlements.",
		"threat": "Faster interceptors arrive in waves, with an ambush near the extraction point.",
	},
	{
		"stop": 3, "name": "SATURN", "universe": "MILKY WAY", "type": "Ringed gas giant",
		"texture": "res://assets/saturn_surface.png", "cloud": "",
		"tint": Color(1.0, 1.0, 1.0), "atmos": Color(0.95, 0.88, 0.6), "atmos_i": 0.8,
		"fog": Color(0.8, 0.72, 0.5), "fog_d": 0.00005, "ambient": Color(0.95, 0.9, 0.7),
		"gravity": 1.07, "temp": -178, "moons": 146, "radius": 360.0, "tilt": 26.7, "ring": true, "spin": 0.04,
		"style": "ice",
		"raider": {"armour": Color(0.72, 0.74, 0.8), "lights": Color(0.45, 0.9, 1.0)},
		"survivor_role": "ICE RESEARCHER", "survivor_suit": Color(0.92, 0.86, 0.7),
		"briefing": "A research crew is stranded on an ice shelf beneath the rings, with their power failing in the cold.",
		"threat": "Ice-hardened raider gunships are cutting off the only route off the shelf.",
	},
	{
		"stop": 4, "name": "FROSTHAVEN", "universe": "BOREAL DRIFT", "type": "Frozen world",
		"texture": "res://assets/planet_surface_3.png", "cloud": "",
		"tint": Color(0.85, 0.95, 1.0), "atmos": Color(0.6, 0.85, 1.0), "atmos_i": 1.1,
		"fog": Color(0.5, 0.7, 0.9), "fog_d": 0.00012, "ambient": Color(0.7, 0.85, 1.0),
		"gravity": 0.9, "temp": -60, "moons": 1, "radius": 120.0, "tilt": 15.0, "ring": false, "spin": 0.02,
		"style": "ice",
		"raider": {"armour": Color(0.55, 0.6, 0.7), "lights": Color(0.4, 0.9, 1.0)},
		"survivor_role": "ARCTIC RANGER", "survivor_suit": Color(0.8, 0.85, 0.9),
		"briefing": "A ranger's patrol is pinned down beside a frozen sea, with their generator failing in the cold.",
		"threat": "Ice-hardened raiders are closing in on the patrol from the far shore.",
	},
	{
		"stop": 5, "name": "VERDANTIS", "universe": "EMERALD REACH", "type": "Lush forest world",
		"texture": "res://assets/earth_surface.png", "cloud": "res://assets/earth_clouds.png",
		"tint": Color(0.6, 1.0, 0.6), "atmos": Color(0.4, 0.9, 0.5), "atmos_i": 1.4,
		"fog": Color(0.2, 0.6, 0.3), "fog_d": 0.00014, "ambient": Color(0.5, 0.9, 0.6),
		"gravity": 1.0, "temp": 22, "moons": 2, "radius": 125.0, "tilt": 20.0, "ring": false, "spin": 0.025,
		"style": "forest",
		"raider": {"armour": Color(0.12, 0.2, 0.14), "lights": Color(0.6, 1.0, 0.3)},
		"survivor_role": "JUNGLE COMMANDO", "survivor_suit": Color(0.25, 0.45, 0.25),
		"briefing": "A commando team is holding a canopy outpost as the hostile force moves through the trees.",
		"threat": "Stealth raiders drop from the canopy and cut off the extraction route.",
	},
	{
		"stop": 7, "name": "ILON-008", "universe": "PERSEUS VOID", "type": "Volcanic basalt world",
		"texture": "res://assets/mars_surface.png", "cloud": "",
		"tint": Color(0.9, 0.6, 0.5), "atmos": Color(1.0, 0.35, 0.15), "atmos_i": 1.4,
		"fog": Color(0.5, 0.2, 0.1), "fog_d": 0.0002, "ambient": Color(0.9, 0.45, 0.3),
		"gravity": 0.8, "temp": 380, "moons": 0, "radius": 110.0, "tilt": 8.0, "ring": false, "spin": 0.02,
		"style": "lava",
		"raider": {"armour": Color(0.14, 0.08, 0.07), "lights": Color(1.0, 0.45, 0.05)},
		"survivor_role": "SURVEY PILOT", "survivor_suit": Color(1.0, 0.7, 0.2),
		"briefing": "A survey pilot is trapped beside a lava field, with the last working relay cracking in the heat.",
		"threat": "Heavy raider interceptors are hunting for the relay, dropping out of the glow of the lava.",
	},
	{
		"stop": 8, "name": "INFERNUS", "universe": "CINDER BELT", "type": "Volcanic world",
		"texture": "res://assets/planet_surface_2.png", "cloud": "",
		"tint": Color(1.0, 0.6, 0.4), "atmos": Color(1.0, 0.4, 0.15), "atmos_i": 1.5,
		"fog": Color(0.6, 0.25, 0.1), "fog_d": 0.00025, "ambient": Color(1.0, 0.5, 0.3),
		"gravity": 1.2, "temp": 420, "moons": 0, "radius": 135.0, "tilt": 5.0, "ring": false, "spin": 0.03,
		"style": "lava",
		"raider": {"armour": Color(0.18, 0.07, 0.05), "lights": Color(1.0, 0.4, 0.05)},
		"survivor_role": "THERMAL ENGINEER", "survivor_suit": Color(1.0, 0.55, 0.15),
		"briefing": "A thermal engineer is cut off by a lava flow, holding a failing cooling rig.",
		"threat": "Heavy raiders hunt through the ash clouds of the lava fields.",
	},
	{
		"stop": 9, "name": "ZEPHYRA", "universe": "ZEPHYR SHOAL", "type": "Ringed sky world",
		"texture": "res://assets/saturn_surface.png", "cloud": "",
		"tint": Color(0.9, 1.0, 0.95), "atmos": Color(0.5, 0.95, 0.85), "atmos_i": 1.0,
		"fog": Color(0.4, 0.7, 0.65), "fog_d": 0.0001, "ambient": Color(0.6, 0.9, 0.85),
		"gravity": 0.95, "temp": -10, "moons": 4, "radius": 200.0, "tilt": 18.0, "ring": true, "spin": 0.035,
		"style": "ice",
		"raider": {"armour": Color(0.5, 0.55, 0.6), "lights": Color(0.4, 1.0, 0.9)},
		"survivor_role": "SKY-FORCE PILOT", "survivor_suit": Color(0.6, 0.9, 0.85),
		"briefing": "A downed sky-force pilot is signalling from a floating platform beneath the rings.",
		"threat": "Interceptors dive out of the ring shadows to finish the pilot.",
	},
	{
		"stop": 10, "name": "SHADOWMERE", "universe": "SHADOW DEEP", "type": "Dark storm world",
		"texture": "res://assets/planet_surface_1.png", "cloud": "res://assets/planet_clouds_1.png",
		"tint": Color(0.35, 0.35, 0.45), "atmos": Color(0.4, 0.4, 0.6), "atmos_i": 1.2,
		"fog": Color(0.12, 0.12, 0.2), "fog_d": 0.00015, "ambient": Color(0.3, 0.3, 0.45),
		"gravity": 1.1, "temp": -40, "moons": 1, "radius": 150.0, "tilt": 30.0, "ring": false, "spin": 0.02,
		"style": "crystal",
		"raider": {"armour": Color(0.12, 0.12, 0.2), "lights": Color(0.5, 0.5, 1.0)},
		"survivor_role": "STORM SPECIALIST", "survivor_suit": Color(0.3, 0.35, 0.5),
		"briefing": "A storm specialist is sheltering in a wrecked relay under a permanent lightning storm.",
		"threat": "Shadow raiders emerge from the storm and attack in packs.",
	},
]


# The stop for mission number k (counting from 0). Missions past the named worlds go further out.
static func stop_for_mission(k: int) -> int:
	if USE_CAMPAIGN_NAMES and k < STOPS.size():
		return STOPS[k]
	return 11 + 3 * maxi(0, k - STOPS.size())


static func mission_for_stop(index: int) -> Dictionary:
	if not USE_CAMPAIGN_NAMES:
		return {}
	for mission in MISSIONS:
		if int(mission["stop"]) == index:
			return mission
	return {}


# Returns the route stop with the campaign's name, universe, look and mission text, when the stop is a named world.
static func apply_to_stop(index: int, data: Dictionary) -> Dictionary:
	var mission: Dictionary = mission_for_stop(index)
	if mission.is_empty():
		return data
	var out: Dictionary = data.duplicate()
	for key in ["name", "universe", "type", "texture", "cloud", "tint", "atmos", "atmos_i", "fog", "fog_d",
			"ambient", "gravity", "temp", "moons", "radius", "tilt", "ring", "spin", "style", "raider"]:
		out[key] = mission[key]
	out["survivor_role"] = mission["survivor_role"]
	out["survivor_suit"] = mission["survivor_suit"]
	out["briefing"] = mission["briefing"]
	out["threat"] = mission["threat"]
	return out
