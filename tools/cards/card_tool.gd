extends SceneTree
## Developer tool behind /add-card (ADR 0040). It asks Scryfall for cards' Oracle Data, says
## what it can read of each, writes a card's printed characteristics, and lists the engine's
## primitives for triage. It never writes abilities: those are composed in the session.
##
## Run: godot --headless --path . -s res://tools/cards/card_tool.gd -- <command> [arguments]
##   primitives               every primitive in the engine, with its doc comment and fields
##   fetch NAME...            each card's Oracle Data and what can be read of it
##   search QUERY             the same for every card a Scryfall search finds
##   write [--anyway] NAME... writes each card's file and its Oracle Data entry, refusing a
##                            card with anything it cannot read unless told --anyway
##   record                   fetches the Oracle Data of every card file that has none
##   review FILE...           each card file's generated rules text beside its Oracle text
##   creature-types           rewrites the engine's CreatureTypes from Scryfall's catalog of
##                            creature types (CR 205.3m), saying what was added or removed

const USAGE: String = "Usage: card_tool.gd -- primitives | fetch NAME... | search QUERY | write [--anyway] NAME... | record | review FILE... | creature-types"
const CONTENT: String = "res://content/cards/"
const ENGINE_SOURCE: String = "res://addons/modmox_rules/src/"
## The engine's folders that cards are composed from.
const PRIMITIVE_FOLDERS: PackedStringArray = [
	"abilities", "conditions", "costs", "effects", "filters", "layers", "mana", "replacements",
	"selections", "targets", "triggers", "values",
]
## Classes that extend these are the engine's machinery, never part of a card.
const MACHINERY: PackedStringArray = ["RefCounted", "Object", "Node"]

var _scryfall: Scryfall


func _initialize() -> void:
	_scryfall = Scryfall.new()
	root.add_child(_scryfall)
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var command: String = arguments[0] if not arguments.is_empty() else ""
	var rest: PackedStringArray = arguments.slice(1)
	var succeeded: bool = true
	match command:
		"primitives":
			_print_primitives()
		"fetch":
			succeeded = await _fetch(rest)
		"search":
			succeeded = await _search(" ".join(rest))
		"write":
			succeeded = await _write(rest)
		"record":
			succeeded = await _record()
		"review":
			succeeded = _review(rest)
		"creature-types":
			succeeded = await _creature_types()
		_:
			printerr(USAGE)
			succeeded = false
	quit(0 if succeeded else 1)


## Rewrites CreatureTypes from Scryfall's catalog (engine ADR 0052). A changed list is an
## engine version change: a saved answer is an index into it (ADR 0010).
func _creature_types() -> bool:
	var types: Array[String] = CreatureTypesSource.types_in(await _scryfall.json_at(CreatureTypesSource.CATALOG_URL))
	if types.is_empty():
		printerr("Scryfall sent no catalog of creature types.")
		return false
	var before: Array[String] = CreatureTypes.ALL.duplicate()
	var added: Array[String] = CreatureTypesSource.added(before, types)
	var removed: Array[String] = CreatureTypesSource.added(types, before)
	if added.is_empty() and removed.is_empty():
		print("CreatureTypes already lists all %d creature types." % types.size())
		return true
	var file: FileAccess = FileAccess.open(CreatureTypesSource.PATH, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write %s." % CreatureTypesSource.PATH)
		return false
	file.store_string(CreatureTypesSource.source_of(types))
	file.close()
	print("Wrote %d creature types to %s." % [types.size(), CreatureTypesSource.PATH])
	print("Added: %s" % ", ".join(PackedStringArray(added)) if not added.is_empty() else "Added: none")
	print("Removed: %s" % ", ".join(PackedStringArray(removed)) if not removed.is_empty() else "Removed: none")
	return true


func _fetch(card_names: PackedStringArray) -> bool:
	var in_content: Dictionary[String, String] = _cards_in_content()
	var entries: Array[Dictionary] = []
	for card_name: String in card_names:
		var entry: Dictionary = await _entry_named(card_name)
		if not entry.is_empty():
			entries.append(entry)
	_describe_all(entries, in_content)
	return entries.size() == card_names.size()


func _search(query: String) -> bool:
	var in_content: Dictionary[String, String] = _cards_in_content()
	var url: String = Scryfall.API + "/cards/search?unique=cards&order=name&q=" + query.uri_encode()
	var cards: Array[Dictionary] = []
	while url != "":
		# Variant: parsed JSON is open-ended until checked.
		var page: Variant = await _scryfall.json_at(url)
		if not page is Dictionary or not (page as Dictionary).has("data"):
			printerr("Scryfall found nothing for %s." % query)
			return false
		for card: Variant in (page as Dictionary)["data"] as Array:
			if card is Dictionary:
				cards.append(card)
		var has_more: bool = (page as Dictionary).get("has_more", false)
		url = str((page as Dictionary).get("next_page", "")) if has_more else ""
	var entries: Array[Dictionary] = []
	for card: Dictionary in cards:
		var entry: Dictionary = await _entry_of(card)
		if not entry.is_empty():
			entries.append(entry)
	_describe_all(entries, in_content)
	return entries.size() == cards.size()


func _write(arguments: PackedStringArray) -> bool:
	var anyway: bool = arguments.has("--anyway")
	var library: OracleData = OracleData.new()
	var in_content: Dictionary[String, String] = _cards_in_content()
	var succeeded: bool = true
	for card_name: String in arguments:
		if card_name == "--anyway":
			continue
		if in_content.has(card_name):
			printerr("%s is already in Content, at %s." % [card_name, in_content[card_name]])
			succeeded = false
			continue
		var entry: Dictionary = await _entry_named(card_name)
		if entry.is_empty():
			succeeded = false
			continue
		var reading: OracleReading = OracleReading.of(entry)
		if not reading.refusals.is_empty() and not anyway:
			printerr("%s was not written. It has what the tool cannot read:\n  - %s" % [card_name, "\n  - ".join(reading.refusals)])
			succeeded = false
			continue
		var folder: String = CONTENT + reading.folder + "/"
		var path: String = folder + reading.file_name + ".tres"
		DirAccess.make_dir_recursive_absolute(folder)
		var error: Error = ResourceSaver.save(reading.definition, path)
		if error != OK:
			printerr("%s could not be saved to %s (error %d)." % [card_name, path, error])
			succeeded = false
			continue
		library.entries[reading.file_name] = entry
		print("Wrote %s." % path)
		for refusal: String in reading.refusals:
			print("  Left for the session: %s" % refusal)
	library.save()
	return succeeded


func _record() -> bool:
	var library: OracleData = OracleData.new()
	var succeeded: bool = true
	var recorded: int = 0
	for path: String in _card_paths(CONTENT):
		var key: String = path.get_file().get_basename()
		if library.entries.has(key):
			continue
		var definition: MmCardDefinition = load(path) as MmCardDefinition
		var entry: Dictionary = await _entry_named(definition.name)
		if entry.is_empty():
			succeeded = false
			continue
		library.entries[key] = entry
		recorded += 1
		var differences: PackedStringArray = OracleData.mismatches(definition, entry)
		if differences.is_empty():
			print("Recorded %s." % key)
		else:
			print("Recorded %s. It differs from its Oracle Data in: %s" % [key, ", ".join(differences)])
	library.save()
	print("Recorded %d." % recorded)
	return succeeded


## Prints each card's generated rules text (ADR 0023) under its Oracle text, for the review
## that checks its abilities were composed right (ADR 0040). [param file_names] are card file
## names without ".tres".
func _review(file_names: PackedStringArray) -> bool:
	var library: OracleData = OracleData.new()
	var paths: Dictionary[String, String] = {}
	for path: String in _card_paths(CONTENT):
		paths[path.get_file().get_basename()] = path
	var succeeded: bool = true
	for file_name: String in file_names:
		if not paths.has(file_name) or not library.entries.has(file_name):
			printerr("%s: no card file with Oracle Data." % file_name)
			succeeded = false
			continue
		var look: CardLook = CardLook.of_definition(load(paths[file_name]) as MmCardDefinition)
		var entry: Dictionary = library.entries[file_name]
		print("== %s ==" % entry.get("name", file_name))
		print("oracle:")
		for line: String in str(entry.get("oracle_text", "")).split("\n"):
			print("    " + line)
		print("generated:")
		for line: String in look.rules_text.split("\n"):
			print("    " + line)
		print("")
	return succeeded


## The Oracle Data entry for the card named exactly [param card_name], or an empty
## Dictionary once the reason is printed.
func _entry_named(card_name: String) -> Dictionary:
	var card: Dictionary = await _scryfall.card_named(card_name)
	if card.is_empty():
		printerr("%s: not found on Scryfall." % card_name)
		return {}
	return await _entry_of(card)


## The Oracle Data entry for [param card], a Scryfall card object, with its first printing's
## set and rarity, or an empty Dictionary once the reason is printed.
func _entry_of(card: Dictionary) -> Dictionary:
	if card.has("card_faces"):
		# Its printings keep their art on each face, so none would be chosen, and the reading
		# refuses it anyway: it is Set Aside, and has no first set to go in yet.
		return OracleData.entry_of(card, {})
	var first_printing: Dictionary = FirstPrinting.choose(await _scryfall.printings_of(card))
	if first_printing.is_empty():
		printerr("%s: no paper printing with art." % card.get("name", ""))
		return {}
	return OracleData.entry_of(card, first_printing)


func _describe_all(entries: Array[Dictionary], in_content: Dictionary[String, String]) -> void:
	var whole: PackedStringArray = []
	var partial: PackedStringArray = []
	var present: PackedStringArray = []
	for entry: Dictionary in entries:
		var reading: OracleReading = OracleReading.of(entry)
		print(_description(entry, reading, in_content))
		if in_content.has(reading.definition.name):
			present.append(reading.definition.name)
		elif reading.refusals.is_empty():
			whole.append(reading.definition.name)
		else:
			partial.append(reading.definition.name)
	print("Characteristics read whole (%d): %s" % [whole.size(), ", ".join(whole)])
	print("With something the tool cannot read (%d): %s" % [partial.size(), ", ".join(partial)])
	print("Already in Content (%d): %s" % [present.size(), ", ".join(present)])


func _description(entry: Dictionary, reading: OracleReading, in_content: Dictionary[String, String]) -> String:
	var card_name: String = reading.definition.name
	var lines: PackedStringArray = ["== %s ==" % card_name]
	if in_content.has(card_name):
		lines.append("file: %s (already in Content)" % in_content[card_name])
	elif reading.folder == "":
		lines.append("file: none, since its first set is not known")
	else:
		lines.append("file: %s%s/%s.tres (new)" % [CONTENT, reading.folder, reading.file_name])
	lines.append("mana cost: %s" % entry.get("mana_cost", ""))
	lines.append("type line: %s" % entry.get("type_line", ""))
	if entry.has("power"):
		lines.append("power/toughness: %s/%s" % [entry.get("power", ""), entry.get("toughness", "")])
	if not entry.has("card_faces"):
		var rarity: String = str(MmCardDefinition.Rarity.keys()[reading.definition.rarity]).capitalize()
		lines.append("rarity: %s (Scryfall: %s, first printed in %s)" % [rarity, entry.get("rarity", ""), entry.get("set_name", "")])
		lines.append("oracle text:")
		for line: String in str(entry.get("oracle_text", "")).split("\n"):
			lines.append("    " + line)
	for face: Variant in entry.get("card_faces", []) as Array:
		# Variant: parsed JSON is open-ended until checked.
		if face is Dictionary:
			lines.append("face %s (%s, %s):" % [face.get("name", ""), face.get("mana_cost", ""), face.get("type_line", "")])
			for line: String in str((face as Dictionary).get("oracle_text", "")).split("\n"):
				lines.append("    " + line)
	for refusal: String in reading.refusals:
		lines.append("cannot read: " + refusal)
	return "\n".join(lines) + "\n"


func _print_primitives() -> void:
	for folder: String in PRIMITIVE_FOLDERS:
		print("## %s/" % folder)
		var files: PackedStringArray = DirAccess.get_files_at(ENGINE_SOURCE + folder)
		files.sort()
		for file: String in files:
			if file.ends_with(".gd"):
				var description: String = _primitive_description(ENGINE_SOURCE + folder + "/" + file)
				if description != "":
					print(description)
		print("")


## A primitive's class, what it extends, its doc comment and its fields, read from its source
## at [param path]; empty for a class that is the engine's machinery.
static func _primitive_description(path: String) -> String:
	var class_title: String = ""
	var base: String = ""
	var doc: PackedStringArray = []
	var details: PackedStringArray = []
	var is_reading_doc: bool = false
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("class_name "):
			class_title = line.trim_prefix("class_name ").strip_edges()
		elif line.begins_with("extends "):
			base = line.trim_prefix("extends ").strip_edges()
			is_reading_doc = true
		elif is_reading_doc and line.begins_with("##"):
			doc.append(line.trim_prefix("##").strip_edges())
		else:
			is_reading_doc = false
			if line.begins_with("@export var ") or line.begins_with("enum "):
				details.append("    " + line.trim_prefix("@export var ").strip_edges())
	if class_title == "" or MACHINERY.has(base):
		return ""
	var description: String = "%s < %s: %s" % [class_title, base, " ".join(doc)]
	return "\n".join([description] + Array(details))


## Every card in Content, its name → its file.
static func _cards_in_content() -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for path: String in _card_paths(CONTENT):
		var definition: MmCardDefinition = load(path) as MmCardDefinition
		if definition != null:
			found[definition.name] = path
	return found


static func _card_paths(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_card_paths(folder + sub + "/"))
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			found.append(folder + file)
	return found
