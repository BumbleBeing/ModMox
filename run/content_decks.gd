class_name ContentDecks
extends RefCounted
## The decks authored in Content, saved as Player Setups in content/decks/. A debug run is
## built from them, and an encounter asked for on the start form or the command line plays
## two of them.

const FOLDER: String = "res://content/decks/"


## The names of the decks in content/decks/, in order.
static func names() -> Array[String]:
	var found: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(FOLDER)
	files.sort()
	for file: String in files:
		# An exported game lists a resource as "name.tres.remap".
		var deck: String = file.trim_suffix(".remap")
		if deck.ends_with(".tres"):
			found.append(deck.trim_suffix(".tres"))
	return found


## Whether Content has a deck named [param deck_name].
static func has(deck_name: String) -> bool:
	return ResourceLoader.exists(path_of(deck_name))


## The file of the deck named [param deck_name].
static func path_of(deck_name: String) -> String:
	return FOLDER + deck_name + ".tres"


## The deck named [param deck_name], as it is saved: never change it.
static func load_deck(deck_name: String) -> MmPlayerSetup:
	return load(path_of(deck_name)) as MmPlayerSetup
