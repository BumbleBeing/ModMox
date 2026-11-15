class_name ButtonShading
extends RefCounted
## How the encounter's made buttons are drawn (the pregame's, the Pass Button and the
## sidebar's): Dither Shading in the button's own color, as the Inspector's buttons are,
## lighter under the cursor, sat down on its lip while held, and flat and gray while it
## cannot be pressed. A button never changes size for it: its plate keeps only SIDE pixels
## at its sides and lifts its text above the lip, or, where even that would make it grow,
## centers it on the whole plate.
##
## Each plate is painted once for each color, state and height and shared by every button
## drawn alike.

## A button that cannot be pressed: the Inspector's gray.
const DISABLED: Color = Color("#303238")
const DISABLED_TEXT: Color = Color(1, 1, 1, 0.4)
## The room a plate keeps at each side of its text.
const SIDE: int = 8
const STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]

static var _plates: Dictionary[String, StyleBoxTexture] = {}


## Shades [param button] in [param color] with white text: see shade().
static func apply(button: Button, color: Color, disabled_color: Color = DISABLED) -> void:
	shade(button, color, disabled_color)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)


## Gives [param button], its size already set, Dither Shading in [param color] in every
## state, and [param disabled_color] while it cannot be pressed, keeping [param side] pixels
## at the sides of its text. Its text colors are left as they are.
static func shade(button: Button, color: Color, disabled_color: Color = DISABLED, side: int = SIDE,
		lifts_text: bool = true) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var height: int = maxi(1, int(button.size.y))
	for state: String in STATES:
		button.add_theme_stylebox_override(state,
			plate(disabled_color if state == "disabled" else color, state, height, side, lifts_text))


## The plate of a button [param height] pixels tall in [param state], drawn in [param color].
static func plate(color: Color, state: String, height: int, side: int = SIDE, lifts_text: bool = true) -> StyleBoxTexture:
	var key: String = "%s/%s/%d/%d/%s" % [color.to_html(), state, height, side, lifts_text]
	if _plates.has(key):
		return _plates[key]
	var made: StyleBoxTexture
	match state:
		"hover":
			made = DitherShading.button_plate(color.lightened(InspectorParts.HOVER_LIGHTEN), false, height)
		"pressed", "hover_pressed":
			made = DitherShading.button_plate(color, true, height)
		"disabled":
			made = DitherShading.disabled_plate(color, height)
		_:
			made = DitherShading.button_plate(color, false, height)
	made.content_margin_left = side
	made.content_margin_right = side
	made.content_margin_bottom = made.content_margin_bottom - made.content_margin_top if lifts_text else 0.0
	made.content_margin_top = 0
	_plates[key] = made
	return made
