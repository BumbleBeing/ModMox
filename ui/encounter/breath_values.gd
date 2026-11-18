class_name BreathValues
extends RefCounted
## Each Portrait's Breath Rate and Breath Intensity (game glossary), known by the Portrait's
## file name and kept in PATH, which the breath lab saves. A Portrait not in it breathes at
## 1 and 1.

const PATH: String = "res://ui/sprites/portraits/breath.json"
const RATE: String = "rate"
const INTENSITY: String = "intensity"

var _table: Dictionary = {}


## The table in [param path], or an empty one if there is none.
static func load_from(path: String = PATH) -> BreathValues:
	var values: BreathValues = BreathValues.new()
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			values._table = parsed
	return values


## What [param portrait] is known by in the table: its file's name, or "" for none.
static func key_of(portrait: Texture2D) -> String:
	if portrait == null:
		return ""
	return portrait.resource_path.get_file().get_basename()


func rate_of(key: String) -> float:
	return _value(key, RATE)


func intensity_of(key: String) -> float:
	return _value(key, INTENSITY)


func set_values(key: String, rate: float, intensity: float) -> void:
	_table[key] = {RATE: snappedf(rate, 0.01), INTENSITY: snappedf(intensity, 0.01)}


func save_to(path: String = PATH) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_table, "\t", true) + "\n")


func _value(key: String, name: String) -> float:
	var entry: Variant = _table.get(key)
	if entry is Dictionary:
		return float((entry as Dictionary).get(name, 1.0))
	return 1.0
