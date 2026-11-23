class_name ContentMods
extends RefCounted
## The Mods and Hexes authored in Content, one file each in content/mods/ (ADR 0029).

const FOLDER: String = "res://content/mods/"


## Every Mod and Hex in Content, by file name.
static func all() -> Array[Mod]:
	var found: Array[Mod] = []
	if not DirAccess.dir_exists_absolute(FOLDER):
		return found
	var files: PackedStringArray = DirAccess.get_files_at(FOLDER)
	files.sort()
	for file: String in files:
		# An exported game lists a resource as "name.tres.remap".
		var mod: String = file.trim_suffix(".remap")
		if mod.ends_with(".tres"):
			found.append(load(FOLDER + mod) as Mod)
	return found
