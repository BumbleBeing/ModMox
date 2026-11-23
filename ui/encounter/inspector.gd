class_name Inspector
extends Panel
## The Inspector (13h and milestone 16, ADR 0033): where a card is read in full during an
## encounter. It lies over the sidebar while a card is pinned and is laid out as the
## deckbuilder's is, from the same InspectorParts: the card's Card Face with its Rarity's
## glow; View Original and Reminders side by side under it; and two bordered, titled panels
## that are always drawn and share the rest of the height evenly, Card Text and State
## Information. While Reminders is pressed one Reminders panel stands in place of both. An
## Emblem and a Potion have their own face, a Reminders button the width of the row and one
## Card Text panel. It draws what it is handed and asks for nothing: the Encounter Screen
## says which card, from its Inspection.
##
## View Original changes only the face: Card Text, State Information and Reminders are the
## pinned thing as it is now (A574). Another card, or the same one pinned again after it was
## let go, lets both buttons up and scrolls every panel to its top; a new snapshot of the
## same card changes none of that (A575).
##
## Built once and filled, never rebuilt: a change of card eases the old one out and the new
## one in, and the same card changed, by a new snapshot or by View Original, is redrawn at
## once.

const PAD: float = 16.0
## What the top of the Inspector says.
const HINT: String = "[Click off to close]"
## The room above and below it: two units (A576).
const HINT_BUFFER: int = 8
## The room between the face, the buttons and the panels.
const GAP: int = 8
const TITLE_SIZE: int = 18
const BODY_SIZE: int = 17
const BUTTON_SIZE: int = 17
const BACKGROUND: Color = Color("#22262e")
const MUTED: Color = Color("#9aa3af")
## The Inspector's colors: a slate that sits with the sidebar (A566).
static var _palette: InspectorParts.Palette = null
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

## What each Rarity is called, as on a Potion's entry in its window and its type line.
const RARITY_NAMES: Dictionary[MmCardDefinition.Rarity, String] = {
	MmCardDefinition.Rarity.COMMON: "Common", MmCardDefinition.Rarity.UNCOMMON: "Uncommon",
	MmCardDefinition.Rarity.RARE: "Rare", MmCardDefinition.Rarity.MYTHIC: "Mythic",
	MmCardDefinition.Rarity.POWER_NINE: "Power-9",
}

var _contents: VBoxContainer
var _hint: Label
var _hint_buffer: MarginContainer
var _face_holder: Control
var _face: CardFace = null
## What stands in the face's place for an Emblem or a Potion (ADR 0033).
var _emblem_face: EmblemFace = null
var _potion_readout: PotionReadout = null
var _button_row: HBoxContainer
var _original_button: Button
var _reminders_button: Button
var _text_panel: PanelContainer
var _text: SymbolLabel
var _text_none: Label
var _state_panel: PanelContainer
var _state_list: VBoxContainer
var _state_none: Label
var _reminder_panel: PanelContainer
var _reminder_list: VBoxContainer
var _reminder_none: Label
var _reminder_icons: Array[TextureRect] = []
var _scrolls: Array[ScrollContainer] = []
var _key: int = NO_CARD
var _look: CardLook = null
var _original: CardLook = null
var _rarity: Variant = null
var _states: Array[StateEntry] = []
## While one card is easing out for another: what to show once it has gone, and the fade.
var _waiting: Array = []
var _swap: Tween = null


func _init() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	add_theme_stylebox_override("panel", style)
	theme = InspectorParts.theme(palette(), BODY_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_contents = VBoxContainer.new()
	_contents.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contents.offset_left = PAD
	_contents.offset_top = 0.0
	_contents.offset_right = -PAD
	_contents.offset_bottom = -PAD
	_contents.add_theme_constant_override("separation", GAP)
	add_child(_contents)
	InspectorParts.shade_background(self, _contents, BACKGROUND, BACKGROUND, 0, 0)
	# In place of a close button: any click off the Inspector lets the card go (A473).
	_hint = Label.new()
	_hint.text = HINT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 10 + UiText.RAISE)
	_hint.add_theme_font_override("font", InspectorParts.italic())
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_buffer = MarginContainer.new()
	_hint_buffer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_buffer.add_theme_constant_override("margin_top", HINT_BUFFER)
	_hint_buffer.add_theme_constant_override("margin_bottom", HINT_BUFFER)
	_hint_buffer.add_child(_hint)
	_contents.add_child(_hint_buffer)
	_face_holder = Control.new()
	_face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contents.add_child(_face_holder)

	_original_button = InspectorParts.toggle("View Original", BUTTON_SIZE, palette())
	_original_button.toggled.connect(func(_is_on: bool) -> void: _draw_face())
	_reminders_button = InspectorParts.toggle("Reminders", BUTTON_SIZE, palette())
	_reminders_button.tooltip_text = "Show what its keywords mean."
	_reminders_button.toggled.connect(func(_is_on: bool) -> void: _show_panels())
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", GAP)
	_button_row.add_child(_original_button)
	_button_row.add_child(_reminders_button)
	_contents.add_child(_button_row)

	_text_panel = _panel("Card Text")
	var text_scroll: ScrollContainer = _scroll_in(_text_panel)
	_text = InspectorParts.symbol_label(palette(), BODY_SIZE)
	text_scroll.add_child(_text)
	_text_none = _none_in(_text_panel)
	_state_panel = _panel("State Information", false)
	_state_list = InspectorParts.list(_scroll_in(_state_panel))
	_state_none = _none_in(_state_panel)
	_reminder_panel = _panel("Reminders")
	_reminder_list = InspectorParts.list(_scroll_in(_reminder_panel))
	_reminder_none = _none_in(_reminder_panel)
	_show_panels()
	resized.connect(_on_resized)


## The colors the Inspector is drawn in.
static func palette() -> InspectorParts.Palette:
	if _palette == null:
		_palette = InspectorParts.Palette.new(Color("#2b3039"), Color("#575a60"), Color("#e9e9e9"), MUTED)
	return _palette


## The glow of a card of [param rarity].
static func glow_of(rarity: MmCardDefinition.Rarity) -> Color:
	return GLOWS[rarity]


## Shows the card [param key], a Game Object ID: its [param look] now, its [param original]
## (null if it has none), its [param rarity] (a Rarity, or null for none) and its State
## Information. Another card takes [param seconds] to change to, the one showing easing out
## and then the new one in; the same card, changed, is redrawn at once.
func show_card(key: int, look: CardLook, original: CardLook, rarity: Variant, states: Array[StateEntry],
		seconds: float = 0.0) -> void:
	var shown: Array = [key, look, original, rarity, states]
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


## Forgets the card shown, as it is let go, so that pinning it again starts afresh (A575).
## What is drawn stays while the Inspector eases out.
func let_go() -> void:
	_key = NO_CARD


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


## The button that swaps the other panels for the Reminders panel.
func reminders_button() -> Button:
	return _reminders_button


## The line at the top that says how the Inspector is closed.
func hint() -> Label:
	return _hint


## Everything that fades when one card gives way to another.
func contents() -> Control:
	return _contents


## The panels showing now, top to bottom.
func panels() -> Array[PanelContainer]:
	var showing: Array[PanelContainer] = []
	for made: PanelContainer in [_text_panel, _state_panel, _reminder_panel]:
		if made.visible:
			showing.append(made)
	return showing


## The titles of the panels showing now, top to bottom.
func panel_titles() -> Array[String]:
	var titles: Array[String] = []
	for made: PanelContainer in panels():
		titles.append(InspectorParts.title_of(made).text)
	return titles


## The Card Text as written, symbols in braces, or None.
func card_text() -> String:
	return InspectorParts.NONE if _text_none.visible else _text.written()


## The label the Card Text is drawn by.
func card_text_label() -> SymbolLabel:
	return _text


## The State Information as drawn: [title, sentence] for each entry.
func state_texts() -> Array:
	var texts: Array = []
	for entry: StateEntry in _states:
		texts.append([entry.title, entry.text])
	return texts


## The plate each entry of the State Information is drawn on, in order.
func state_plates() -> Array[PanelContainer]:
	var plates: Array[PanelContainer] = []
	plates.assign(_state_list.get_children())
	return plates


## The keyword of each Reminder drawn, in order.
func reminder_keywords() -> Array[String]:
	var keywords: Array[String] = []
	if _look != null:
		for reminder: Reminder in Reminders.of(_look.abilities):
			keywords.append(reminder.keyword)
	return keywords


func reminder_icons() -> Array[TextureRect]:
	return _reminder_icons


func _process(_delta: float) -> void:
	# Every title stands the same way above its body: a twentieth of a card's panel when two
	# share the room under a card's face, whatever is shown (A585).
	var width: float = size.x - 2.0 * PAD
	var card_face: float = width / CardGeometry.ASPECT
	var room: float = _contents.size.y - _hint_buffer.size.y - card_face - _button_row.size.y - 4.0 * GAP
	var gap: int = InspectorParts.title_gap(room / 2.0)
	for made: PanelContainer in [_text_panel, _state_panel, _reminder_panel]:
		InspectorParts.set_title_gap(made, gap)


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
		_reminders_button.set_pressed_no_signal(false)
		for scroll: ScrollContainer in _scrolls:
			scroll.scroll_vertical = 0
	_key = key
	_look = shown[1] as CardLook
	_original = shown[2] as CardLook
	_rarity = shown[3]
	_states.assign(shown[4] as Array)
	_original_button.disabled = _original == null
	_original_button.tooltip_text = "" if _original != null else "A token has no original."
	# An Emblem and a Potion have no Original and no State Information (ADR 0033).
	_original_button.visible = _look.kind == CardLook.Kind.CARD
	_fill_text()
	_fill_states()
	_fill_reminders()
	_show_panels()
	_draw_face()


## Shows Card Text and State Information, or the Reminders panel in their place while its
## button is pressed. An Emblem or a Potion has no State Information.
func _show_panels() -> void:
	var is_card: bool = _look == null or _look.kind == CardLook.Kind.CARD
	var is_reminding: bool = _reminders_button.button_pressed
	_text_panel.visible = not is_reminding
	_state_panel.visible = not is_reminding and is_card
	_reminder_panel.visible = is_reminding


## Draws the face of the version shown.
func _draw_face() -> void:
	InspectorParts.clear(_face_holder)
	_face = null
	_emblem_face = null
	_potion_readout = null
	var width: float = size.x - 2.0 * PAD
	var height: float = width / CardGeometry.ASPECT
	match shown_look().kind:
		CardLook.Kind.EMBLEM:
			_emblem_face = EmblemFace.new()
			_emblem_face.setup(shown_look(), width / (EmblemFace.DESIGN.x / EmblemFace.DESIGN.y))
			_face_holder.custom_minimum_size = _emblem_face.size
			_face_holder.add_child(_emblem_face)
		CardLook.Kind.POTION:
			_potion_readout = PotionReadout.new()
			_potion_readout.setup(shown_look(), width, _rarity)
			_face_holder.custom_minimum_size = _potion_readout.size
			_face_holder.add_child(_potion_readout)
		_:
			_face_holder.custom_minimum_size = Vector2(width, height)
			_face = CardFace.new()
			_face.setup(shown_look(), height)
			_face_holder.add_child(_face)
			if _rarity != null:
				BorderEffects.add_glow(_face, _face.size, glow_of(_rarity as MmCardDefinition.Rarity))


## The rules text of the pinned thing as it is now: a card's as its face prints it, and an
## Emblem's or a Potion's one ability to a line, a spent one gray and marked "(used)".
func _fill_text() -> void:
	var lines: Array[String] = []
	var spent: Array[int] = []
	if _look.kind == CardLook.Kind.CARD:
		var printed: String = _look.printed_rules_text()
		if printed != "":
			lines.assign(Array(printed.split("\n")))
		# Game ADR 0079: an Adventure's name and cost, type line and rules under its creature's.
		lines.append_array(_look.adventure_text_lines())
	else:
		for index: int in _look.rules_lines.size():
			if _look.is_ability_spent(index):
				lines.append(_look.rules_lines[index] + EmblemFace.USED_SUFFIX)
				spent.append(index)
			else:
				lines.append(_look.rules_lines[index])
	_text.write_lines(lines, spent, palette().muted, InspectorParts.PARAGRAPH_BREAK)
	_show_none(_text_panel, _text_none, lines.is_empty())


func _fill_states() -> void:
	InspectorParts.clear(_state_list)
	for entry: StateEntry in _states:
		_state_list.add_child(InspectorParts.entry_plate(entry.title, entry.text, palette(), BODY_SIZE))
	_show_none(_state_panel, _state_none, _states.is_empty())


func _fill_reminders() -> void:
	InspectorParts.clear(_reminder_list)
	_reminder_icons.clear()
	var reminders: Array[Reminder] = Reminders.of(_look.abilities)
	for reminder: Reminder in reminders:
		var row: HBoxContainer = InspectorParts.reminder_row(reminder, palette(), BODY_SIZE)
		_reminder_icons.append(row.get_child(0) as TextureRect)
		_reminder_list.add_child(row)
	_show_none(_reminder_panel, _reminder_none, reminders.is_empty())


## Shows [param none] in [param made] in place of its scroll when [param is_empty].
func _show_none(made: PanelContainer, none: Label, is_empty: bool) -> void:
	none.visible = is_empty
	InspectorParts.body_of(made).get_child(0).visible = not is_empty


## A panel titled [param title], on a backing unless [param is_backed] is false.
func _panel(title: String, is_backed: bool = true) -> PanelContainer:
	var made: PanelContainer = InspectorParts.panel(title, palette(), TITLE_SIZE, is_backed)
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contents.add_child(made)
	return made


func _scroll_in(made: PanelContainer) -> ScrollContainer:
	var scroll: ScrollContainer = InspectorParts.scroll(InspectorParts.body_of(made))
	_scrolls.append(scroll)
	return scroll


func _none_in(made: PanelContainer) -> Label:
	var none: Label = InspectorParts.none_label(palette(), BODY_SIZE)
	none.visible = false
	InspectorParts.body_of(made).add_child(none)
	return none
