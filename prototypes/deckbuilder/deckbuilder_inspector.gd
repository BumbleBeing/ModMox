class_name DeckbuilderInspector
extends VBoxContainer
## The deckbuilder's inspector (step 8, A552 to A555): the card's face, the View Original
## and Reminders buttons side by side, and two panels under them that are always drawn.
## Card Text has the card's rules text as its face prints it, without reminder text. Mods
## has the three Mod Slots as bubbles in a shaded gray tray twice as tall as a bubble and a
## subpanel for each Mod or Hex on the card, and nothing under the tray when there are none. Apply a Mod is under both, at the bottom.
##
## While Reminders is pressed, one Reminders panel stands in place of both, with an entry
## for each keyword, as the encounter's Inspector has (ADR 0033). It stays pressed from
## card to card until it is let up.
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
const NONE: String = "None"
const TITLE_SIZE: int = 18
const BODY_SIZE: int = 16
const SYMBOL_SIZE: int = 16
const BUBBLE_SIZE: float = 22.0

var _card: DeckbuilderCard = null
var _face_height: float = 0.0
var _hint: Label = null
var _body: VBoxContainer = null
var _face_holder: Control = null
var _face: CardFace = null
var _original_button: Button = null
var _reminders_button: Button = null
var _button_row: HBoxContainer = null
var _reminder_panel: PanelContainer = null
var _text_scroll: ScrollContainer = null
var _text: RichTextLabel = null
var _shown_text: String = ""
var _reminder_scroll: ScrollContainer = null
var _reminder_list: VBoxContainer = null
var _reminder_keywords: Array[String] = []
var _bubble_row: HBoxContainer = null
var _bubble_tray: PanelContainer = null
var _panels: Array[PanelContainer] = []
var _bubbles: Array[Bubble] = []
var _mod_list: VBoxContainer = null
var _mod_names: Array[String] = []
var _apply_button: Button = null
## While one card is easing out for another: what to show once it has gone, and the fade.
var _is_easing_out: bool = false
var _waiting_card: DeckbuilderCard = null
var _waiting_height: float = 0.0
var _swap: Tween = null


func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = _label(HINT, BODY_SIZE + 2, DeckbuilderLook.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.visible = false
	add_child(_body)
	_face_holder = Control.new()
	_face_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_face_holder)
	_original_button = Button.new()
	_original_button.text = "View Original"
	_original_button.toggle_mode = true
	_original_button.focus_mode = Control.FOCUS_NONE
	_original_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_original_button.add_theme_font_size_override("font_size", BODY_SIZE + 1)
	_original_button.toggled.connect(func(_is_on: bool) -> void: _draw_version())
	_reminders_button = Button.new()
	_reminders_button.text = "Reminders"
	_reminders_button.tooltip_text = "Show what this card's keywords mean."
	_reminders_button.toggle_mode = true
	_reminders_button.focus_mode = Control.FOCUS_NONE
	_reminders_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reminders_button.add_theme_font_size_override("font_size", BODY_SIZE + 1)
	_reminders_button.toggled.connect(func(_is_on: bool) -> void: _show_panels())
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 8)
	_button_row.add_child(_original_button)
	_button_row.add_child(_reminders_button)
	_body.add_child(_button_row)

	var text_panel: VBoxContainer = _panel("Card Text")
	_text_scroll = _scroll(text_panel)
	_text = RichTextLabel.new()
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	_text.add_theme_color_override("default_color", DeckbuilderLook.TEXT)
	_text_scroll.add_child(_text)

	var mod_panel: VBoxContainer = _panel("Mods")
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
	mod_panel.add_child(_bubble_tray)
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
	var mod_scroll: ScrollContainer = _scroll(mod_panel)
	_mod_list = _list(mod_scroll)
	_apply_button = Button.new()
	_apply_button.text = "Apply a Mod"
	_apply_button.focus_mode = Control.FOCUS_NONE
	_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button.add_theme_font_size_override("font_size", BODY_SIZE + 2)
	_apply_button.pressed.connect(func() -> void: apply_pressed.emit())

	var reminder_panel: VBoxContainer = _panel("Reminders")
	_reminder_panel = _panels[-1]
	_reminder_scroll = _scroll(reminder_panel)
	_reminder_list = _list(_reminder_scroll)
	_body.add_child(_apply_button)
	_show_panels()


## Shows [param card] with its face [param face_height] tall, or the hint if it is null.
## View Original is let up for another card and stays as it is for the same one.
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
	_card = card
	_face_height = face_height
	_hint.visible = card == null
	_body.visible = card != null
	if card == null:
		_clear_face()
		return
	_original_button.disabled = not card.is_modified()
	_original_button.tooltip_text = "" if card.is_modified() else "This card has no Mods or Hexes."
	_draw_version()
	_fill_mods()


## Whether Apply a Mod can be pressed, and if not, [param why_not] as its tooltip.
func set_apply(why_not: String) -> void:
	_apply_button.disabled = why_not != ""
	_apply_button.tooltip_text = why_not


func shown_card() -> DeckbuilderCard:
	return _card


## The look the face and the Card Text are drawn from: the card as it is, or its Original.
func shown_look() -> CardLook:
	if _card == null:
		return null
	return _card.original_look() if is_showing_original() else _card.look()


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
	return _shown_text


## The keyword of each Reminder drawn, in order.
func reminder_keywords() -> Array[String]:
	return _reminder_keywords


## The name of each Mod and Hex listed, in slot order.
func mod_names() -> Array[String]:
	return _mod_names


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
		titles.append((panel.find_child("Title", true, false) as Label).text)
	return titles


func _process(_delta: float) -> void:
	# The panels showing share what is between the top buttons and Apply a Mod, in equal parts.
	var showing: Array[PanelContainer] = panels()
	var gap: float = _body.get_theme_constant("separation")
	var taken: float = _face_holder.custom_minimum_size.y + _button_row.size.y + _apply_button.size.y \
			+ gap * (showing.size() + 2)
	var each: float = floorf(maxf(_body.size.y - taken, 0.0) / showing.size())
	for panel: PanelContainer in showing:
		panel.custom_minimum_size.y = each


## Shows Card Text and Mods, or the Reminders panel in their place while its button is pressed.
func _show_panels() -> void:
	for panel: PanelContainer in _panels:
		panel.visible = (panel == _reminder_panel) == _reminders_button.button_pressed


## Draws the face, the Card Text and the Reminders of the version shown.
func _draw_version() -> void:
	_clear_face()
	var look: CardLook = shown_look()
	_face = CardFace.new()
	_face.setup(look, _face_height)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_holder.custom_minimum_size = _face.size
	_face_holder.add_child(_face)
	_fill_text(look.printed_rules_text())
	_fill_reminders(Reminders.of(look.abilities))


func _clear_face() -> void:
	if _face != null:
		_face_holder.remove_child(_face)
		_face.queue_free()
		_face = null


## Writes [param text] with its {X} symbols drawn from the mana symbol images.
func _fill_text(text: String) -> void:
	_shown_text = NONE if text == "" else text
	_text.clear()
	if text == "":
		_text.push_color(DeckbuilderLook.MUTED)
		_text.add_text(NONE)
		_text.pop()
		return
	var symbol: RegEx = RegEx.create_from_string("\\{[^}]+\\}")
	var from: int = 0
	for found: RegExMatch in symbol.search_all(text):
		_text.add_text(text.substr(from, found.get_start() - from))
		var image: String = ManaSymbols.image_for(found.get_string())
		if image == "":
			_text.add_text(found.get_string())
		else:
			_text.add_image(ManaSymbols.texture(image), SYMBOL_SIZE, SYMBOL_SIZE, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		from = found.get_end()
	_text.add_text(text.substr(from))


func _fill_reminders(reminders: Array[Reminder]) -> void:
	_clear(_reminder_list)
	_reminder_keywords.clear()
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
		row.add_child(_words(reminder.keyword, reminder.text))
		_reminder_list.add_child(row)
		_reminder_keywords.append(reminder.keyword)
	if reminders.is_empty():
		_reminder_list.add_child(_label(NONE, BODY_SIZE, DeckbuilderLook.MUTED))


## The bubbles and a subpanel for each Mod and Hex on the card, in slot order.
func _fill_mods() -> void:
	var slots: Array[ModSlotRow.Slot] = ModSlotRow.slots_of(_card)
	for slot: int in _bubbles.size():
		_bubbles[slot].slot = slots[slot]
		_bubbles[slot].queue_redraw()
	_clear(_mod_list)
	_mod_names.clear()
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
		plate.add_child(_words("%s (Hex)" % title if mod.is_hex else title, mod.description))
		_mod_list.add_child(plate)
		_mod_names.append(mod.name)


## A panel with [param title] centered at its top. Returns the column to fill under it.
func _panel(title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = DeckbuilderLook.INSPECTOR_PANEL
	style.border_color = DeckbuilderLook.PANEL_EDGE
	style.set_border_width_all(DeckbuilderLook.PANEL_EDGE_WIDTH)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	style.content_margin_top = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	_body.add_child(panel)
	_panels.append(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	var heading: Label = _label(title, TITLE_SIZE, DeckbuilderLook.MUTED)
	heading.name = "Title"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	return column


static func _scroll(parent: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll


static func _list(scroll: ScrollContainer) -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


## A title over a sentence that wraps.
static func _words(title: String, sentence: String) -> VBoxContainer:
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading: Label = _label(title, BODY_SIZE, DeckbuilderLook.TEXT)
	heading.add_theme_font_override("font", DeckbuilderLook.bold())
	words.add_child(heading)
	if sentence != "":
		var body: Label = Label.new()
		# Wrapping is set before the text (conventions).
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.text = sentence
		body.add_theme_font_size_override("font_size", BODY_SIZE)
		body.add_theme_color_override("font_color", DeckbuilderLook.TEXT)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(body)
	return words


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func _clear(list: Control) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
