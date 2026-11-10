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
const API: String = "https://api.scryfall.com"
## Scryfall asks for a User-Agent and Accept header, and about 10 requests a second at most.
const HEADERS: PackedStringArray = ["User-Agent: ModMoxArtFetcher/1.0", "Accept: application/json;q=0.9,*/*;q=0.8"]
const PAUSE_SECONDS: float = 0.5

var _http: HTTPRequest


func _initialize() -> void:
	_http = HTTPRequest.new()
	root.add_child(_http)
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
	var card: Variant = await _get_json(API + "/cards/named?exact=" + card_name.uri_encode())
	# Variant: parsed JSON is open-ended until checked.
	if not card is Dictionary or not (card as Dictionary).has("prints_search_uri"):
		return "not found on Scryfall"
	if (card as Dictionary).get("content_warning", false):
		print("Note: Scryfall flags %s with a content warning." % card_name)
	var printings: Variant = await _get_json(str((card as Dictionary)["prints_search_uri"]) + "&dir=asc")
	if not printings is Dictionary:
		return "no printings"
	var chosen: Dictionary = FirstPrinting.choose((printings as Dictionary).get("data", []) as Array)
	if chosen.is_empty():
		return "no printing with art"
	var image: PackedByteArray = await _get_bytes(str((chosen["image_uris"] as Dictionary)["art_crop"]))
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


func _get_json(url: String) -> Variant:
	var body: PackedByteArray = await _get_bytes(url)
	return JSON.parse_string(body.get_string_from_utf8()) if not body.is_empty() else null


## The body at [param url], waiting and retrying when Scryfall says to slow down.
func _get_bytes(url: String) -> PackedByteArray:
	for attempt: int in 6:
		await create_timer(PAUSE_SECONDS).timeout
		if _http.request(url, HEADERS) != OK:
			return PackedByteArray()
		var result: Array = await _http.request_completed
		var code: int = result[1]
		if code == 200:
			return result[3]
		if code != 429:
			return PackedByteArray()
		await create_timer(30.0 * (attempt + 1)).timeout
	return PackedByteArray()


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
