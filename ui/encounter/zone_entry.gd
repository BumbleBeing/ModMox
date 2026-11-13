class_name ZoneEntry
extends PanelContainer
## One thing in a Zone Window: a rectangle with art on its left, a name, and a line under
## it. Everything on the stack is drawn this way, spell or ability, and so is an Emblem and
## a Potion. One that can be used now is made usable: it glows green as a card that can be
## played does, brightens under the cursor, and takes a click (ADR 0032, A537).

const ART_SIZE: float = 64.0
## The color a Spent ability's text is drawn in on an entry, which is dark; the Emblem Face
## has its own for its light text box. What is written after it is the same on both (A520).
const USED_COLOR: Color = Color("#7c8492")
const USED_SUFFIX: String = EmblemFace.USED_SUFFIX
## The square shown for an Emblem that has no art yet, as on its Emblem Face (A534).
const NO_ART_COLOR: Color = EmblemFace.NO_ART_COLOR

var _name: Label
var _detail: Label
var _lines: VBoxContainer
var _row: HBoxContainer
var _picture: Control
var _style: StyleBoxFlat
var _tint: Color
var _catcher: ClickCatcher = null
## The lines under the name when show_lines() set them, and which of them are Spent.
var _line_texts: Array[String] = []
var _spent: Array[int] = []


## [param art_key] is the art to show, or "" for none.
func _init(art_key: String, entry_name: String, detail: String, tint: Color) -> void:
	_tint = tint
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("#2c323c")
	_style.border_color = tint
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(5)
	_style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", _style)
	_row = HBoxContainer.new()
	add_child(_row)
	var picture: TextureRect = TextureRect.new()
	picture.texture = ArtLibrary.shared().cropped(art_key, Vector2(ART_SIZE, ART_SIZE)) if art_key != "" else null
	picture.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture = picture
	_row.add_child(picture)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_lines)
	_name = Label.new()
	_name.text = entry_name
	_name.add_theme_font_override("font", CardFonts.title())
	_name.add_theme_font_size_override("font_size", 20)
	_name.clip_text = true
	_lines.add_child(_name)
	_detail = Label.new()
	_detail.text = detail
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 15)
	_detail.modulate = Color(1, 1, 1, 0.75)
	_lines.add_child(_detail)


## Keeps the line under the name to one line, cut with an ellipsis where the entry ends.
func cut_detail() -> void:
	_cut(_detail)


## Whether the line under the name is cut with an ellipsis instead of wrapping.
func is_detail_cut() -> bool:
	return not _line_texts.is_empty() or _detail.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS


func name_text() -> String:
	return _name.text


## The line under the name; after show_lines(), every line, joined as an Emblem's abilities
## always were.
func detail_text() -> String:
	return " · ".join(_line_texts) if not _line_texts.is_empty() else _detail.text


## Shows [param picture] where the art is, in place of what was there: a Potion's art, or
## the gray square of an Emblem with none.
func show_picture(picture: Control) -> void:
	var place: int = _picture.get_index()
	_row.remove_child(_picture)
	_picture.queue_free()
	_picture = picture
	picture.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(picture)
	_row.move_child(picture, place)


## Shows the gray square of an Emblem that has no art.
func show_no_art() -> void:
	var square: ColorRect = ColorRect.new()
	square.color = NO_ART_COLOR
	show_picture(square)


## What is drawn where the art is.
func picture() -> Control:
	return _picture


## Shows [param lines] under the name, each on a line of its own cut with an ellipsis: an
## Emblem's or a Potion's abilities. Those whose place is in [param spent] are gray and
## marked "(used)" (A520).
func show_lines(lines: Array[String], spent: Array[int] = []) -> void:
	_line_texts = lines.duplicate()
	_spent = spent.duplicate()
	for child: Node in _lines.get_children():
		if child != _name and child != _detail:
			_lines.remove_child(child)
			child.queue_free()
	_detail.visible = lines.is_empty()
	for index: int in lines.size():
		var line: Label = Label.new()
		var is_spent: bool = spent.has(index)
		line.text = lines[index] + (USED_SUFFIX if is_spent else "")
		line.add_theme_font_size_override("font_size", 15)
		if is_spent:
			line.add_theme_color_override("font_color", USED_COLOR)
		else:
			line.modulate = Color(1, 1, 1, 0.75)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cut(line)
		_lines.add_child(line)


## The text of each line show_lines() drew, as it reads on the entry.
func line_texts() -> Array[String]:
	var texts: Array[String] = []
	for index: int in _line_texts.size():
		texts.append(_line_texts[index] + (USED_SUFFIX if _spent.has(index) else ""))
	return texts


## Whether line [param index] is drawn as a Spent ability.
func is_line_spent(index: int) -> bool:
	return _spent.has(index)


## Makes it something a click uses: its border glows green in place of its own color, and
## it brightens under the cursor with the pointing hand, as a card in hand that can be
## played does (A537). Returns what takes the click.
func make_usable() -> ClickCatcher:
	_style.border_color = DecisionClicks.color_of(DecisionClicks.Kind.PLAY)
	_style.set_border_width_all(3)
	_style.shadow_color = Color(_style.border_color, 0.6)
	_style.shadow_size = 6
	_catcher = ClickCatcher.add(self, size)
	return _catcher


## What takes a click on it, or null if clicking it does nothing.
func click_catcher() -> ClickCatcher:
	return _catcher


## Whether a click on it uses it.
func is_usable() -> bool:
	return _catcher != null


## The color its border is drawn in: its own, or the Glow's while it can be used.
func border_color() -> Color:
	return _style.border_color


static func _cut(line: Label) -> void:
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
