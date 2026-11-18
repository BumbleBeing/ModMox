extends SceneTree
## Developer tool: gives every implemented card its art, for offline play (A226). For each
## Card Definition under content/cards/ that has no image in content/art/ or no manifest
## entry, it asks Scryfall for the card's printings, picks the first printing
## (FirstPrinting), downloads its art crop and records its credits in content/art/art.json,
## keeping any focus point already set. Then, for each token a card creates, it downloads
## the art of the token its creating card's first printing names (TokenArt) into
## content/art/tokens/, named after the Token Definition's file (game ADR 0045). Cards and
## tokens that already have art are skipped unless --force is given.
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
	var creators: Dictionary[String, MmCardDefinition] = {}
	for path: String in _card_files(CARDS):
		var definition: MmCardDefinition = load(path) as MmCardDefinition
		var key: String = path.get_file().get_basename()
		for token: MmCardDefinition in TokenArt.tokens_made_by(definition):
			if not creators.has(TokenArt.key_of(token)):
				creators[TokenArt.key_of(token)] = definition
		if not force and library.has_image(key) and library.entries.has(key):
			skipped += 1
			continue
		var error: String = await _fetch(definition.name, key, library)
		if error == "":
			fetched += 1
			print("Fetched %s." % key)
		else:
			failed.append("%s: %s" % [key, error])
	DirAccess.make_dir_recursive_absolute(ArtLibrary.FOLDER + ArtLibrary.TOKENS)
	for key: String in creators:
		if not force and library.has_image(key) and library.entries.has(key):
			skipped += 1
			continue
		var error: String = await _fetch_token(creators[key], key, library)
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
	var chosen: Dictionary = await _first_printing(card_name)
	if chosen.has("error"):
		return str(chosen["error"])
	return await _save_art(chosen, key, library)


## The art of the token its creating card [param creator]'s first printing names, saved
## under [param key] for the Token Definition behind it.
func _fetch_token(creator: MmCardDefinition, key: String, library: ArtLibrary) -> String:
	var chosen: Dictionary = await _first_printing(creator.name)
	if chosen.has("error"):
		return "%s's %s" % [creator.name, chosen["error"]]
	var token: MmCardDefinition = null
	for made: MmCardDefinition in TokenArt.tokens_made_by(creator):
		if TokenArt.key_of(made) == key:
			token = made
	var part: Dictionary = TokenArt.part_for(chosen, token)
	if part.is_empty():
		return "%s's first printing names no %s" % [creator.name, token.name]
	# Variant: parsed JSON is open-ended until checked.
	var token_card: Variant = await _scryfall.json_at(str(part.get("uri", "")))
	if not token_card is Dictionary or not ((token_card as Dictionary).get("image_uris", {}) as Dictionary).has("art_crop"):
		return "the token has no art"
	return await _save_art(token_card as Dictionary, key, library)


## The first printing (FirstPrinting) of the card named [param card_name], or a Dictionary
## holding only "error" when there is none.
func _first_printing(card_name: String) -> Dictionary:
	var card: Dictionary = await _scryfall.card_named(card_name)
	if card.is_empty():
		return {"error": "not found on Scryfall"}
	if card.get("content_warning", false):
		print("Note: Scryfall flags %s with a content warning." % card_name)
	var printings: Array = await _scryfall.printings_of(card)
	if printings.is_empty():
		return {"error": "no printings"}
	var chosen: Dictionary = FirstPrinting.choose(printings)
	if chosen.is_empty():
		return {"error": "no printing with art"}
	return chosen


## Downloads the art crop of [param chosen], a Scryfall card object, as [param key]'s image
## and records its credits.
func _save_art(chosen: Dictionary, key: String, library: ArtLibrary) -> String:
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
