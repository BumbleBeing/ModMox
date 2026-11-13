class_name Inspector
extends Panel
## The Inspector (13h, ADR 0033): where a card is read in full during an encounter. It lies
## over the sidebar while a card is pinned and shows that card's Card Face with its Rarity's glow, View Original under
## it, its State List and its Reminders, each list in a scrolling section of its own that
## is no taller than what is in it. It draws what it is handed and asks for nothing: the
## Encounter Screen says which card, from its Inspection.
##
## Built once and filled, never rebuilt: a change of card eases the old one out and the new
## one in, and the same card changed, by a new snapshot or by View Original, is redrawn at
## once.

const PAD: float = 16.0
## What the top of the Inspector says.
const HINT: String = "[Click off to close]"
## The room above and below it: one unit (A474).
const HINT_BUFFER: int = 4
const BACKGROUND: Color = Color("#22262e")
const MUTED: Color = Color("#9aa3af")
## The most each scrolling section may take, in pixels.
const STATE_CAP: float = 170.0
const REMINDER_CAP: float = 270.0
## What shown_key() gives before any card is shown.
const NO_CARD: int = Inspection.NOTHING
## The color a card's face glows in for its Rarity (A466): gray, silver, gold, honey and
## light green.
const GLOWS: Dictionary[MmCardDefinition.Rarity, Color] = {
	MmCardDefinition.Rarity.COMMON: Color("#8a8f98"),
	MmCardDefinition.Rarity.UNCOMMON: Color("#d5dbe3"),
	MmCardDefinition.Rarity.RARE: Color("#f2c744"),
	MmCardDefinition.Rarity.MYTHIC: Color("#e89a2b"),
	MmCardDefinition.Rarity.POWER_NINE: Color("#9be88a"),
}

## What each Rarity is called, as on a Potion's entry in its window.
const RARITY_NAMES: Dictionary[MmCardDefinition.Rarity, String] = {
	MmCardDefinition.Rarity.COMMON: "Common", MmCardDefinition.Rarity.UNCOMMON: "Uncommon",
	MmCardDefinition.Rarity.RARE: "Rare", MmCardDefinition.Rarity.MYTHIC: "Mythic",
	MmCardDefinition.Rarity.POWER_NINE: "Power-9",
}

var _contents: VBoxContainer
var _hint: Label
var _face_holder: Control
var _face: CardFace = null
## What stands in the face's place for an Emblem or a Potion (ADR 0033).
var _emblem_face: EmblemFace = null
var _potion_readout: PotionReadout = null
var _original_button: Button
var _state_title: Label
var _state_scroll: ScrollContainer
var _state_list: VBoxContainer
var _reminder_title: Label
var _reminder_scroll: ScrollContainer
var _reminder_list: VBoxContainer
var _reminder_icons: Array[TextureRect] = []
var _key: int = NO_CARD
var _look: CardLook = null
var _original: CardLook = null
var _glow: Variant = null
var _states: Array[StateEntry] = []
## While one card is easing out for another: what to show once it has gone, and the fade.
var _waiting: Array = []
var _swap: Tween = null


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_contents = VBoxContainer.new()
	_contents.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contents.offset_left = PAD
	_contents.offset_top = 0.0
	_contents.offset_right = -PAD
	_contents.offset_bottom = -PAD
	_contents.add_theme_constant_override("separation", 6)
	add_child(_contents)
	# In place of a close button: any click off the Inspector lets the card go (A473).
	_hint = Label.new()
	_hint.text = HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10 + UiText.RAISE)
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buffer: MarginContainer = MarginContainer.new()
	buffer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buffer.add_theme_constant_override("margin_top", HINT_BUFFER)
	buffer.add_theme_constant_override("margin_bottom", HINT_BUFFER)
	buffer.add_child(_hint)
	_contents.add_child(buffer)
	_face_holder = Control.new()
	_face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contents.add_child(_face_holder)
	_original_button = Button.new()
	_original_button.text = "View Original"
	_original_button.toggle_mode = true
	_original_button.focus_mode = Control.FOCUS_NONE
	_original_button.custom_minimum_size = Vector2(150, 34)
	_original_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_original_button.add_theme_font_size_override("font_size", 15 + UiText.RAISE)
	_original_button.toggled.connect(func(_is_on: bool) -> void: _draw_face())
	_contents.add_child(_original_button)
	_state_title = _label("Right now", 15, MUTED)
	_contents.add_child(_state_title)
	_state_scroll = _scroll()
	_contents.add_child(_state_scroll)
	_state_list = _list(_state_scroll)
	_reminder_title = _label("Reminders", 15, MUTED)
	_contents.add_child(_reminder_title)
	_reminder_scroll = _scroll()
	_contents.add_child(_reminder_scroll)
	_reminder_list = _list(_reminder_scroll)
	resized.connect(_on_resized)


## The glow of a card of [param rarity].
static func glow_of(rarity: MmCardDefinition.Rarity) -> Color:
	return GLOWS[rarity]


## Shows the card [param key], a Game Object ID: its [param look] now, its [param original]
## (null if it has none), the color its face glows in (null for none) and its State List.
## View Original stays as it is while the same card is shown
## and is let up for another. Another card takes [param seconds] to change to, the one
## showing easing out and then the new one in; the same card, changed, is redrawn at once.
func show_card(key: int, look: CardLook, original: CardLook, glow: Variant, states: Array[StateEntry],
		seconds: float = 0.0) -> void:
	var shown: Array = [key, look, original, glow, states]
	var is_easing_out: bool = not _waiting.is_empty()
	if is_easing_out or (key != _key and _key != NO_CARD and seconds > 0.0 and is_visible_in_tree() and modulate.a > 0.0):
		_waiting = shown
		if is_easing_out:
			return
		if _swap != null:
			_swap.kill()
		_swap = create_tween().set_trans(Easing.TRANSITION)
		_swap.tween_property(_contents, "modulate:a", 0.0, seconds / 2.0 * _contents.modulate.a).set_ease(Tween.EASE_IN)
		_swap.tween_callback(_show_waiting)
		_swap.tween_property(_contents, "modulate:a", 1.0, seconds / 2.0).set_ease(Tween.EASE_OUT)
		return
	if key != _key:
		# Nothing to ease out of: the Inspector itself is easing in.
		if _swap != null:
			_swap.kill()
		_contents.modulate.a = 1.0
	_apply(shown)


## The Game Object ID of the card shown, or NO_CARD.
func shown_key() -> int:
	return _key


## The look the face is drawn from: the card as it is now, or its Original.
func shown_look() -> CardLook:
	return _original if _is_showing_original() else _look


## The Card Face, or null before any card is shown and while an Emblem or a Potion is.
func face() -> CardFace:
	return _face


## The Emblem Face, or null unless an Emblem is shown.
func emblem_face() -> EmblemFace:
	return _emblem_face


## The Potion Readout, or null unless a Potion is shown.
func potion_readout() -> PotionReadout:
	return _potion_readout


func original_button() -> Button:
	return _original_button


## The line at the top that says how the Inspector is closed.
func hint() -> Label:
	return _hint


func state_scroll() -> ScrollContainer:
	return _state_scroll


func reminder_scroll() -> ScrollContainer:
	return _reminder_scroll


## The title over the Reminders.
func reminder_title() -> Label:
	return _reminder_title


## Everything that fades when one card gives way to another.
func contents() -> Control:
	return _contents


## The State List as drawn: [title, sentence] for each entry.
func state_texts() -> Array:
	var texts: Array = []
	for entry: StateEntry in _states:
		texts.append([entry.title, entry.text])
	return texts


## The keyword of each Reminder drawn, in order.
func reminder_keywords() -> Array[String]:
	var keywords: Array[String] = []
	if _look != null:
		for reminder: Reminder in Reminders.of(shown_look().abilities):
			keywords.append(reminder.keyword)
	return keywords


func reminder_icons() -> Array[TextureRect]:
	return _reminder_icons


func _process(_delta: float) -> void:
	# A section is as tall as what is in it, up to its cap; past that it scrolls.
	_state_scroll.custom_minimum_size.y = minf(_state_list.get_combined_minimum_size().y, STATE_CAP)
	_reminder_scroll.custom_minimum_size.y = minf(_reminder_list.get_combined_minimum_size().y, REMINDER_CAP)


func _on_resized() -> void:
	if _look != null:
		_draw_face()


func _is_showing_original() -> bool:
	return _original_button.button_pressed and _original != null


func _show_waiting() -> void:
	var next: Array = _waiting
	_waiting = []
	_apply(next)


func _apply(shown: Array) -> void:
	var key: int = shown[0]
	if key != _key:
		_original_button.set_pressed_no_signal(false)
	_key = key
	_look = shown[1] as CardLook
	_original = shown[2] as CardLook
	_glow = shown[3]
	_states.assign(shown[4] as Array)
	_original_button.disabled = _original == null
	_original_button.tooltip_text = "" if _original != null else "An Emblem or a token has no original."
	_fill_states()
	_draw_face()


## Draws the face of the version shown, and the Reminders for that version's keywords.
func _draw_face() -> void:
	for child: Node in _face_holder.get_children():
		_face_holder.remove_child(child)
		child.queue_free()
	_face = null
	_emblem_face = null
	_potion_readout = null
	var width: float = size.x - 2.0 * PAD
	var height: float = width / CardGeometry.ASPECT
	var kind: CardLook.Kind = shown_look().kind
	# An Emblem and a Potion have no Original, State List or Reminders (ADR 0033).
	_original_button.visible = kind == CardLook.Kind.CARD
	match kind:
		CardLook.Kind.EMBLEM:
			_emblem_face = EmblemFace.new()
			_emblem_face.setup(shown_look(), width / (EmblemFace.DESIGN.x / EmblemFace.DESIGN.y))
			_face_holder.custom_minimum_size = _emblem_face.size
			_face_holder.add_child(_emblem_face)
		CardLook.Kind.POTION:
			_potion_readout = PotionReadout.new()
			_potion_readout.setup(shown_look(), width, _glow)
			_face_holder.custom_minimum_size = _potion_readout.size
			_face_holder.add_child(_potion_readout)
		_:
			_face_holder.custom_minimum_size = Vector2(width, height)
			_face = CardFace.new()
			_face.setup(shown_look(), height)
			_face_holder.add_child(_face)
			if _glow != null:
				BorderEffects.add_glow(_face, _face.size, _glow as Color)
	_fill_reminders()


func _fill_states() -> void:
	_clear(_state_list)
	for entry: StateEntry in _states:
		_state_list.add_child(_words(entry.title, entry.text))
	_state_title.visible = not _states.is_empty()
	_state_scroll.visible = not _states.is_empty()


func _fill_reminders() -> void:
	_clear(_reminder_list)
	_reminder_icons.clear()
	var reminders: Array[Reminder] = Reminders.of(shown_look().abilities) if shown_look().kind == CardLook.Kind.CARD \
		else ([] as Array[Reminder])
	for reminder: Reminder in reminders:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon: TextureRect = TextureRect.new()
		icon.texture = load("%s%s.png" % [KeywordChips.ICON_FOLDER, reminder.icon]) as Texture2D
		# Pixel art: nearest, at twice its size.
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		_reminder_icons.append(icon)
		row.add_child(_words(reminder.keyword, reminder.text))
		_reminder_list.add_child(row)
	_reminder_title.visible = not reminders.is_empty()
	_reminder_scroll.visible = not reminders.is_empty()


## A title over a sentence that wraps.
static func _words(title: String, sentence: String) -> VBoxContainer:
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_label(title, 15, Color.WHITE))
	var body: Label = Label.new()
	# Wrapping is set before the text (conventions).
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = sentence
	body.add_theme_font_size_override("font_size", 13 + UiText.RAISE)
	body.add_theme_color_override("font_color", MUTED)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(body)
	return words


static func _clear(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


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
	label.add_theme_font_size_override("font_size", font_size + UiText.RAISE)
	label.add_theme_color_override("font_color", color)
	return label
