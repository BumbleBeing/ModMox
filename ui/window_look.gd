class_name WindowLook
extends RefCounted
## How a window standing over a screen looks, as the Spoils screen's does (milestone 18):
## Dither Shaded in a warm dark gray inside the Steel Rim, with dithered slate-gray buttons.
## The main menu's window and its dialogs, the Spoils window, the Pause Menu and the
## encounter's ending banner are drawn in it.
##
## The Steel Rim (the conventions, signed off by the user from prototypes/window_border) is
## three bands RIM_BAND pixels wide, near-black outside and in with dark steel between, its
## corners stepped in blocks of a band, CORNER_STEPS deep, as a Steel Frame's are and never
## rounded.

const FILL: Color = Color("#4b3f3f")
## The rim's outer and inner bands.
const EDGE: Color = Color("#14171c")
## The rim's middle band: the Steel Frame's steel darkened about a third.
const STEEL: Color = Color("#6e747e")
## Each band is as wide as a Steel Frame's ring.
const RIM_BAND: int = SteelFrame.RING
const RIM: int = RIM_BAND * 3
const CORNER_STEPS: int = 4
## How far in from the left and right the stepped corner reaches. The face's dither grid
## starts there across, and the Soldier Shadow and the Wisp Light keep to it.
const CORNER: int = RIM + CORNER_STEPS * RIM_BAND
## The room inside a window round what it holds: as clear of the rim as the Spoils screen's
## window was of its old 2 px edge.
const MARGIN: int = RIM + 22
## The Spoils screen's title bar gray (#656a75) darkened a fifth, as its Continue is.
const BUTTON: Color = Color("#51555e")
const BUTTON_RADIUS: int = 12

## What a pixel is, from the outside in: clear, then each band of the rim.
const _BANDS: Array[Color] = [Color(0, 0, 0, 0), EDGE, STEEL, EDGE]
## The height a shaded window was last painted for.
const _PAINTED: StringName = &"window_look_painted"


## A window's plate, [param height] pixels tall: the Steel Rim round the window's Dither
## Shading. Its middle columns tile, so it fits any width.
static func plate(height: int) -> StyleBoxTexture:
	var width: int = CORNER * 2 + DitherShading.BLOCK * 4
	var top: Color = FILL.lightened(0.06)
	var bottom: Color = FILL.darkened(0.3)
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			image.set_pixel(x, y, _pixel(x, y, width, height, top, bottom))
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = CORNER
	made.texture_margin_right = CORNER
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	made.set_content_margin_all(MARGIN)
	return made


## Keeps [param window] painted with a plate for its height, painting it again only when
## that changes, since a plate's width tiles. A plate's margin is always MARGIN, so painting
## never resizes the window. Shading a window twice does nothing more.
static func shade(window: Control) -> void:
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if window.has_meta(_PAINTED):
		return
	var paint: Callable = func() -> void:
		# Before it is laid out, a window is painted as short as its corners allow, so that
		# its margin is right from the start.
		var height: int = maxi(int(window.size.y), CORNER * 2)
		if window.get_meta(_PAINTED, 0) == height:
			return
		window.set_meta(_PAINTED, height)
		window.add_theme_stylebox_override("panel", plate(height))
	window.set_meta(_PAINTED, 0)
	window.resized.connect(paint)
	paint.call()


static func _pixel(x: int, y: int, width: int, height: int, top: Color, bottom: Color) -> Color:
	for band: int in _BANDS.size():
		if not SteelFrame.is_inside(x, y, width, height, band * RIM_BAND, CORNER_STEPS):
			return _BANDS[band]
	# On a grid starting CORNER in, kept positive so that its blocks are whole.
	return DitherShading.band_color(posmod(x - CORNER, DitherShading.BLOCK * 2), y, height, top, bottom)
