class_name DeckbuilderInspector
extends VBoxContainer
## The deckbuilder's inspector (step 8, A552 to A555; milestone 16, ADR 0033): the card's
## face, the View Original and Reminders buttons side by side, and two panels under them
## that are always drawn, built from the same InspectorParts as the encounter's Inspector.
## Card Text has the card's rules text as its face prints it, without reminder text. Mods
## has the three Mod Slots as bubbles in a shaded gray tray twice as tall as a bubble and a
## subpanel for each Mod or Hex on the card. Apply a Mod is under both, at the bottom.
##
## While Reminders is pressed, one Reminders panel stands in place of both, with an entry
## for each keyword. View Original changes only the face: Card Text, Reminders and Mods are
## the card as it is (A582). Another card, or none, lets both buttons up and scrolls the
## panels to their tops (A583). A panel with nothing to say says None, centered and in
## italics (A577).
##
## The panels showing are equally tall: together they fill the height between the two
## buttons at the top and Apply a Mod at the bottom, half each for Card Text and Mods. What
## does not fit in one scrolls inside it.
##
## It draws what it is handed and changes nothing: it reports [signal apply_pressed].

signal apply_pressed


## One Mod Slot in the tray, drawn as the bubbles on a card's face are: a rimmed hollow lit
## from the upper left, with a green or red chip in it.
class Bubble:
	extends Control
	var slot: ModSlotRow.Slot = ModSlotRow.Slot.EMPTY

	func _draw() -> void:
		ModSlotRow.draw_bubble(self, size / 2.0, minf(size.x, size.y) / 2.0, slot)

const HINT: String = "Hover over any card to view it here.\nRight-click any card to select it."
const NONE: String = InspectorParts.NONE
const TITLE_SIZE: int = 18
const BODY_SIZE: int = 17
const BUTTON_SIZE: int = 17
const HINT_SIZE: int = 18
const BUBBLE_SIZE: float = 22.0
const GAP: int = 8

var _card: DeckbuilderCard = null
var _face_height: float = 0.0
var _hint: Label = null
var _body: VBoxContainer = null
var _face_holder: Control = null
var _face: CardFace = null
var _original_button: Button = null
var _reminders_button: Button = null
var _button_row: HBoxContainer = null
var _text_panel: PanelContainer = null
var _mod_panel: PanelContainer = null
var _reminder_panel: PanelContainer = null
var _text: SymbolLabel = null
var _text_none: Label = null
var _reminder_list: VBoxContainer = null
var _reminder_none: Label = null
var _reminder_keywords: Array[String] = []
var _bubble_row: HBoxContainer = null
var _bubble_tray: PanelContainer = null
var _panels: Array[PanelContainer] = []
var _scrolls: Array[ScrollContainer] = []
var _bubbles: Array[Bubble] = []
var _mod_scroll: ScrollContainer = null
var _mod_list: VBoxContainer = null
var _mod_none: Label = null
var _mod_names: Array[String] = []
var _mod_labels: Array[SymbolLabel] = []
var _apply_button: Button = null
## While one card is easing out for another: what to show once it has gone, and the fade.
var _is_easing_out: bool = false
var _waiting_card: DeckbuilderCard = null
var _waiting_height: float = 0.0
var _swap: Tween = null


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = InspectorParts.label(HINT, HINT_SIZE, DeckbuilderLook.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", GAP)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.visible = false
	add_child(_body)
	_face_holder = Control.new()
	_face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# As wide as the face and centered, so the face sits in the middle of the inspector.
	_face_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(_face_holder)
	_original_button = InspectorParts.toggle("View Original", BUTTON_SIZE, DeckbuilderLook.inspector_palette())
	_original_button.toggled.connect(func(_is_on: bool) -> void: _draw_face())
	_reminders_button = InspectorParts.toggle("Reminders", BUTTON_SIZE, DeckbuilderLook.inspector_palette())
	_reminders_button.tooltip_text = "Show what this card's keywords mean."
	_reminders_button.toggled.connect(func(_is_on: bool) -> void: _show_panels())
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", GAP)
	_button_row.add_child(_original_button)
	_button_row.add_child(_reminders_button)
	_body.add_child(_button_row)

	_text_panel = _panel("Card Text")
	var text_scroll: ScrollContainer = _scroll_in(_text_panel)
	_text = InspectorParts.symbol_label(DeckbuilderLook.inspector_palette(), BODY_SIZE)
	text_scroll.add_child(_text)
	_text_none = _none_in(_text_panel)

	_mod_panel = _panel("Mods")
	var mod_body: VBoxContainer = InspectorParts.body_of(_mod_panel)
	_bubble_tray = PanelContainer.new()
	var tray: StyleBoxFlat = StyleBoxFlat.new()
	tray.bg_color = DeckbuilderLook.BUBBLE_TRAY
	tray.border_color = DeckbuilderLook.BUBBLE_TRAY_BORDER
	# Both ends are rounded off in full: half the tray's height.
	tray.set_corner_radius_all(roundi(BUBBLE_SIZE))
	DeckbuilderLook.shade(tray, 3)
	_bubble_tray.add_theme_stylebox_override("panel", tray)
	_bubble_tray.custom_minimum_size = Vector2(0, 2.0 * BUBBLE_SIZE)
	_bubble_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mod_body.add_child(_bubble_tray)
	_bubble_row = HBoxContainer.new()
	_bubble_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_tray.add_child(_bubble_row)
	for slot: int in DeckbuilderCard.MOD_SLOTS:
		var seat: CenterContainer = CenterContainer.new()
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bubble: Bubble = Bubble.new()
		bubble.custom_minimum_size = Vector2(BUBBLE_SIZE, BUBBLE_SIZE)
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seat.add_child(bubble)
		_bubble_row.add_child(seat)
		_bubbles.append(bubble)
	_mod_scroll = _scroll_in(_mod_panel)
	_mod_list = InspectorParts.list(_mod_scroll)
	_mod_none = _none_in(_mod_panel)
	_apply_button = Button.new()
	_apply_button.text = "Apply a Mod"
	_apply_button.focus_mode = Control.FOCUS_NONE
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.add_theme_font_size_override("font_size", HINT_SIZE)
	InspectorParts.shade_button(_apply_button, DeckbuilderLook.inspector_palette())
	_apply_button.pressed.connect(func() -> void: apply_pressed.emit())

	_reminder_panel = _panel("Reminders")
	_reminder_list = InspectorParts.list(_scroll_in(_reminder_panel))
	_reminder_none = _none_in(_reminder_panel)
	_body.add_child(_apply_button)
	_show_panels()


## Shows [param card] with its face [param face_height] tall, or the hint if it is null.
## Both buttons are let up for another card and stay as they are for the same one.
##
## Another card takes [param seconds] to change to, as in the encounter's Inspector: what
## is showing eases out and then the new card eases in. The same card, changed, is redrawn
## at once, and so is everything given no time.
func show_card(card: DeckbuilderCard, face_height: float, seconds: float = 0.0) -> void:
	if _is_easing_out or (card != _card and seconds > 0.0 and is_visible_in_tree()):
		_waiting_card = card
		_waiting_height = face_height
		if _is_easing_out:
			return
		_is_easing_out = true
		if _swap != null:
			_swap.kill()
		_swap = create_tween().set_trans(Easing.TRANSITION)
		_swap.tween_property(self, "modulate:a", 0.0, seconds / 2.0 * modulate.a).set_ease(Tween.EASE_IN)
		_swap.tween_callback(_show_waiting)
		_swap.tween_property(self, "modulate:a", 1.0, seconds / 2.0).set_ease(Tween.EASE_OUT)
		return
	_apply(card, face_height)


## Whether one card is easing out for another.
func is_changing() -> bool:
	return _is_easing_out


func _show_waiting() -> void:
	_is_easing_out = false
	_apply(_waiting_card, _waiting_height)
	_waiting_card = null


func _apply(card: DeckbuilderCard, face_height: float) -> void:
	if card != _card:
		_original_button.set_pressed_no_signal(false)
		_reminders_button.set_pressed_no_signal(false)
		_show_panels()
		for scroll: ScrollContainer in _scrolls:
			scroll.scroll_vertical = 0
	_card = card
	_face_height = face_height
	_hint.visible = card == null
	_body.visible = card != null
	if card == null:
		_clear_face()
		return
	_original_button.disabled = not card.is_modified()
	_original_button.tooltip_text = "" if card.is_modified() else "This card has no Mods or Hexes."
	_draw_face()
	_fill_text(DeckbuilderLooks.look_of(card).printed_rules_text())
	_fill_reminders(Reminders.of(DeckbuilderLooks.look_of(card).abilities))
	_fill_mods()


## Whether Apply a Mod can be pressed, and if not, [param why_not] as its tooltip.
func set_apply(why_not: String) -> void:
	_apply_button.disabled = why_not != ""
	_apply_button.tooltip_text = why_not


func shown_card() -> DeckbuilderCard:
	return _card


## The look the face is drawn from: the card as it is, or its Original.
func shown_look() -> CardLook:
	if _card == null:
		return null
	return DeckbuilderLooks.original_of(_card) if is_showing_original() else DeckbuilderLooks.look_of(_card)


func is_showing_original() -> bool:
	return _card != null and _card.is_modified() and _original_button.button_pressed


## The Card Face, or null while no card is shown.
func face() -> CardFace:
	return _face


func original_button() -> Button:
	return _original_button


## The button that swaps the two panels for the Reminders panel.
func reminders_button() -> Button:
	return _reminders_button


func apply_button() -> Button:
	return _apply_button


## The Card Text as written, symbols in braces, or NONE.
func card_text() -> String:
	return NONE if _text_none.visible else _text.written()


## The label the Card Text is drawn by, each of its symbols as an image.
func card_text_label() -> SymbolLabel:
	return _text


## The keyword of each Reminder drawn, in order.
func reminder_keywords() -> Array[String]:
	return _reminder_keywords


## The name of each Mod and Hex listed, in slot order.
func mod_names() -> Array[String]:
	return _mod_names


## The label that draws what each Mod and Hex listed says it does, in slot order. One that
## says nothing has none.
func mod_labels() -> Array[SymbolLabel]:
	return _mod_labels


## The panels showing now, top to bottom: Card Text and Mods, or Reminders alone.
func panels() -> Array[PanelContainer]:
	return _panels.filter(func(panel: PanelContainer) -> bool: return panel.visible)


## The gray tray the bubbles sit in.
func bubble_tray() -> PanelContainer:
	return _bubble_tray


## The titles of the panels showing now, top to bottom.
func panel_titles() -> Array[String]:
	var titles: Array[String] = []
	for panel: PanelContainer in panels():
		titles.append(InspectorParts.title_of(panel).text)
	return titles


func _process(_delta: float) -> void:
	# The panels showing share what is between the top buttons and Apply a Mod, in equal parts.
	var showing: Array[PanelContainer] = panels()
	var room: float = _body.size.y - _face_holder.custom_minimum_size.y - _button_row.size.y - _apply_button.size.y \
			- GAP * (showing.size() + 2)
	var each: float = floorf(maxf(room, 0.0) / showing.size())
	for panel: PanelContainer in showing:
		panel.custom_minimum_size.y = each
	# Every title stands as far above its body as it does when Card Text and Mods share the room (A585).
	var two_up: float = (_body.size.y - _face_holder.custom_minimum_size.y - _button_row.size.y - _apply_button.size.y \
			- GAP * 4) / 2.0
	for panel: PanelContainer in _panels:
		InspectorParts.set_title_gap(panel, InspectorParts.title_gap(floorf(two_up)))


## Shows Card Text and Mods, or the Reminders panel in their place while its button is pressed.
func _show_panels() -> void:
	for panel: PanelContainer in _panels:
		panel.visible = (panel == _reminder_panel) == _reminders_button.button_pressed


## Draws the face of the version shown.
func _draw_face() -> void:
	_clear_face()
	if _card == null:
		return
	_face = CardFace.new()
	_face.setup(shown_look(), _face_height)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_holder.custom_minimum_size = _face.size
	_face_holder.add_child(_face)
	# It glows in its Rarity's color, as in the encounter's Inspector; a Mod changes no Rarity.
	BorderEffects.add_glow(_face, _face.size, Inspector.glow_of(_card.run_card.base.rarity))


func _clear_face() -> void:
	if _face != null:
		_face_holder.remove_child(_face)
		_face.queue_free()
		_face = null


## Writes [param text] with its {X} symbols drawn from the mana symbol images, or None.
func _fill_text(text: String) -> void:
	var lines: Array[String] = []
	if text != "":
		lines.assign(Array(text.split("\n")))
	_text.write_lines(lines, [], DeckbuilderLook.MUTED, InspectorParts.PARAGRAPH_BREAK)
	_text.get_parent().visible = text != ""
	_text_none.visible = text == ""


func _fill_reminders(reminders: Array[Reminder]) -> void:
	InspectorParts.clear(_reminder_list)
	_reminder_keywords.clear()
	for reminder: Reminder in reminders:
		_reminder_list.add_child(InspectorParts.reminder_row(reminder, DeckbuilderLook.inspector_palette(), BODY_SIZE))
		_reminder_keywords.append(reminder.keyword)
	_reminder_list.get_parent().visible = not reminders.is_empty()
	_reminder_none.visible = reminders.is_empty()


## The bubbles and a subpanel for each Mod and Hex on the card, in slot order, or None.
func _fill_mods() -> void:
	var slots: Array[ModSlotRow.Slot] = ModSlotRow.slots_of(_card)
	for slot: int in _bubbles.size():
		_bubbles[slot].slot = slots[slot]
		_bubbles[slot].queue_redraw()
	InspectorParts.clear(_mod_list)
	_mod_names.clear()
	_mod_labels.clear()
	for mod: Mod in _card.mods:
		var tint: Color = ModSlotRow.color_of(ModSlotRow.Slot.HEX if mod.is_hex else ModSlotRow.Slot.MOD)
		var plate: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = DeckbuilderLook.INSPECTOR_PANEL.lerp(tint, 0.18)
		style.border_color = tint
		style.set_border_width_all(1)
		style.border_width_left = 5
		style.set_corner_radius_all(5)
		style.set_content_margin_all(6)
		style.content_margin_left = 10
		plate.add_theme_stylebox_override("panel", style)
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title: String = mod.name if mod.name != "" else "Unnamed"
		var words: VBoxContainer = InspectorParts.words("%s (Hex)" % title if mod.is_hex else title, mod.description,
			DeckbuilderLook.inspector_palette(), BODY_SIZE)
		plate.add_child(words)
		if mod.description != "":
			_mod_labels.append(words.get_child(1) as SymbolLabel)
		_mod_list.add_child(plate)
		_mod_names.append(mod.name)
	_mod_scroll.visible = not _card.mods.is_empty()
	_mod_none.visible = _card.mods.is_empty()


## A panel with [param title] centered at its top, added to the body.
func _panel(title: String) -> PanelContainer:
	var panel: PanelContainer = InspectorParts.panel(title, DeckbuilderLook.inspector_palette(), TITLE_SIZE)
	_body.add_child(panel)
	_panels.append(panel)
	return panel


func _scroll_in(panel: PanelContainer) -> ScrollContainer:
	var scroll: ScrollContainer = InspectorParts.scroll(InspectorParts.body_of(panel))
	_scrolls.append(scroll)
	return scroll


func _none_in(panel: PanelContainer) -> Label:
	var none: Label = InspectorParts.none_label(DeckbuilderLook.inspector_palette(), BODY_SIZE)
	none.visible = false
	InspectorParts.body_of(panel).add_child(none)
	return none
