class_name ModPopup
extends Control
## The window for applying a held Mod to the selected card. It covers the deckbuilder and
## lists every kind of Mod the Hero holds, with how many: the ones not applicable to the
## card are gray and take no clicks. Hovering over a Mod shows the card as it would become
## beside the card as it is. Clicking one offers Apply and Cancel, and Apply asks once more
## before it says the Mod was applied, because applying is final.
##
## It changes nothing itself: it reports [signal applied] and [signal closed].

signal applied(mod: Mod)
signal closed

enum State { CHOOSING, CHOSEN, CONFIRMING }

const WINDOW: Vector2 = Vector2(1000, 640)
const PAD: float = 20.0
const TILES_WIDTH: float = 380.0
const FACE_HEIGHT: float = 380.0
const DIM: Color = Color(0, 0, 0, 0.6)
const FILL: Color = Color("#23272e")
const BORDER: Color = Color("#4a515d")
const MUTED: Color = Color("#9aa3af")
const CHOSEN_RING: Color = Color("#e8cf8a")

var _card: DeckbuilderCard = null
var _held_mods: HeldMods = null
var _state: State = State.CHOOSING
## The Mod the "after" face is showing, or null.
var _previewed: Mod = null
## The Mod that was clicked, or null.
var _chosen: Mod = null
var _tiles: Dictionary[Mod, Button] = {}
var _before: CardFace = null
var _after: CardFace = null
var _after_place: Control = null
var _after_caption: Label = null
var _footer: HBoxContainer = null
var _buttons: Dictionary[String, Button] = {}
var _question: Label = null


## Shows the Mods of [param held_mods] for [param card].
func setup(card: DeckbuilderCard, held_mods: HeldMods) -> void:
	_card = card
	_held_mods = held_mods
	theme = DeckbuilderLook.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var window: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	window.add_theme_stylebox_override("panel", style)
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.offset_left = -WINDOW.x / 2.0
	window.offset_right = WINDOW.x / 2.0
	window.offset_top = -WINDOW.y / 2.0
	window.offset_bottom = WINDOW.y / 2.0
	add_child(window)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	rows.position = Vector2(PAD, PAD)
	rows.size = WINDOW - 2.0 * Vector2(PAD, PAD)
	window.add_child(rows)
	rows.add_child(_label("Modify %s" % card.look().name, 26))
	var middle: HBoxContainer = HBoxContainer.new()
	middle.add_theme_constant_override("separation", 24)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(middle)
	middle.add_child(_tile_list())
	middle.add_child(_faces())
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	_footer.custom_minimum_size = Vector2(0, 40)
	rows.add_child(_footer)
	_show_state()


func state() -> State:
	return _state


## The tile for [param mod], or null if none of it is held.
func tile(mod: Mod) -> Button:
	return _tiles.get(mod, null) as Button


## The Mod the "as it would become" face is showing, or null.
func previewed() -> Mod:
	return _previewed


## The Mod that was clicked and is waiting for Apply, or null.
func chosen() -> Mod:
	return _chosen


## The card as it is.
func before_face() -> CardFace:
	return _before


## The card as it would become with the previewed Mod, or null while none is previewed.
func after_face() -> CardFace:
	return _after


## The button named [param key] if it is offered now: "close", "apply", "cancel", "yes" or
## "no". Null otherwise.
func button(key: String) -> Button:
	return _buttons.get(key, null) as Button


## What Apply asks before it is final, or "" when it is not asking.
func question() -> String:
	return "" if _question == null else _question.text


## The cursor comes over [param mod]'s tile, or leaves the tiles when it is null. The card
## with that Mod is shown, unless a Mod has already been clicked.
func hover(mod: Mod) -> void:
	if _state != State.CHOOSING:
		return
	_preview(mod if mod != null and mod.is_applicable_to(_card) else null)


## [param mod]'s tile is clicked. Nothing happens for one that is not applicable.
func choose(mod: Mod) -> void:
	if _state == State.CONFIRMING or not _tiles.has(mod) or not mod.is_applicable_to(_card):
		return
	_chosen = mod
	_state = State.CHOSEN
	_preview(mod)
	_show_state()


func _on_apply() -> void:
	_state = State.CONFIRMING
	_show_state()


func _on_cancel() -> void:
	_chosen = null
	_state = State.CHOOSING
	_preview(null)
	_show_state()


func _on_yes() -> void:
	applied.emit(_chosen)


func _on_no() -> void:
	_state = State.CHOSEN
	_show_state()


func _on_close() -> void:
	closed.emit()


## The held Mods, one tile for each kind.
func _tile_list() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(TILES_WIDTH, 0)
	column.add_child(_label("Held Mods", 18, MUTED))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var tiles: VBoxContainer = VBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tiles)
	if _held_mods.kinds().is_empty():
		tiles.add_child(_label("You hold no Mods.", 18, MUTED))
	for mod: Mod in _held_mods.kinds():
		var button: Button = Button.new()
		button.text = "%s   ×%d\n%s" % [mod.name, _held_mods.count_of(mod), mod.description]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.custom_minimum_size = Vector2(0, 68)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not mod.is_applicable_to(_card)
		if button.disabled:
			button.tooltip_text = "This Mod cannot go on this card."
		button.pressed.connect(choose.bind(mod))
		button.mouse_entered.connect(hover.bind(mod))
		button.mouse_exited.connect(hover.bind(null))
		tiles.add_child(button)
		_tiles[mod] = button
	return column


## The card as it is, and beside it the place for the card as it would become.
func _faces() -> Control:
	var pair: HBoxContainer = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 24)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_size: Vector2 = Vector2(FACE_HEIGHT * CardGeometry.ASPECT, FACE_HEIGHT)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_child(_label("As it is", 18, MUTED))
	_before = DeckbuilderFace.make(_card, FACE_HEIGHT)
	left.add_child(_before)
	pair.add_child(left)
	var right: VBoxContainer = VBoxContainer.new()
	_after_caption = _label("With a Mod", 18, MUTED)
	right.add_child(_after_caption)
	_after_place = Panel.new()
	var empty: StyleBoxFlat = StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0.25)
	empty.border_color = BORDER
	empty.set_border_width_all(1)
	empty.set_corner_radius_all(roundi(card_size.x * CardGeometry.CORNER))
	_after_place.add_theme_stylebox_override("panel", empty)
	_after_place.custom_minimum_size = card_size
	var hint: Label = _label("Hover over a Mod to see the card with it.", 18, MUTED)
	hint.name = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(24, 0)
	hint.size = card_size - Vector2(48, 0)
	_after_place.add_child(hint)
	right.add_child(_after_place)
	pair.add_child(right)
	return pair


## Shows the card as [param mod] would leave it, or the empty place for null.
func _preview(mod: Mod) -> void:
	if mod == _previewed:
		return
	_previewed = mod
	if _after != null:
		_after.queue_free()
		_after = null
	(_after_place.get_node("Hint") as Label).visible = mod == null
	_after_caption.text = "With a Mod" if mod == null else "With %s" % mod.name
	if mod != null:
		_after = DeckbuilderFace.make(_card.with_mod(mod), FACE_HEIGHT)
		_after_place.add_child(_after)


## Draws the buttons the state offers and marks the chosen tile.
func _show_state() -> void:
	for child: Node in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_question = null
	for mod: Mod in _tiles:
		var button: Button = _tiles[mod]
		button.disabled = _state == State.CONFIRMING or not mod.is_applicable_to(_card)
		if mod == _chosen:
			var ring: StyleBoxFlat = StyleBoxFlat.new()
			ring.bg_color = Color("#343b47")
			ring.border_color = CHOSEN_RING
			ring.set_border_width_all(2)
			ring.set_corner_radius_all(4)
			ring.set_content_margin_all(8)
			for look: String in ["normal", "hover", "pressed", "disabled"]:
				button.add_theme_stylebox_override(look, ring)
		else:
			for look: String in ["normal", "hover", "pressed", "disabled"]:
				button.remove_theme_stylebox_override(look)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match _state:
		State.CHOOSING:
			_footer.add_child(_label("Click a Mod to apply it. Applying is permanent.", 18, MUTED))
			_footer.add_child(spacer)
			_add_button("close", "Close", _on_close)
		State.CHOSEN:
			_footer.add_child(_label("%s will fill one of this card's Mod Slots." % _chosen.name, 18, MUTED))
			_footer.add_child(spacer)
			_add_button("apply", "Apply", _on_apply)
			_add_button("cancel", "Cancel", _on_cancel)
		State.CONFIRMING:
			_question = _label("Are you sure? Applying %s to %s cannot be undone." % [_chosen.name, _card.look().name], 18)
			_footer.add_child(_question)
			_footer.add_child(spacer)
			_add_button("yes", "Yes, apply it", _on_yes)
			_add_button("no", "No, go back", _on_no)


func _add_button(key: String, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 0)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_footer.add_child(button)
	_buttons[key] = button


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
