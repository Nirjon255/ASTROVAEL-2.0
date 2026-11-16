extends RefCounted
# Pilot progress, saved to user://astrovael_progress.json.
# Version 3 stores best_miles (route miles). Older best values were in another unit, so they are not carried over.

const SAVE_PATH: String = "user://astrovael_progress.json"
const SAVE_VERSION: int = 3

# Set by the cover when a save slot is chosen; read by main.gd when the flight scene starts.
static var pending_slot: int = -1


static func load_data() -> Dictionary:
	var result: Dictionary = {"best_miles": 0, "total_energy": 0, "total_diamonds": 0, "speed_level": 0, "balance": 0, "missions_done": 0}
	if not FileAccess.file_exists(SAVE_PATH):
		return result
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return result
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	var data: Dictionary = parsed
	result["total_energy"] = int(data.get("total_energy", 0))
	result["total_diamonds"] = int(data.get("total_diamonds", 0))
	result["speed_level"] = int(data.get("speed_level", 0))
	result["balance"] = int(data.get("balance", 0))
	result["missions_done"] = int(data.get("missions_done", 0))
	if int(data.get("version", 0)) >= SAVE_VERSION:
		result["best_miles"] = int(data.get("best_miles", 0))
	return result


static func save_data(values: Dictionary) -> void:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"best_miles": int(values.get("best_miles", 0)),
		"total_energy": int(values.get("total_energy", 0)),
		"total_diamonds": int(values.get("total_diamonds", 0)),
		"speed_level": int(values.get("speed_level", 0)),
		"balance": int(values.get("balance", 0)),
		"missions_done": int(values.get("missions_done", 0)),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write progress file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload))
	file.close()


static func slot_path(index: int) -> String:
	return "user://astrovael_slot_%d.json" % index


# Returns the saved state for a slot, or an empty dictionary if the slot is empty.
static func read_slot(index: int) -> Dictionary:
	var path: String = slot_path(index)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func write_slot(index: int, data: Dictionary) -> void:
	var file := FileAccess.open(slot_path(index), FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save slot %d" % index)
		return
	file.store_string(JSON.stringify(data))
	file.close()
