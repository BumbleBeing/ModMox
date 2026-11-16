extends SceneTree
## Developer tool: fetches the art a Portrait is drawn after (ReferenceArt). It asks Scryfall
## for the card named by --card, picks its first printing (FirstPrinting, A227), saves that
## printing's art crop to tools/sprites/reference/<key>.jpg, and prints the key and the
## header lines that credit it in the Portrait's grid file. Double-faced cards are not
## handled yet.
##
## Run: godot --headless --path . -s res://tools/art/fetch_reference.gd -- --card="Keldon Warlord"

var _scryfall: Scryfall


func _initialize() -> void:
	_scryfall = Scryfall.new()
	root.add_child(_scryfall)
	_run.call_deferred()


func _run() -> void:
	var card_name: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--card="):
			card_name = argument.trim_prefix("--card=").strip_edges()
	if card_name == "":
		printerr("Name the card: -- --card=\"Keldon Warlord\"")
		quit(2)
		return
	var error: String = await _fetch(card_name)
	if error != "":
		printerr("%s: %s" % [card_name, error])
	quit(1 if error != "" else 0)


func _fetch(card_name: String) -> String:
	var card: Dictionary = await _scryfall.card_named(card_name)
	if card.is_empty():
		return "not found on Scryfall"
	if card.get("content_warning", false):
		print("Note: Scryfall flags %s with a content warning." % card["name"])
	var printings: Array = await _scryfall.printings_of(card)
	var chosen: Dictionary = FirstPrinting.choose(printings)
	if chosen.is_empty():
		if ReferenceArt.is_double_faced(printings):
			return "its art is on its faces, and double-faced cards are not handled yet"
		return "no printing with art"
	var image: PackedByteArray = await _scryfall.bytes_at(str((chosen["image_uris"] as Dictionary)["art_crop"]))
	if image.is_empty():
		return "download failed"
	var key: String = ReferenceArt.key_of(str(card["name"]))
	var path: String = ReferenceArt.path_of(key)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "cannot write %s" % path
	file.store_buffer(image)
	file.close()
	print("Key: %s" % key)
	print("Art: %s" % ProjectSettings.globalize_path(path))
	for line: String in ReferenceArt.header(chosen):
		print(line)
	return ""
