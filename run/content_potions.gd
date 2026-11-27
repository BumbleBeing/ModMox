class_name ContentPotions
extends RefCounted
## The Potions authored in Content, one file each in content/potions/ (engine ADR 0036), which
## a Store stocks from (milestone 24).

const FOLDER: String = "res://content/potions/"


## Every Potion in Content, by file name.
static func all() -> Array[MmCardDefinition]:
	var found: Array[MmCardDefinition] = []
	if not DirAccess.dir_exists_absolute(FOLDER):
		return found
	var files: PackedStringArray = DirAccess.get_files_at(FOLDER)
	files.sort()
	for file: String in files:
		# An exported game lists a resource as "name.tres.remap".
		var potion: String = file.trim_suffix(".remap")
		if potion.ends_with(".tres"):
			found.append(load(FOLDER + potion) as MmCardDefinition)
	return found
