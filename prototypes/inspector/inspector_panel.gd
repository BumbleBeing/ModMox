extends Panel
## THROWAWAY (13h prototype): the Inspector. A card's Card Face with its Rarity's glow, See
## Original, its State List and its Reminders, each list in a scrolling section of its own.

signal close_pressed

const Notes := preload("res://prototypes/inspector/inspector_notes.gd")
const WIDTH: float = 340.0
const PAD: float = 16.0
const MUTED: Color = Color("#9aa3af")
## The most each scrolling section may take, in pixels.
const STATE_CAP: float = 170.0
const REMINDER_CAP: float = 270.0
const NO_CARD: int = 0

var _header: HBoxContainer
var _close: Button
var _face_holder: Control
var _face: CardFace = null
var _original_box: Button
var _state_title: Label
var _state_scroll: ScrollContainer
var _state_list: VBoxContainer
var _reminder_title: Label
var _reminder_scroll: ScrollContainer
var _reminder_list: VBoxContainer
var _key: int = NO_CARD
var _look: CardLook = null
var _original: CardLook = null
var _glow: Variant = null
var _column: VBoxContainer
## While one card is fading out for another: what to show once it has gone, and the fade.
var _waiting: Array = []
var _swap: Tween = null


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#22262e")
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = PAD
	column.offset_top = PAD / 2.0
	column.offset_right = -PAD
	column.offset_bottom = -PAD
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_column = column
	_header = HBoxContainer.new()
	_header.custom_minimum_size = Vector2(0, 30)
	var pinned: Label = _label("Pinned", 16, MUTED)
	pinned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(pinned)
	_close = Button.new()
	_close.text = "✕"
	_close.focus_mode = Control.FOCUS_NONE
	_close.custom_minimum_size = Vector2(30, 30)
	_close.tooltip_text = "Let the pinned card go (Escape)"
	_close.pressed.connect(func() -> void: close_pressed.emit())
	_header.add_child(_close)
	column.add_child(_header)
	_face_holder = Control.new()
	_face_holder.custom_minimum_size = Vector2(WIDTH - 2.0 * PAD, face_height())
	_face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_face_holder)
	_original_box = Button.new()
	_original_box.text = "See Original"
	_original_box.toggle_mode = true
	_original_box.focus_mode = Control.FOCUS_NONE
	_original_box.custom_minimum_size = Vector2(150, 34)
	_original_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_original_box.add_theme_font_size_override("font_size", 17)
	_original_box.toggled.connect(func(_is_on: bool) -> void: _draw_face())
	column.add_child(_original_box)
	_state_title = _label("Right now", 17, MUTED)
	column.add_child(_state_title)
	_state_scroll = _scroll()
	column.add_child(_state_scroll)
	_state_list = _list(_state_scroll)
	_reminder_title = _label("Keywords", 17, MUTED)
	column.add_child(_reminder_title)
	_reminder_scroll = _scroll()
	column.add_child(_reminder_scroll)
	_reminder_list = _list(_reminder_scroll)


static func face_height() -> float:
	return (WIDTH - 2.0 * PAD) / CardGeometry.ASPECT


## Shows the card [param key]: its [param look] now, its [param original] (null if it has
## none), the color of its Rarity's glow (null for none) and its State List. See Original
## stays as it is while the same card is shown, and is unticked for another. Another card
## takes [param seconds] to change to: the one showing eases out, then the new one eases
## in. The same card, changed, is redrawn at once.
func show_card(key: int, look: CardLook, original: CardLook, glow: Variant, states: Array[Array], is_pinned: bool,
		seconds: float = 0.0) -> void:
	var shown: Array = [key, look, original, glow, states, is_pinned]
	var is_fading_out: bool = not _waiting.is_empty()
	if is_fading_out or (key != _key and _key != NO_CARD and seconds > 0.0 and is_visible_in_tree() and modulate.a > 0.0):
		_waiting = shown
		if is_fading_out:
			return
		if _swap != null:
			_swap.kill()
		_swap = create_tween().set_trans(Easing.TRANSITION)
		_swap.tween_property(_column, "modulate:a", 0.0, seconds / 2.0 * _column.modulate.a).set_ease(Tween.EASE_IN)
		_swap.tween_callback(func() -> void:
			var next: Array = _waiting
			_waiting = []
			_apply(next))
		_swap.tween_property(_column, "modulate:a", 1.0, seconds / 2.0).set_ease(Tween.EASE_OUT)
		return
	if key != _key:
		# Nothing to ease out of: the Inspector itself is easing in.
		if _swap != null:
			_swap.kill()
		_column.modulate.a = 1.0
	_apply(shown)


func _apply(shown: Array) -> void:
	var key: int = shown[0]
	var original: CardLook = shown[2] as CardLook
	var states: Array[Array] = shown[4]
	var is_pinned: bool = shown[5]
	if key != _key:
		_original_box.set_pressed_no_signal(false)
	_key = key
	_look = shown[1] as CardLook
	_original = original
	_glow = shown[3]
	_header.modulate.a = 1.0 if is_pinned else 0.0
	_close.disabled = not is_pinned
	_original_box.disabled = original == null
	_original_box.tooltip_text = "" if original != null else "An Emblem or a token has no original."
	_fill(_state_list, states, false)
	_state_title.visible = not states.is_empty()
	_state_scroll.visible = not states.is_empty()
	_draw_face()


func is_showing_original() -> bool:
	return _original_box.button_pressed and _original != null


func _process(_delta: float) -> void:
	# A section is as tall as what is in it, up to its cap; past that it scrolls.
	_state_scroll.custom_minimum_size.y = minf(_state_list.get_combined_minimum_size().y, STATE_CAP)
	_reminder_scroll.custom_minimum_size.y = minf(_reminder_list.get_combined_minimum_size().y, REMINDER_CAP)


func _draw_face() -> void:
	if _look == null:
		return
	if _face != null:
		_face_holder.remove_child(_face)
		_face.queue_free()
	var shown: CardLook = _original if is_showing_original() else _look
	_face = CardFace.new()
	_face.setup(shown, face_height())
	_face_holder.add_child(_face)
	if _glow != null:
		BorderEffects.add_glow(_face, _face.size, _glow as Color)
	var reminders: Array[Array] = Notes.reminders(shown)
	_fill(_reminder_list, reminders, true)
	_reminder_title.visible = not reminders.is_empty()
	_reminder_scroll.visible = not reminders.is_empty()


## Fills [param list] with [param entries]: [title, sentence] each, or with
## [param has_icons] [icon, title, sentence].
func _fill(list: VBoxContainer, entries: Array[Array], has_icons: bool) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for entry: Array in entries:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if has_icons:
			var icon: TextureRect = TextureRect.new()
			icon.texture = entry[0] as Texture2D
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.custom_minimum_size = Vector2(32, 32)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(icon)
		var words: VBoxContainer = VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var first: int = 1 if has_icons else 0
		words.add_child(_label(entry[first] as String, 17, Color.WHITE))
		var sentence: Label = _label(entry[first + 1] as String, 15, MUTED)
		sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(sentence)
		row.add_child(words)
		list.add_child(row)


static func _scroll() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


static func _list(scroll: ScrollContainer) -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
