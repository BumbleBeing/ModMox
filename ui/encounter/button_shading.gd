class_name ButtonShading
extends RefCounted
## How the encounter's made buttons are drawn (the pregame's, the sidebar's and the Pause
## Menu's): in the steel frame every button has (SteelFrame, game ADR 0066), Dither Shaded
## in the button's own color inside it, as the Inspector's buttons are, lighter under the cursor, sat down on its lip while held, and flat and gray while it
## cannot be pressed. A button never changes size for it: its plate keeps only SIDE pixels
## at its sides and lifts its text above the lip, or, where even that would make it grow,
## centers it on the whole plate.
##
## Each plate is painted once for each color, state and height and shared by every button
## drawn alike (by SteelFrame).

## A button that cannot be pressed: the Inspector's gray.
const DISABLED: Color = Color("#303238")
const DISABLED_TEXT: Color = Color(1, 1, 1, 0.4)
## The room a plate keeps at each side of its text.
const SIDE: int = 8
const STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "disabled"]


## Shades [param button] in [param color] with white text: see shade().
static func apply(button: Button, color: Color, disabled_color: Color = DISABLED) -> void:
	shade(button, color, disabled_color)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)


## Gives [param button], its size already set, the steel frame (SteelFrame) in
## [param color] in every state, and in [param disabled_color] while it cannot be pressed,
## keeping [param side] pixels at the sides of its text. Its text colors are left as they
## are. Under the cursor it is lighter; HoverEase eases that in.
static func shade(button: Button, color: Color, disabled_color: Color = DISABLED, side: int = SIDE,
		lifts_text: bool = true) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var height: int = maxi(1, int(button.size.y))
	for state: String in STATES:
		button.add_theme_stylebox_override(state, plate(color, state, height, side, lifts_text, disabled_color))


## The plate of a button [param height] pixels tall in [param state], framed in steel and
## drawn in [param color], or in [param disabled_color] while it cannot be pressed.
static func plate(color: Color, state: String, height: int, side: int = SIDE, lifts_text: bool = true,
		disabled_color: Color = DISABLED) -> StyleBoxTexture:
	return SteelFrame.plate(color, state, height, false, disabled_color, side, lifts_text)
