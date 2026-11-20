class_name PotionArt
extends Control
## A Potion Icon as it is always drawn (ADR 0033, as amended): on a raised plate in Dither
## Shading in its Rarity's color, the icon in whole art pixels over it. Large, in the
## Inspector, the icon has a margin of one art pixel of plate; small, on an entry of the
## Potions window or the Stack Window, the icon fills the plate. An icon's glass is left
## clear but for a see-through lining, so the plate shows through it.

const FOLDER: String = "res://ui/sprites/potions/"
## The icon of a Potion that has none of its own.
const BOTTLE: String = "bottle"
## The icon's grid: 32 art pixels each way.
const CELLS: int = 32
## The plate's color for each Rarity: the color the Inspector glows in (Inspector.GLOWS),
## but for Mythic, whose plate is sienna, since a plate in the glow's honey would pass for
## Rare's gold beside it.
const PLATES: Dictionary[MmCardDefinition.Rarity, Color] = {
	MmCardDefinition.Rarity.COMMON: Color("#8a8f98"),
	MmCardDefinition.Rarity.UNCOMMON: Color("#d5dbe3"),
	MmCardDefinition.Rarity.RARE: Color("#f2c744"),
	MmCardDefinition.Rarity.MYTHIC: Color("#a0522d"),
	MmCardDefinition.Rarity.POWER_NINE: Color("#9be88a"),
}
const EDGE: Color = Color("#14171c")
const EDGE_WIDTH: int = 2
## How far the plate is lightened at its top and darkened at its foot.
const LIGHTEN: float = 0.18
const DARKEN: float = 0.2
## The plate's corners are rounded by this share of its side.
const ROUNDING: float = 0.08

var _key: String
var _is_small: bool
var _plate_color: Color
var _plate: Panel
var _icon: TextureRect


## The icon of the Potion authored in the file named [param key], or the plain bottle.
static func icon_of(key: String) -> Texture2D:
	return load(FOLDER + (key if has_icon(key) else BOTTLE) + ".png") as Texture2D


## Whether the Potion authored in the file named [param key] has an icon of its own.
static func has_icon(key: String) -> bool:
	return key != "" and ResourceLoader.exists(FOLDER + key + ".png")


## The plate a Potion Icon stands on: [param color] in Dither Shading, edged in near-black,
## painted for a square [param side] pixels wide.
static func plate_style(color: Color, side: int) -> StyleBoxTexture:
	return DitherShading.plate(color.lightened(LIGHTEN), color.darkened(DARKEN), EDGE,
			maxi(EDGE_WIDTH, roundi(side * ROUNDING)), EDGE_WIDTH, 0, side)


## The art of the Potion authored in the file named [param key], in a square [param side]
## pixels wide, on the plate of its [param rarity] (a Rarity, or null for a Potion given
## none, which stands on the Common plate).
func _init(key: String, side: float, is_small: bool, rarity: Variant) -> void:
	_key = key
	_is_small = is_small
	_plate_color = PLATES[rarity as MmCardDefinition.Rarity] if rarity != null else PLATES[MmCardDefinition.Rarity.COMMON]
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = Panel.new()
	_plate.size = size
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hard edges: the plate's blocks are pixel art too.
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.add_theme_stylebox_override("panel", plate_style(_plate_color, int(side)))
	add_child(_plate)
	var art_pixel: float = side / CELLS if is_small else side / (CELLS + 2)
	var icon_rect: Rect2 = Rect2(Vector2.ZERO, size) if is_small else Rect2(Vector2(art_pixel, art_pixel), Vector2(CELLS, CELLS) * art_pixel)
	_icon = _picture(icon_of(key))
	_icon.position = icon_rect.position
	_icon.size = icon_rect.size
	add_child(_icon)


## The file name of the Potion this is the art of.
func key() -> String:
	return _key


## Whether this is the small art of a window's entry, not the Inspector's large one.
func is_small() -> bool:
	return _is_small


## Where the icon is drawn in the square.
func icon_rect() -> Rect2:
	return Rect2(_icon.position, _icon.size)


## Where the plate is drawn: the whole square.
func plate_rect() -> Rect2:
	return Rect2(_plate.position, _plate.size)


## The color the plate is shaded from: its Potion's Rarity's.
func plate_color() -> Color:
	return _plate_color


## The icon drawn: the Potion's own, or the plain bottle.
func icon_texture() -> Texture2D:
	return _icon.texture


static func _picture(texture: Texture2D) -> TextureRect:
	var picture: TextureRect = TextureRect.new()
	picture.texture = texture
	# Hard edges: these are pixel art, drawn many times their size.
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture
