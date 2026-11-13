class_name ArtLibrary
extends RefCounted
## The card art shipped with the game for offline play (A226): one image per Card Definition
## in content/art/, named by the definition's file name, and one manifest holding each
## image's Scryfall credits and focus point (A233). Art belongs to the Card Definition, so a
## renamed Run Card keeps its art.

const FOLDER: String = "res://content/art/"
const MANIFEST: String = "res://content/art/art.json"
## Emblem art is put there by hand, named after the Emblem's file, with a manifest of its
## own holding each picture's artist and focus point (ADR 0033). An Emblem's key is its file
## name after EMBLEMS, "emblems/diviners_boon", so the same code finds its image.
const EMBLEMS: String = "emblems/"
const EMBLEM_MANIFEST: String = "res://content/art/emblems/art.json"
const MIDDLE: Vector2 = Vector2(0.5, 0.5)

## Card file name → {"set", "collector_number", "artist", "scryfall_id", "focus": [x, y]}.
var entries: Dictionary = {}

static var _shared: ArtLibrary = null


## The library the faces draw from, loaded once.
static func shared() -> ArtLibrary:
	if _shared == null:
		_shared = ArtLibrary.new()
	return _shared


func _init() -> void:
	entries = _read(MANIFEST)
	var emblems: Dictionary = _read(EMBLEM_MANIFEST)
	for key: String in emblems:
		entries[EMBLEMS + key] = emblems[key]


## The art for [param key], or null when the card has none (a Card Face then shows its name
## in the art window).
func texture(key: String) -> Texture2D:
	var path: String = FOLDER + key + ".jpg"
	return load(path) as Texture2D if key != "" and ResourceLoader.exists(path) else null


## Whether [param key]'s image is in content/art/, imported or not.
func has_image(key: String) -> bool:
	return key != "" and FileAccess.file_exists(FOLDER + key + ".jpg")


## The art key of the Emblem authored in the file named [param file_name].
static func emblem_key(file_name: String) -> String:
	return EMBLEMS + file_name


func artist(key: String) -> String:
	return str((entries.get(key, {}) as Dictionary).get("artist", ""))


## The point of the art (0 to 1 on each axis) a crop keeps as near its middle as it can.
func focus(key: String) -> Vector2:
	var saved: Variant = (entries.get(key, {}) as Dictionary).get("focus", null)
	# Variant: a JSON array, or nothing when the focus was never set.
	if saved is Array and (saved as Array).size() == 2:
		return Vector2(float((saved as Array)[0]), float((saved as Array)[1]))
	return MIDDLE


## The art for [param key] cropped to cover a box of [param box_size] around its focus
## point, or null when the card has none.
func cropped(key: String, box_size: Vector2) -> Texture2D:
	var art: Texture2D = texture(key)
	if art == null:
		return null
	var size: Vector2 = art.get_size()
	var region: Rect2 = crop(size, box_size, focus(key))
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = art
	atlas.region = Rect2(region.position * size, region.size * size)
	return atlas


## Moves [param key]'s focus point. Call save() to keep it.
func set_focus(key: String, point: Vector2) -> void:
	var entry: Dictionary = entries.get(key, {})
	entry["focus"] = [snappedf(point.x, 0.001), snappedf(point.y, 0.001)]
	entries[key] = entry


func save() -> void:
	# Emblem art has its own manifest, kept by hand.
	var cards: Dictionary = {}
	for key: String in entries:
		if not key.begins_with(EMBLEMS):
			cards[key] = entries[key]
	var file: FileAccess = FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(cards, "\t", true) + "\n")


## The part of an image of [param art_size] (in UV, 0 to 1) that covers a box of
## [param box_size] without stretching: centered on [param point] unless that would show
## past the art's edge, where it stops.
static func crop(art_size: Vector2, box_size: Vector2, point: Vector2) -> Rect2:
	var art_aspect: float = art_size.x / art_size.y
	var box_aspect: float = box_size.x / box_size.y
	var scale: Vector2 = Vector2(box_aspect / art_aspect, 1.0) if art_aspect > box_aspect else Vector2(1.0, art_aspect / box_aspect)
	var corner: Vector2 = (point - scale / 2.0).clamp(Vector2.ZERO, Vector2.ONE - scale)
	return Rect2(corner, scale)


## The manifest at [param path] as a Dictionary; empty if there is none or it is not one.
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# Variant: parsed JSON is open-ended until checked.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
