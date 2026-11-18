class_name ContentCards
extends RefCounted
## The Card Definitions authored in Content, one file each under a set's folder in
## content/cards/.

const FOLDER: String = "res://content/cards/"


## Every Card Definition in Content, by set folder and then by file name.
static func all() -> Array[MmCardDefinition]:
	var found: Array[MmCardDefinition] = []
	var sets: PackedStringArray = DirAccess.get_directories_at(FOLDER)
	sets.sort()
	for card_set: String in sets:
		var files: PackedStringArray = DirAccess.get_files_at(FOLDER + card_set)
		files.sort()
		for file: String in files:
			# An exported game lists a resource as "name.tres.remap".
			var card: String = file.trim_suffix(".remap")
			if card.ends_with(".tres"):
				found.append(load(FOLDER + card_set + "/" + card) as MmCardDefinition)
	return found
