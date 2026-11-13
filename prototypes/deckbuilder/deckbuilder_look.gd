class_name DeckbuilderLook
extends RefCounted
## How the deckbuilder looks. Everything that is not printed on a card is set in Linux
## Libertine (SIL Open Font License, bundled in assets/fonts/); cards keep their own fonts
## (CardFonts). Every background is a shade of maroon, laid out like a workbench (A557): the
## bench behind everything is the darkest, panes are mid, and what stands on a pane (a deck
## column, a panel inside it) is lighter. Buttons are shaded gray and text boxes dark gray. Text is a
## shade of gray, never of the background's color. Card faces, the green and red of Mods
## and Hexes and the mana colors keep their own colors.

const BENCH: Color = Color("#170a0e")
const PANE: Color = Color("#2b1219")
const PANE_BORDER: Color = Color("#16080b")
## A deck column: lighter than a pane, so the piles stand out from the bench.
const COLUMN: Color = Color("#3a1a23")
const SUBPANEL: Color = Color("#46202b")
## A panel in the inspector: darker than other subpanels, lighter than its pane.
const INSPECTOR_PANEL: Color = Color("#35171f")
## The tray the Mod Slot bubbles sit in.
const BUBBLE_TRAY: Color = Color("#34373d")
const BUBBLE_TRAY_BORDER: Color = Color("#1f2125")
const BUTTON_DISABLED: Color = Color("#303238")
## The plate behind Zoom and its sliders.
const BAR_PANEL: Color = Color("#34373d")
## The thin gray edge of a deck column and of a panel in the inspector, and how wide it is.
const PANEL_EDGE: Color = Color("#575a60")
const PANEL_EDGE_WIDTH: int = 2
const SUBPANEL_BORDER: Color = Color("#220d13")
## A hollow cut into the wood: a text box, an empty place for a card.
const HOLLOW: Color = Color("#171a1f")
const BUTTON: Color = Color("#4b4e55")
const BUTTON_HOVER: Color = Color("#5b5f67")
const BUTTON_PRESSED: Color = Color("#393c42")
const BUTTON_EDGE: Color = Color("#1f2125")
const TEXT: Color = Color("#e9e9e9")
const MUTED: Color = Color("#b6b6b6")
const DISABLED_TEXT: Color = Color("#797979")
## What is lit: a chosen filter, a column a card would drop into.
const BRASS: Color = Color("#e8cf8a")

const FOLDER: String = "res://assets/fonts/linux_libertine/linlibertine-%s.ttf"

static var _theme: Theme = null


static func regular() -> Font:
	return load(FOLDER % "regular") as Font


static func bold() -> Font:
	return load(FOLDER % "bold") as Font


## The theme a deckbuilder window takes, so that every label, button and box under it is
## set in the deckbuilder's font.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = regular()
		_theme.default_font_size = 18
		_theme.set_stylebox("normal", "Button", _button_face(BUTTON, false))
		_theme.set_stylebox("hover", "Button", _button_face(BUTTON_HOVER, false))
		_theme.set_stylebox("pressed", "Button", _button_face(BUTTON_PRESSED, true))
		_theme.set_stylebox("hover_pressed", "Button", _button_face(BUTTON_PRESSED, true))
		_theme.set_stylebox("disabled", "Button", _button_face(BUTTON_DISABLED, false))
		_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			_theme.set_color(state, "Button", TEXT)
		_theme.set_color("font_disabled_color", "Button", DISABLED_TEXT)
		_theme.set_stylebox("normal", "LineEdit", _plate(HOLLOW, SUBPANEL_BORDER, 5, 6.0))
		_theme.set_stylebox("focus", "LineEdit", _plate(HOLLOW, BRASS, 5, 6.0))
		_theme.set_color("font_color", "LineEdit", TEXT)
		_theme.set_color("font_placeholder_color", "LineEdit", DISABLED_TEXT)
		_theme.set_color("caret_color", "LineEdit", TEXT)
		_theme.set_color("font_color", "Label", TEXT)
		_theme.set_stylebox("panel", "PopupMenu", _plate(SUBPANEL, PANE_BORDER, 5, 6.0))
		_theme.set_stylebox("hover", "PopupMenu", _plate(BUTTON_HOVER, BUTTON_EDGE, 4, 2.0))
		_theme.set_color("font_color", "PopupMenu", TEXT)
		_theme.set_color("font_hover_color", "PopupMenu", TEXT)
		_theme.set_stylebox("panel", "TooltipPanel", _plate(HOLLOW, SUBPANEL_BORDER, 4, 6.0))
		_theme.set_color("font_color", "TooltipLabel", TEXT)
	return _theme


## Shades [param style] as everything raised is shaded: lit from above, with a dark lip
## [param lip] pixels deep underneath and a soft shadow.
static func shade(style: StyleBoxFlat, lip: int = 4) -> void:
	style.border_color = style.bg_color.darkened(0.45)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = lip
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)


## A button's face, lit from above: its fill, a dark lip underneath and a soft shadow. A
## pressed one sits down on its lip.
static func _button_face(fill: Color, is_pressed: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = _plate(fill, fill.darkened(0.45), 6, 8.0)
	style.border_width_top = 1
	style.border_width_bottom = 1 if is_pressed else 4
	style.content_margin_top = 10.0 if is_pressed else 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	return style


static func _plate(fill: Color, edge: Color, radius: int, margin: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
