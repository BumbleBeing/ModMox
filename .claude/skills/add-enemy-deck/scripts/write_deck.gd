extends SceneTree
## Writes a deck list as a Player Setup in content/decks/, for /add-enemy-deck. Each line of the
## list is "<count> <card name>"; every card must already be in Content. A card it cannot find
## is named and nothing is written.
##
## Run: godot --headless --path . -s <this script> -- DECK_NAME LIST_FILE [--out PATH] [--skip NAME]...
##   DECK_NAME  the deck's file name without ".tres", such as "white_black" or "ajani_2"
##   LIST_FILE  an absolute path to the deck list
##   --out      write here instead of res://content/decks/DECK_NAME.tres (for trying it out)
##   --skip     leave out a card that could not be added (repeat for each), and say so

const CONTENT: String = "res://content/cards/"
const DECKS: String = "res://content/decks/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	quit(0 if _write(OS.get_cmdline_user_args()) else 1)


func _write(arguments: PackedStringArray) -> bool:
	if arguments.size() < 2:
		printerr("Usage: write_deck.gd -- DECK_NAME LIST_FILE [--out PATH] [--skip NAME]...")
		return false
	var deck_name: String = arguments[0]
	var list_file: String = arguments[1]
	var out: String = DECKS + deck_name + ".tres"
	var skipped: Array[String] = []
	var index: int = 2
	while index < arguments.size():
		var flag: String = arguments[index]
		if index + 1 >= arguments.size():
			printerr("%s needs a value" % flag)
			return false
		if flag == "--out":
			out = arguments[index + 1]
		elif flag == "--skip":
			skipped.append(arguments[index + 1].to_lower())
		else:
			printerr("Unknown argument %s" % flag)
			return false
		index += 2
	var lines: PackedStringArray = FileAccess.get_file_as_string(list_file).split("\n", false)
	var in_content: Dictionary[String, String] = _cards_in_content()
	var setup: MmPlayerSetup = MmPlayerSetup.new()
	var missing: Array[String] = []
	var total: int = 0
	for raw: String in lines:
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		var space: int = line.find(" ")
		if space < 1 or not line.substr(0, space).is_valid_int():
			printerr("Not \"<count> <card name>\": %s" % line)
			return false
		var count: int = line.substr(0, space).to_int()
		var card_name: String = line.substr(space + 1).strip_edges()
		if card_name.to_lower() in skipped:
			print("Left out: %d %s" % [count, card_name])
			continue
		if not in_content.has(card_name.to_lower()):
			missing.append(card_name)
			continue
		var definition: MmCardDefinition = load(in_content[card_name.to_lower()]) as MmCardDefinition
		for copy: int in count:
			var run_card: MmRunCard = MmRunCard.new()
			run_card.base = definition
			setup.deck.append(run_card)
		total += count
	if not missing.is_empty():
		printerr("Not in Content, so nothing was written: %s" % ", ".join(missing))
		return false
	if ResourceLoader.exists(out) and out.begins_with(DECKS):
		print("Replacing %s" % out)
	var error: Error = ResourceSaver.save(setup, out)
	if error != OK:
		printerr("Could not save %s: %s" % [out, error_string(error)])
		return false
	print("Wrote %s: %d cards" % [out, total])
	return true


## Every card file in Content, by its card's name in lower case.
static func _cards_in_content() -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for set_folder: String in DirAccess.get_directories_at(CONTENT):
		var folder: String = CONTENT + set_folder + "/"
		for file: String in DirAccess.get_files_at(folder):
			if not file.ends_with(".tres"):
				continue
			var definition: MmCardDefinition = load(folder + file) as MmCardDefinition
			if definition != null:
				found[definition.name.to_lower()] = folder + file
	return found
