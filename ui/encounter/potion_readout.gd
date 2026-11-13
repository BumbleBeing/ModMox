class_name PotionReadout
extends Control
## A Potion as the Inspector shows it (ADR 0033, A532): its Potion Icon enlarged where a
## Card Face would be, glowing in its Rarity's color, with its name, a type line that reads
## "Potion" and its rules text under it.

## How much of the Inspector's width the art takes.
const ART_SHARE: float = 0.66

var _look: CardLook
var _art: PotionArt
var _name: Label
var _type_line: Label
var _text: Label


## Draws [param look], a Potion's, [param width] pixels wide, glowing in [param glow] (a
## Color, or null for none).
func setup(look: CardLook, width: float, glow: Variant) -> void:
	_look = look
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A whole number of screen pixels to each art pixel, so the icon's edges stay hard.
	var art_pixel: float = floorf(width * ART_SHARE / (PotionArt.CELLS + 2))
	var side: float = art_pixel * (PotionArt.CELLS + 2)
	_art = PotionArt.new(look.art_key, side, false)
	_art.position = Vector2(roundf((width - side) / 2.0), 24)
	add_child(_art)
	if glow != null:
		# Round the art, not as its child: the art cuts off whatever is drawn outside it.
		var ring: Control = Control.new()
		ring.position = _art.position
		ring.size = _art.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ring)
		BorderEffects.add_glow(ring, ring.size, glow as Color)
	var below: float = _art.position.y + side + 24
	_name = _label(look.name, 30, Color.WHITE, Rect2(0, below, width, 40))
	_name.add_theme_font_override("font", CardFonts.title())
	_type_line = _label(look.held_type_line(), 18, Color("#9aa3af"), Rect2(0, below + 44, width, 24))
	_text = _label(look.rules_text, 20, Color("#e4e7ee"), Rect2(16, below + 84, width - 32, 130))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	size = Vector2(width, below + 84 + 130)
	custom_minimum_size = size


## The look it was drawn from.
func look() -> CardLook:
	return _look


## The Potion Icon, enlarged.
func art() -> PotionArt:
	return _art


## The Potion's name, as drawn.
func name_text() -> String:
	return _name.text


## The type line, which reads "Potion".
func type_line_text() -> String:
	return _type_line.text


## What the Potion does, as drawn.
func rules_text() -> String:
	return _text.text


## The color the art glows in, or null.
func glow_color() -> Variant:
	for child: Node in get_children():
		if child is Control and BorderEffects.glow_color(child as Control) != null:
			return BorderEffects.glow_color(child as Control)
	return null


func _label(text: String, font_size: int, color: Color, box: Rect2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = box.position
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
