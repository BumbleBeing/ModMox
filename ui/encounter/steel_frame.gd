class_name SteelFrame
extends RefCounted
## How a button is drawn (game ADR 0066, the conventions): the Info Panel's and the Pass
## Button through apply(), every other made button of the encounter through ButtonShading,
## and the Inspector's through InspectorParts. Dither
## Shading in the button's own color inside a pixel border with stepped corners, nothing
## rounded. The border is a ring of light steel RING pixels thick with a dark line one pixel
## thick inside it, over the button's lip. The ring of a Selected Answer is white. A button
## that cannot be pressed lies flat, with no lip, its ring faded toward the panel. Under
## the cursor its face lightens, eased in and out and never switched (HoverEase).
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
## The room a roomy plate keeps round its text.
const ROOMY_SIDE: int = 10
const ROOMY_PAD: int = 7

static var _plates: Dictionary[String, StyleBoxTexture] = {}


## Frames [param button], its size already set, in [param color] with white text, its ring
## white when [param is_selected].
static func apply(button: Button, color: Color, is_selected: bool = false) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var height: int = maxi(1, int(button.size.y))
	for state: String in ButtonShading.STATES:
		# The cursor's lightening is eased by a layer over the face, not switched by a plate.
		button.add_theme_stylebox_override(state, plate(color, "normal" if state == "hover" else state, height, is_selected))
	var layer: Panel = Panel.new()
	layer.size = button.size
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_theme_stylebox_override("panel", hover_plate(height))
	HoverEase.ease(button, layer)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", ButtonShading.DISABLED_TEXT)


## The plate of a button [param height] pixels tall in [param state], drawn in [param color],
## and in [param disabled_fill] while it cannot be pressed. It keeps [param side] pixels at
## the sides of its text and [param pad] above and below it, and lifts the text above its
## lip unless [param lifts_text] is off. A [param ring] color, when given, is the ring's in
## place of steel, for a button marked as the one chosen.
static func plate(color: Color, state: String, height: int, is_selected: bool = false,
		disabled_fill: Color = ButtonShading.DISABLED, side: int = ButtonShading.SIDE, lifts_text: bool = true,
		pad: int = 0, ring: Variant = null) -> StyleBoxTexture:
	var key: String = "%s/%s/%d/%s/%s/%d/%s/%d/%s" % [color.to_html(), state, height, is_selected, disabled_fill.to_html(), side,
		lifts_text, pad, (ring as Color).to_html() if ring != null else ""]
	if _plates.has(key):
		return _plates[key]
	var is_disabled: bool = state == "disabled"
	var is_pressed: bool = state in ["pressed", "hover_pressed"]
	var fill: Color = color
	if is_disabled:
		fill = disabled_fill
	elif state == "hover":
		fill = color.lightened(InspectorParts.HOVER_LIGHTEN)
	var lip: int = 0 if is_disabled else (DitherShading.PRESSED_LIP if is_pressed else DitherShading.LIP)
	# A pressed button sits down on its lip: its face starts lower.
	var drop: int = DitherShading.LIP - DitherShading.PRESSED_LIP if is_pressed and not is_disabled else 0
	var face_height: int = height - lip - drop
	var top: Color = fill.darkened(0.2) if is_pressed else fill.lightened(0.12)
	var bottom: Color = fill.lightened(0.02) if is_pressed else fill.darkened(0.25)
	var ring_now: Color = ring as Color if ring != null and not is_disabled else ring_color(is_selected, is_disabled)
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
					pixel = ring_now
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
	made.content_margin_left = side
	made.content_margin_right = side
	# The text is centered on the face, above the lip, or on the whole plate.
	made.content_margin_top = (drop if lifts_text else 0) + pad
	made.content_margin_bottom = (lip if lifts_text else 0) + pad
	_plates[key] = made
	return made


## The plate of a button that takes its size from its text: as plate(), with ROOMY_SIDE
## pixels at the sides of its text and ROOMY_PAD above and below it.
static func roomy_plate(color: Color, state: String, height: int, disabled_fill: Color = ButtonShading.DISABLED,
		ring: Variant = null) -> StyleBoxTexture:
	return plate(color, state, height, false, disabled_fill, ROOMY_SIDE, true, ROOMY_PAD, ring)


## Frames [param button] with roomy plates in [param color] in every state, for
## [param height] pixels.
static func frame_roomy(button: Button, color: Color, height: int, disabled_fill: Color = ButtonShading.DISABLED,
		ring: Variant = null) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state: String in ButtonShading.STATES:
		button.add_theme_stylebox_override(state, roomy_plate(color, state, height, disabled_fill, ring))


## Frames a button whose height its container gives it: with roomy plates painted for its
## height now, and again whenever that changes, so the frame is never stretched.
static func frame_as_sized(button: Button, color: Color, disabled_fill: Color = ButtonShading.DISABLED) -> void:
	var paint: Callable = func() -> void: frame_roomy(button, color, maxi(1, int(button.size.y)), disabled_fill)
	button.resized.connect(paint)
	paint.call()


## The layer that lightens a raised button [param height] pixels tall under the cursor:
## white over its face as far as a hover lightens, and nothing over its ring or lip. White
## text under it is left as it is.
static func hover_plate(height: int) -> StyleBoxTexture:
	var key: String = "hover/%d" % height
	if _plates.has(key):
		return _plates[key]
	var face: int = height - DitherShading.LIP
	var corner: int = RING * (CORNER_STEPS + 3)
	var width: int = corner * 2 + DitherShading.BLOCK * 4
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			image.set_pixel(x, y, Color(1, 1, 1, InspectorParts.HOVER_LIGHTEN) if is_inside(x, y, width, face, FRAME) else Color(0, 0, 0, 0))
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = corner
	made.texture_margin_right = corner
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_plates[key] = made
	return made


## The ring alone of a raised button [param height] pixels tall, in white and with nothing
## inside or outside it: what flashes when a button lights up, step for step the shape of
## its frame, so that no corner the button does not have is lit.
static func ring_plate(height: int) -> StyleBoxTexture:
	var key: String = "ring/%d" % height
	if _plates.has(key):
		return _plates[key]
	var face: int = height - DitherShading.LIP
	var corner: int = RING * (CORNER_STEPS + 3)
	var width: int = corner * 2 + DitherShading.BLOCK * 4
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var is_ring: bool = is_inside(x, y, width, face, 0) and not is_inside(x, y, width, face, RING)
			image.set_pixel(x, y, Color.WHITE if is_ring else Color(0, 0, 0, 0))
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = corner
	made.texture_margin_right = corner
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
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
