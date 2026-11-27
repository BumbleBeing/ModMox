class_name ContentArmor
extends RefCounted
## The Armor authored in Content, one file each in content/armor/ (game ADR 0106), added with
## /add-armor.

const FOLDER: String = "res://content/armor/"


## Every Armor in Content, by file name.
static func all() -> Array[Armor]:
	var found: Array[Armor] = []
	if not DirAccess.dir_exists_absolute(FOLDER):
		return found
	var files: PackedStringArray = DirAccess.get_files_at(FOLDER)
	files.sort()
	for file: String in files:
		# An exported game lists a resource as "name.tres.remap".
		var armor: String = file.trim_suffix(".remap")
		if armor.ends_with(".tres"):
			found.append(load(FOLDER + armor) as Armor)
	return found


## The Armor in Content whose file is named [param file_name], without its extension, or null.
static func named(file_name: String) -> Armor:
	var path: String = FOLDER + file_name + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Armor
