class_name ContentStages
extends RefCounted
## The Stages and Villains authored in Content, in content/stages/ and content/villains/.
## They are listed here and not on StageDefinition, which exports lists of Villains and so
## must not name itself (conventions, "The run ends clean").

const STAGES: String = "res://content/stages/"
const VILLAINS: String = "res://content/villains/"


## Every Stage in content/stages/, in file order.
static func all() -> Array[StageDefinition]:
	var found: Array[StageDefinition] = []
	for file: String in _files_in(STAGES):
		found.append(load(STAGES + file) as StageDefinition)
	return found


## Every Villain in content/villains/, in file order.
static func all_villains() -> Array[Villain]:
	var found: Array[Villain] = []
	for file: String in _files_in(VILLAINS):
		found.append(load(VILLAINS + file) as Villain)
	return found


## The resource files in [param folder], sorted. An exported game lists a resource as
## "name.tres.remap".
static func _files_in(folder: String) -> Array[String]:
	var found: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		var named: String = file.trim_suffix(".remap")
		if named.ends_with(".tres"):
			found.append(named)
	return found
