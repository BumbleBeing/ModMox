class_name MenuBackdrop
extends TextureRect
## The Menu Backdrop (game glossary, game ADR 0081): Last Light, the top of a castle tower at
## nightfall behind the main menu, the menu's window set into its parapet. Stretched over the
## whole screen it is drawn six screen pixels to each of its own, with hard edges, and never
## dimmed.
##
## It is its still, with its flicker played over it: the few pixels that ever change, each with
## its color on every frame, FRAMES_PER_SECOND frames a second, over and over. Both are drawn by
## tools/sprites/menu_backdrop.py, and imported as Images so that the flicker can be painted
## onto the still.

const STILL: String = "res://ui/sprites/backgrounds/menu/last_light.png"
## Each flicker pixel's color, one pixel to a column and one frame to a row; where each is, as
## [x, y] in the order of the columns.
const FLICKER: String = "res://ui/sprites/backgrounds/menu/last_light_flicker.png"
const FLICKER_PIXELS: String = "res://ui/sprites/backgrounds/menu/last_light_flicker.json"
const SIZE: Vector2i = Backdrops.SIZE
const FRAMES_PER_SECOND: float = 10.0
## The picture's row the window's top lies on: the top of the parapet's merlons.
const PARAPET: int = 67

var _still: Image
var _flicker: Image
var _pixels: Array[Vector2i] = []
## The still with the flicker of the frame it is on painted over it, and the texture showing it.
var _picture: Image
var _texture: ImageTexture
var _clock: float = 0.0
var _frame: int = 0


func _init() -> void:
	_still = load(STILL) as Image
	_flicker = load(FLICKER) as Image
	var found: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FLICKER_PIXELS))
	for pixel: Array in found["pixels"]:
		_pixels.append(Vector2i(int(pixel[0]), int(pixel[1])))
	_picture = _still.duplicate() as Image
	_paint()
	_texture = ImageTexture.create_from_image(_picture)
	texture = _texture
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Where the window's top lies on a screen [param height] pixels tall: on the parapet.
static func parapet_y(height: float) -> float:
	return height * PARAPET / SIZE.y


## How many frames the loop has.
func frames() -> int:
	return _flicker.get_height()


## The frame it is showing, from 0.
func frame() -> int:
	return _frame


## The picture as it is showing now.
func picture() -> Image:
	return _picture


## The picture with no flicker: the loop's first frame.
func still() -> Image:
	return _still


## Where each pixel that flickers is, in the order of the flicker's columns.
func flicker_pixels() -> Array[Vector2i]:
	return _pixels


## The color of the flicker pixel in [param column] on [param on_frame].
func flicker_color(column: int, on_frame: int) -> Color:
	return _flicker.get_pixel(column, on_frame)


## Lets [param seconds] go by, and shows the frame the clock is then on.
func advance(seconds: float) -> void:
	_clock = fmod(_clock + seconds, frames() / FRAMES_PER_SECOND)
	var now: int = mini(floori(_clock * FRAMES_PER_SECOND), frames() - 1)
	if now == _frame:
		return
	_frame = now
	_paint()
	_texture.update(_picture)


func _process(delta: float) -> void:
	advance(delta)


func _paint() -> void:
	for column: int in _pixels.size():
		_picture.set_pixelv(_pixels[column], _flicker.get_pixel(column, _frame))
