extends SceneTree
## Developer tool: gives every implemented card its art, for offline play (A226). For each
## Card Definition under content/cards/ that has no image in content/art/ or no manifest
## entry, it asks Scryfall for the card's printings, picks the first printing
## (FirstPrinting), downloads its art crop and records its credits in content/art/art.json,
## keeping any focus point already set. Cards that already have art are skipped unless
## --force is given.
##
## Run: godot --headless --path . -s res://tools/art/fetch_art.gd [-- --force]

const CARDS: String = "res://content/cards/"

var _scryfall: Scryfall


func _initialize() -> void:
	_scryfall = Scryfall.new()
	root.add_child(_scryfall)
	_run.call_deferred()


func _run() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	var library: ArtLibrary = ArtLibrary.new()
	var fetched: int = 0
	var skipped: int = 0
	var failed: PackedStringArray = []
	for path: String in _card_files(CARDS):
		var definition: MmCardDefinition = load(path) as MmCardDefinition
		var key: String = path.get_file().get_basename()
		if not force and library.has_image(key) and library.entries.has(key):
			skipped += 1
			continue
		var error: String = await _fetch(definition.name, key, library)
		if error == "":
			fetched += 1
			print("Fetched %s." % key)
		else:
			failed.append("%s: %s" % [key, error])
	library.save()
	print("Fetched %d, skipped %d, failed %d." % [fetched, skipped, failed.size()])
	for line: String in failed:
		printerr(line)
	quit(1 if not failed.is_empty() else 0)


func _fetch(card_name: String, key: String, library: ArtLibrary) -> String:
	var card: Dictionary = await _scryfall.card_named(card_name)
	if card.is_empty():
		return "not found on Scryfall"
	if card.get("content_warning", false):
		print("Note: Scryfall flags %s with a content warning." % card_name)
	var printings: Array = await _scryfall.printings_of(card)
	if printings.is_empty():
		return "no printings"
	var chosen: Dictionary = FirstPrinting.choose(printings)
	if chosen.is_empty():
		return "no printing with art"
	var image: PackedByteArray = await _scryfall.bytes_at(str((chosen["image_uris"] as Dictionary)["art_crop"]))
	if image.is_empty():
		return "download failed"
	var file: FileAccess = FileAccess.open(ArtLibrary.FOLDER + key + ".jpg", FileAccess.WRITE)
	file.store_buffer(image)
	file.close()
	var entry: Dictionary = library.entries.get(key, {})
	entry["set"] = chosen.get("set", "")
	entry["collector_number"] = chosen.get("collector_number", "")
	entry["artist"] = chosen.get("artist", "")
	entry["scryfall_id"] = chosen.get("id", "")
	if not entry.has("focus"):
		entry["focus"] = [0.5, 0.5]
	library.entries[key] = entry
	return ""


static func _card_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_card_files(folder + sub + "/"))
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			found.append(folder + file)
	return found
