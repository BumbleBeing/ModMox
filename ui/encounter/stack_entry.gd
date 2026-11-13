class_name StackEntry
extends PanelContainer
## One spell or ability in the Stack Window, or one trigger still being put in order
## there. Art on its left and two lines, each kept to one line and cut short with an
## ellipsis (A338): what it is, then who controls it and what it targets. A stack object
## has its own color on its border and a stripe down its left side; a trigger being ordered
## is plain with a dashed border, and has a grip to drag it by (A339, A345, A393).

## The cursor came over this entry, or left it.
signal hovered(is_over: bool)

const ART_SIZE: float = 52.0
const GRIP_WIDTH: float = 20.0
const GRIP_COLOR: Color = Color(1, 1, 1, 0.55)

var _potion_art: PotionArt = null
var _name: Label
var _detail: Label
var _color: Color
var _style: StyleBoxFlat
var _stripe: ColorRect = null
var _dashes: DashedBorder = null
var _row: HBoxContainer
var _grip: Control = null
var _catcher: ClickCatcher = null
var _art: TextureRect


## [param art_key] is the art to show, or "" for none.
func _init(art_key: String, first_line: String, second_line: String, color: Color, is_dashed: bool = false) -> void:
	_color = color
	_style = StyleBoxFlat.new()
	_style.bg_color = Color("#2c323c")
	_style.border_color = color
	_style.set_border_width_all(0 if is_dashed else 2)
	_style.set_corner_radius_all(5)
	_style.set_content_margin_all(5)
	add_theme_stylebox_override("panel", _style)
	_row = HBoxContainer.new()
	add_child(_row)
	if is_dashed:
		_dashes = DashedBorder.new(size, color, 2.0, -1.0)
		_dashes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_dashes)
		resized.connect(_dashes.queue_redraw)
	else:
		_stripe = ColorRect.new()
		_stripe.color = color
		_stripe.custom_minimum_size = Vector2(7, 0)
		_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(_stripe)
	_art = TextureRect.new()
	var picture: TextureRect = _art
	picture.texture = ArtLibrary.shared().cropped(art_key, Vector2(ART_SIZE, ART_SIZE)) if art_key != "" else null
	picture.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(picture)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(lines)
	_name = _cut_label(first_line, 16)
	_name.add_theme_font_override("font", CardFonts.title())
	lines.add_child(_name)
	_detail = _cut_label(second_line, 13)
	_detail.modulate = Color(1, 1, 1, 0.75)
	lines.add_child(_detail)
	mouse_entered.connect(func() -> void: hovered.emit(true))
	mouse_exited.connect(func() -> void: hovered.emit(false))


## Shows the art of the Potion authored in the file named [param key] where the art is: its
## ability is on the stack, and the Potion itself is gone (ADR 0032, A531).
func show_potion(key: String) -> void:
	_potion_art = PotionArt.new(key, ART_SIZE, true)
	_art.add_child(_potion_art)


## The Potion's art, or null for anything that did not come from a Potion.
func potion_art() -> PotionArt:
	return _potion_art


## The square at the left that shows the art: where a card put on the stack flies to.
func art() -> TextureRect:
	return _art


func name_text() -> String:
	return _name.text


func detail_text() -> String:
	return _detail.text


## Its own color: a stack object's hue, or the plain color of a trigger being ordered.
func color() -> Color:
	return _color


## The color its border is drawn in: its own, or the Glow's while it can be chosen.
func border_color() -> Color:
	return _style.border_color


## The color of the stripe down its left side, which never changes; null for a dashed
## entry, which has none. A Variant because "no stripe" is not a color.
func stripe_color() -> Variant:
	return _stripe.color if _stripe != null else null


func is_dashed() -> bool:
	return _dashes != null


## Whether both lines are kept to one line each and cut short with an ellipsis.
func is_cut() -> bool:
	return _name.clip_text and _detail.clip_text \
		and _name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS \
		and _detail.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS


## Makes it something a click can choose: its border glows as a target does, in place of
## its own color, while its stripe keeps that color (A354). Returns what takes the click.
func make_targetable() -> ClickCatcher:
	_style.border_color = DecisionClicks.color_of(DecisionClicks.Kind.TARGET)
	_style.set_border_width_all(3)
	_catcher = ClickCatcher.add(self, size)
	_catcher.mouse_entered.connect(func() -> void: hovered.emit(true))
	_catcher.mouse_exited.connect(func() -> void: hovered.emit(false))
	return _catcher


## What takes a click on it, or null if clicking it does nothing.
func click_catcher() -> ClickCatcher:
	return _catcher


## Gives it a grip at its right end: six dots, drawn, that say it can be dragged (A393).
func add_grip() -> void:
	_grip = Control.new()
	_grip.custom_minimum_size = Vector2(GRIP_WIDTH, 0)
	_grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grip.draw.connect(_draw_grip)
	_row.add_child(_grip)
	mouse_default_cursor_shape = Control.CURSOR_VSIZE


## Its grip, or null on an entry that cannot be dragged.
func grip() -> Control:
	return _grip


## Two columns of three dots, drawn: no font has to be searched for a glyph.
func _draw_grip() -> void:
	var middle: Vector2 = _grip.size / 2.0
	for column: int in 2:
		for line: int in 3:
			_grip.draw_circle(middle + Vector2(column * 7.0 - 3.5, (line - 1) * 8.0), 2.2, GRIP_COLOR)


func _cut_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
