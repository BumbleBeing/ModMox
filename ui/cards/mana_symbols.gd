class_name ManaSymbols
extends RefCounted
## The mana symbol images: a mana cost's pips, and the {X} symbols in rules text.

const FOLDER: String = "res://assets/card_frames/pips/"

static var _textures: Dictionary[String, Texture2D] = {}


## The pip images for [param cost], in order: one generic pip (or {0} for a cost with no
## symbols at all), then one per symbol in stored order, then one per hybrid symbol, named
## for its two colors ("br" for {B/R}), after an {X} for each. A card with no mana cost has
## none, which is not the same as {0}. Matches MmManaCost.describe().
static func pip_names(cost: MmManaCost) -> Array[String]:
	var names: Array[String] = []
	if cost == null:
		return names
	for x: int in cost.x_count:
		names.append("x")  # CR 107.3: {X} comes first, as in {X}{W}.
	if cost.generic > 0 or (cost.symbols.is_empty() and cost.hybrid_symbols.is_empty() and cost.x_count == 0):
		names.append(str(cost.generic))
	for symbol: MmMana.Type in cost.symbols:
		names.append((MmMana.SYMBOLS[symbol] as String).to_lower())
	for hybrid: Vector2i in cost.hybrid_symbols:
		names.append((MmMana.SYMBOLS[hybrid.x as MmMana.Type] + MmMana.SYMBOLS[hybrid.y as MmMana.Type]).to_lower())
	return names


## The image name for a symbol written in rules text, such as "{T}", "{2}" or "{B/R}", or ""
## when there is no image for it.
static func image_for(symbol: String) -> String:
	var inner: String = symbol.trim_prefix("{").trim_suffix("}").to_lower().replace("/", "")
	return inner if ResourceLoader.exists(FOLDER + inner + ".svg") else ""


## The texture for a pip image name, such as "r", "t" or "2".
static func texture(image_name: String) -> Texture2D:
	if not _textures.has(image_name):
		var image: Image = load(FOLDER + image_name + ".svg") as Image
		var copy: Image = image.duplicate() as Image
		copy.generate_mipmaps()
		_textures[image_name] = ImageTexture.create_from_image(copy)
	return _textures[image_name]
