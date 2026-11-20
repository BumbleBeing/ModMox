class_name SteelFrame
extends RefCounted
## How the buttons of the Info Panel and the Pass Button are drawn (game ADR 0066): Dither
## Shading in the button's own color inside a pixel border with stepped corners, nothing
## rounded. The border is a ring of light steel RING pixels thick with a dark line one pixel
## thick inside it, over the button's lip. The ring of a Selected Answer is white. A button
## that cannot be pressed lies flat, with no lip, its ring faded toward the panel.
##
## Each plate is painted once for each color, state, height and ring and shared.

const STEEL: Color = Color("#aab2c2")
const SELECTED_RING: Color = Color.WHITE
## What a disabled button's ring fades toward: the Info Panel's fill.
const PANEL: Color = Color("#2c323c")
## The ring is this many pixels thick, and the corners step in blocks of it.
const RING: int = 3
const CORNER_STEPS: int = 2
## The ring and the dark line inside it: how far in the face starts.
const FRAME: int = RING + 1

static var _plates: Dictionary[String, StyleBoxTexture] = {}


## Frames [param button], its size already set, in [param color] with white text, its ring
## white when [param is_selected].
static func apply(button: Button, color: Color, is_selected: bool = false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var height: int = maxi(1, int(button.size.y))
	for state: String in ButtonShading.STATES:
		button.add_theme_stylebox_override(state, plate(color, state, height, is_selected))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", ButtonShading.DISABLED_TEXT)


## The plate of a button [param height] pixels tall in [param state], drawn in [param color].
static func plate(color: Color, state: String, height: int, is_selected: bool = false) -> StyleBoxTexture:
	var key: String = "%s/%s/%d/%s" % [color.to_html(), state, height, is_selected]
	if _plates.has(key):
		return _plates[key]
	var is_disabled: bool = state == "disabled"
	var is_pressed: bool = state in ["pressed", "hover_pressed"]
	var fill: Color = color
	if is_disabled:
		fill = ButtonShading.DISABLED
	elif state == "hover":
		fill = color.lightened(InspectorParts.HOVER_LIGHTEN)
	var lip: int = 0 if is_disabled else (DitherShading.PRESSED_LIP if is_pressed else DitherShading.LIP)
	# A pressed button sits down on its lip: its face starts lower.
	var drop: int = DitherShading.LIP - DitherShading.PRESSED_LIP if is_pressed and not is_disabled else 0
	var face_height: int = height - lip - drop
	var top: Color = fill.darkened(0.2) if is_pressed else fill.lightened(0.12)
	var bottom: Color = fill.lightened(0.02) if is_pressed else fill.darkened(0.25)
	var ring: Color = ring_color(is_selected, is_disabled)
	var line: Color = fill.darkened(0.65)
	var lip_color: Color = STEEL.darkened(0.55)
	var corner: int = RING * (CORNER_STEPS + 3)
	var width: int = corner * 2 + DitherShading.BLOCK * 4
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var face_y: int = y - drop
			var pixel: Color = Color(0, 0, 0, 0)
			if is_inside(x, face_y, width, face_height, 0):
				if not is_inside(x, face_y, width, face_height, RING):
					pixel = ring
				elif not is_inside(x, face_y, width, face_height, FRAME):
					pixel = line
				else:
					pixel = DitherShading.band_color(x, face_y, face_height, top, bottom)
			elif lip > 0 and is_inside(x, face_y - lip, width, face_height, 0):
				pixel = lip_color
			image.set_pixel(x, y, pixel)
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = corner
	made.texture_margin_right = corner
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	made.content_margin_left = ButtonShading.SIDE
	made.content_margin_right = ButtonShading.SIDE
	# The text is centered on the face, above the lip.
	made.content_margin_top = drop
	made.content_margin_bottom = lip
	_plates[key] = made
	return made


## The ring's color: white for a Selected Answer, faded toward the panel when the button
## cannot be pressed, light steel otherwise.
static func ring_color(is_selected: bool, is_disabled: bool) -> Color:
	if is_selected:
		return SELECTED_RING
	return STEEL.lerp(PANEL, 0.6) if is_disabled else STEEL


## How tall the face of a raised button [param height] pixels tall is: all of it but the lip.
static func face_height(height: float) -> float:
	return height - DitherShading.LIP


## Whether the pixel at [param x], [param y] is inside a [param width] by [param height] box
## shrunk by [param depth], whose corners step in blocks RING pixels square.
static func is_inside(x: int, y: int, width: int, height: int, depth: int) -> bool:
	var from_side: int = mini(x, width - 1 - x) - depth
	var from_end: int = mini(y, height - 1 - y) - depth
	if from_side < 0 or from_end < 0:
		return false
	@warning_ignore("integer_division")
	return from_side / RING + from_end / RING >= CORNER_STEPS
