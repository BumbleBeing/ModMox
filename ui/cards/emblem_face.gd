class_name EmblemFace
extends Control
## An Emblem drawn in full, in the Inspector (ADR 0033, A533): its art in a border of its
## own, its name, a type line that reads "Emblem", its rules text with any Spent ability
## gray and marked "(used)", and the artist's credit. It is the size of a Card Face and has
## no Rarity glow. An Emblem with no art shows a gray box and no credit.
##
## The border is a plain gray frame until the user supplies one.

## The face as it was designed, which every part is scaled from.
const DESIGN: Vector2 = Vector2(388, 543)
const FRAME_COLOR: Color = Color("#3a3f4a")
const EDGE_COLOR: Color = Color("#8a8f98")
const NO_ART_COLOR: Color = Color("#6b7280")
const TEXT_BOX_COLOR: Color = Color("#d9dce3")
const INK: Color = Color("#14141a")
## A Spent ability's ink, on the light text box.
const USED_INK: Color = Color("#8a8f98")
const USED_SUFFIX: String = " (used)"

var _look: CardLook
var _scale: float = 1.0
var _name: Label
var _type_line: Label
var _art: TextureRect = null
var _no_art: ColorRect = null
var _text: RichTextLabel
var _credit: Label = null


## Draws [param look], an Emblem's, [param height] pixels tall.
func setup(look: CardLook, height: float) -> void:
	_look = look
	_scale = height / DESIGN.y
	size = DESIGN * _scale
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame: Panel = Panel.new()
	frame.size = size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FRAME_COLOR
	style.border_color = EDGE_COLOR
	style.set_border_width_all(int(round(10 * _scale)))
	style.set_corner_radius_all(int(round(16 * _scale)))
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	_name = _label(look.name, 22, Color.WHITE, Rect2(22, 18, 344, 30))
	_name.add_theme_font_override("font", CardFonts.title())
	_name.clip_text = true
	var art_box: Rect2 = _scaled(Rect2(22, 54, 344, 250))
	var texture: Texture2D = ArtLibrary.shared().cropped(look.art_key, art_box.size) if look.art_key != "" else null
	if texture != null:
		_art = CardShapes.image(texture, art_box)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)
	else:
		_no_art = ColorRect.new()
		_no_art.color = NO_ART_COLOR
		_no_art.position = art_box.position
		_no_art.size = art_box.size
		_no_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_no_art)
	_type_line = _label(look.held_type_line(), 18, Color("#e4e7ee"), Rect2(22, 308, 344, 26))
	var box: Panel = CardShapes.rounded(_scaled(Rect2(22, 340, 344, 160)).size, 4 * _scale, TEXT_BOX_COLOR)
	box.position = _scaled(Rect2(22, 340, 344, 160)).position
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.text = rules_bbcode(look)
	_text.position = Vector2(8, 6) * _scale
	_text.size = box.size - Vector2(16, 12) * _scale
	_text.add_theme_font_override("normal_font", CardFonts.body())
	_text.add_theme_font_size_override("normal_font_size", int(round(17 * _scale)))
	_text.add_theme_color_override("default_color", INK)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)
	var artist: String = ArtLibrary.shared().artist(look.art_key) if _art != null else ""
	if artist != "":
		_credit = _label("Illus. " + artist, 12, Color("#c3c9d6"), Rect2(22, 506, 344, 18))


## The rules text of [param look] as the face prints it: one ability to a line, a Spent one
## gray and marked "(used)".
static func rules_bbcode(look: CardLook) -> String:
	var lines: PackedStringArray = []
	for index: int in look.rules_lines.size():
		if look.is_ability_spent(index):
			lines.append("[color=#%s]%s%s[/color]" % [USED_INK.to_html(false), look.rules_lines[index], USED_SUFFIX])
		else:
			lines.append(look.rules_lines[index])
	return "\n".join(lines)


## The look it was drawn from.
func look() -> CardLook:
	return _look


## The Emblem's name, as drawn.
func name_text() -> String:
	return _name.text


## The type line, which reads "Emblem".
func type_line_text() -> String:
	return _type_line.text


## The rules text as it reads, without its colors.
func rules_text() -> String:
	return _text.get_parsed_text()


## Whether it shows a picture; without one it shows the gray box.
func has_art() -> bool:
	return _art != null


## The gray box of an Emblem with no art, or null.
func no_art_box() -> ColorRect:
	return _no_art


## The artist's credit, or "" for an Emblem with no art.
func credit_text() -> String:
	return _credit.text if _credit != null else ""


func _scaled(design: Rect2) -> Rect2:
	return Rect2(design.position * _scale, design.size * _scale)


func _label(text: String, font_size: int, color: Color, design: Rect2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = design.position * _scale
	label.size = design.size * _scale
	label.add_theme_font_size_override("font_size", int(round(font_size * _scale)))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
