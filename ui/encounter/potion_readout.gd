class_name PotionReadout
extends Control
## A Potion as the Inspector shows it (ADR 0033, A532, A581, A588): its Potion Icon enlarged
## where a Card Face would be, glowing in its Rarity's color, with its name and a type line
## of its Rarity and "Potion", such as "Rare Potion", under it. Its rules text is the
## Inspector's Card Text, not the readout's.

## How much of the Inspector's width the art takes.
const ART_SHARE: float = 0.66

var _look: CardLook
var _art: PotionArt
var _name: Label
var _type_line: Label


## Draws [param look], a Potion's, [param width] pixels wide, glowing in the color of its
## [param rarity] (a Rarity, or null for none).
func setup(look: CardLook, width: float, rarity: Variant) -> void:
	_look = look
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A whole number of screen pixels to each art pixel, so the icon's edges stay hard.
	var art_pixel: float = floorf(width * ART_SHARE / (PotionArt.CELLS + 2))
	var side: float = art_pixel * (PotionArt.CELLS + 2)
	_art = PotionArt.new(look.art_key, side, false)
	_art.position = Vector2(roundf((width - side) / 2.0), 24)
	add_child(_art)
	if rarity != null:
		# Round the art, not as its child: the art cuts off whatever is drawn outside it.
		var ring: Control = Control.new()
		ring.position = _art.position
		ring.size = _art.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ring)
		BorderEffects.add_glow(ring, ring.size, Inspector.glow_of(rarity as MmCardDefinition.Rarity))
	var below: float = _art.position.y + side + 24
	_name = _label(look.name, 30, Color.WHITE, Rect2(0, below, width, 40))
	_name.add_theme_font_override("font", CardFonts.title())
	var type_line: String = look.held_type_line()
	if rarity != null:
		type_line = "%s %s" % [Inspector.RARITY_NAMES[rarity as MmCardDefinition.Rarity], type_line]
	_type_line = _label(type_line, 18, Color("#9aa3af"), Rect2(0, below + 44, width, 24))
	size = Vector2(width, below + 44 + 24)
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


## The type line, such as "Rare Potion".
func type_line_text() -> String:
	return _type_line.text


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
