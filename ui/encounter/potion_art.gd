class_name PotionArt
extends Control
## A Potion Icon as it is always drawn (ADR 0033, A538): on a beige square with a darker
## circle behind it, the circle in the icon's own pixels so that its edge steps as the
## icon's does. Large, in the Inspector, the icon has a margin of one art pixel and the
## circle fills the icon's grid; small, on an entry of the Potions window or the Stack
## Window, the icon fills the square and the circle is one art pixel wider all round and
## one lower, cut off by the square.

const FOLDER: String = "res://ui/sprites/potions/"
## The icon of a Potion that has none of its own.
const BOTTLE: String = "bottle"
## The icon's grid: 16 art pixels each way.
const CELLS: int = 16
const BEIGE: Color = Color("#e6dcbd")
const CIRCLE: Color = Color("#a8926f")

var _key: String
var _is_small: bool
var _circle: TextureRect
var _icon: TextureRect


## The icon of the Potion authored in the file named [param key], or the plain bottle.
static func icon_of(key: String) -> Texture2D:
	return load(FOLDER + (key if has_icon(key) else BOTTLE) + ".png") as Texture2D


## Whether the Potion authored in the file named [param key] has an icon of its own.
static func has_icon(key: String) -> bool:
	return key != "" and ResourceLoader.exists(FOLDER + key + ".png")


## The circle as an image, [param grow] art pixels wider all round than the icon's grid.
static func circle_image(grow: int) -> Image:
	var cells: int = CELLS + 2 * grow
	var middle: float = (cells - 1) / 2.0
	var image: Image = Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	for y: int in cells:
		for x: int in cells:
			if Vector2(x - middle, y - middle).length() <= cells / 2.0:
				image.set_pixel(x, y, CIRCLE)
	return image


## The art of the Potion authored in the file named [param key], in a square [param side]
## pixels wide.
func _init(key: String, side: float, is_small: bool) -> void:
	_key = key
	_is_small = is_small
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var square: ColorRect = ColorRect.new()
	square.color = BEIGE
	square.size = size
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(square)
	var art_pixel: float = side / CELLS if is_small else side / (CELLS + 2)
	var icon_rect: Rect2 = Rect2(Vector2.ZERO, size) if is_small else Rect2(Vector2(art_pixel, art_pixel), Vector2(CELLS, CELLS) * art_pixel)
	var grow: int = 1 if is_small else 0
	var down: int = 1 if is_small else 0
	_circle = _picture(ImageTexture.create_from_image(circle_image(grow)))
	_circle.position = icon_rect.position + Vector2(-grow, down - grow) * art_pixel
	_circle.size = Vector2(CELLS + 2 * grow, CELLS + 2 * grow) * art_pixel
	add_child(_circle)
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


## Where the darker circle is drawn in the square; it may reach past the square's edge.
func circle_rect() -> Rect2:
	return Rect2(_circle.position, _circle.size)


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
