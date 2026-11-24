extends Control
## PROTOTYPE (milestones 24 and 25, step 3): the Collection Window (game glossary), which
## the Store opens to sell cards and the Workshop for a Removal and for a Duplication. It
## stands over the shop, which it dims, and lays the Collection out as the deckbuilder
## does: the deckbuilder's own Inspector down its left, its filter bar over a scrolling
## grid of cards, and along its foot the gold held, the one button that confirms, with the
## coin and the price on it, and Close. Throwaway: deleted with the two prototypes. It
## changes only the sample Holdings it is handed, never a run.
##
## A click on a card selects it, ringing it and holding it in the Inspector; a click on it
## again lets it go. A card the window cannot take is gray and takes no clicks: a Power-9
## card when selling or duplicating, and a card with no Mod and no Hex for a Removal. A
## card in a Deck carries a tag, "In 2 Decks".
##   Sell Cards: the button reads "Sell" with what the Store pays, a third of its price for
##   the card as it is, and over it stands "Currently in Aggro and Control" for a card in
##   Decks. Sold, the card leaves the Collection and its Decks and the gold counts up.
##   Remove Mods/Hexes: the Mods panel heads the selected card's Mods and Hexes with "Choose
##   one to remove."; a click on one chooses it, and "Remove" takes it off for the flat
##   price. While a card is selected the Mods panel takes the Card Text panel's room, so
##   that all three of a full card's Mods show. With nothing to remove anywhere, the
##   window says so in place of the cards.
##   Duplicate a Card: the button reads "Duplicate" with the Store's price for the card as
##   it is. Duplicated, the copy joins the Collection and the window closes, since a visit
##   has one Duplication.

signal gold_changed(gold: int)
signal duplicated
signal closed

enum Use { SELL, REMOVE, DUPLICATE }

const Parts = preload("res://prototypes/store_screen/shop_parts.gd")
const TITLES: Dictionary[Use, String] = {
	Use.SELL: "Sell Cards", Use.REMOVE: "Remove Mods/Hexes", Use.DUPLICATE: "Duplicate a Card",
}
const CONFIRMS: Dictionary[Use, String] = { Use.SELL: "Sell", Use.REMOVE: "Remove", Use.DUPLICATE: "Duplicate" }
const CLOSE: String = "Close"
const CHOOSE_ONE: String = "Choose one to remove."
const NOTHING_TO_REMOVE: String = "None of your cards has a Mod or a Hex."
const DIM: Color = Color(0, 0, 0, 0.6)
const WINDOW: Rect2 = Rect2(12, 12, 1896, 1056)
const PAD: float = 14.0
const TITLE_HEIGHT: float = 48.0
const FOOT_HEIGHT: float = 56.0
const GAP: float = 10.0
const INSPECTOR_WIDTH: float = 340.0
const FILTER_HEIGHT: float = 52.0
## As the deckbuilder's Collection has its cards before any zoom, less two pixels so that
## eight stand in a row here as they do there.
const CARD_HEIGHT: float = DeckbuilderLayout.COLLECTION_CARD_HEIGHT - 2.0
## Between two rows there is room for a tag to stand half above its card.
const CARD_GAP: Vector2 = Vector2(8, 22)
const GRID_PAD: Vector2 = Vector2(4, 16)
const GRAY: Color = Color(0.42, 0.42, 0.42, 0.6)
## The deckbuilder's ring round a selected card, and the Modify Window's round a chosen Mod.
const SELECTED_RING: Color = Color("#7fd4ff")
const CHOSEN_RING: Color = Color("#e8cf8a")
const TAG_FILL: Color = Color("#23272e")
const TAG_EDGE: Color = Color("#aab2c2")
## Faces are made a few each frame, as in the deckbuilder, so opening never stalls.
const FACE_BUDGET_MSEC: int = 6

var _use: Use = Use.SELL
var _held: Parts.Holdings = null
var _gold: int = 0
var _ease_seconds: float = 0.0
var _count_seconds: float = 0.0
var _filter: CollectionFilter = CollectionFilter.new()
var _filter_bar: FilterBar = null
var _scroll: ScrollContainer = null
var _grid: Control = null
var _columns: int = 1
var _card_size: Vector2 = Vector2.ZERO
## Each card's cell in the grid, and its face once it is made, by the card's identity.
var _cells: Dictionary[int, Control] = {}
var _faces: Dictionary[int, CardFace] = {}
var _rings: Dictionary[int, Panel] = {}
var _to_make: Array[DeckbuilderCard] = []
var _shown: Array[DeckbuilderCard] = []
var _selected: DeckbuilderCard = null
var _hovered: DeckbuilderCard = null
var _inspected: DeckbuilderCard = null
## Which of the selected card's Mods and Hexes is chosen for a Removal, or -1.
var _chosen_mod: int = -1
var _inspector: DeckbuilderInspector = null
## The Inspector's Card Text panel while it is put away for a Removal, or null.
var _card_text: PanelContainer = null
var _count: Label = null
var _decks_line: Label = null
var _confirm: Button = null
var _close: Button = null
## While a picture is being made the cursor is only where the flags put it.
var is_driven: bool = false


## Opens for [param use] on what [param held] holds, with [param gold] to spend.
func setup(use: Use, held: Parts.Holdings, gold: int, ease_seconds: float, count_seconds: float) -> void:
	_use = use
	_held = held
	_gold = gold
	_ease_seconds = ease_seconds
	_count_seconds = count_seconds
	theme = DeckbuilderLook.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nothing under the window takes a click.
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var window: Panel = Panel.new()
	window.position = WINDOW.position
	window.size = WINDOW.size
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_theme_stylebox_override("panel", WindowLook.plate(int(WINDOW.size.y)))
	add_child(window)
	var title: Label = Parts.text(TITLES[use], 32, Parts.TEXT, true)
	title.position = Vector2(0, 6)
	title.size = Vector2(WINDOW.size.x, TITLE_HEIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	window.add_child(title)
	var top: float = TITLE_HEIGHT + 8.0
	var body_height: float = WINDOW.size.y - top - PAD - FOOT_HEIGHT - GAP
	_inspector = Parts.add_inspector(window, Rect2(PAD, top, INSPECTOR_WIDTH, body_height))
	var left: float = PAD + INSPECTOR_WIDTH + GAP
	var across: float = WINDOW.size.x - left - PAD
	_add_filter_bar(window, Rect2(left, top, across, FILTER_HEIGHT))
	_add_grid(window, Rect2(left, top + FILTER_HEIGHT + GAP, across, body_height - FILTER_HEIGHT - GAP))
	_add_foot(window, Rect2(PAD, WINDOW.size.y - PAD - FOOT_HEIGHT, WINDOW.size.x - 2.0 * PAD, FOOT_HEIGHT))
	_lay_out_grid(true)
	_show_foot()
	Easing.fade_in(self, _ease_seconds)


func _process(_delta: float) -> void:
	if _to_make.is_empty():
		return
	var started: int = Time.get_ticks_msec()
	var has_made: bool = false
	while not _to_make.is_empty() and (not has_made or Time.get_ticks_msec() - started < FACE_BUDGET_MSEC):
		_make_face(_to_make.pop_front())
		has_made = true


## The deckbuilder's pane, shaded in [param fill].
func _pane(on: Control, place: Rect2, fill: Color) -> Panel:
	var made: Panel = Panel.new()
	made.position = place.position
	made.size = place.size
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	on.add_child(made)
	InspectorParts.shade_background(made, null, fill, DeckbuilderLook.PANEL_EDGE, DeckbuilderLook.PANEL_EDGE_WIDTH,
			DeckbuilderLook.PANEL_RADIUS)
	return made


func _add_filter_bar(on: Control, place: Rect2) -> void:
	var pane: Panel = _pane(on, place, DeckbuilderLook.PANE)
	var owned: Array[DeckbuilderCard] = _held.collection.cards()
	_filter_bar = FilterBar.new()
	_filter_bar.setup(_filter, _filter.apply(owned).size(), owned.size())
	_filter_bar.changed.connect(func() -> void: _lay_out_grid(true))
	_filter_bar.position = Vector2(8, 8)
	_filter_bar.size = place.size - Vector2(16, 16)
	_filter_bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pane.add_child(_filter_bar)


func _add_grid(on: Control, place: Rect2) -> void:
	var pane: Panel = _pane(on, place, DeckbuilderLook.COLUMN)
	if _use == Use.REMOVE and not _held.collection.cards().any(func(card: DeckbuilderCard) -> bool: return card.is_modified()):
		var none: Label = Parts.text(NOTHING_TO_REMOVE, 28, Parts.TEXT, false)
		none.set_anchors_preset(Control.PRESET_FULL_RECT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pane.add_child(none)
		return
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = Vector2(10, 4)
	_scroll.size = place.size - Vector2(20, 8)
	_scroll.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pane.add_child(_scroll)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_grid)
	_card_size = Vector2(roundf(CARD_HEIGHT * CardGeometry.ASPECT), CARD_HEIGHT)
	var room: float = _scroll.size.x - DeckbuilderLayout.SCROLL_BAR - 2.0 * GRID_PAD.x
	_columns = maxi(1, floori((room + CARD_GAP.x) / (_card_size.x + CARD_GAP.x)))


## The foot: the gold held at the left; at the right the Decks a card being sold is in,
## the button that confirms, and Close.
func _add_foot(on: Control, place: Rect2) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.position = place.position
	row.size = place.size
	row.add_theme_constant_override("separation", 14)
	on.add_child(row)
	var gold: Control = Parts.gold_panel(_gold)
	row.add_child(gold)
	_count = gold.find_child("Count", true, false) as Label
	var room: Control = Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(room)
	_decks_line = Parts.text("", 22, Parts.TEXT, false)
	_decks_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_decks_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_decks_line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(_decks_line)
	_confirm = Parts.price_button(CONFIRMS[_use])
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)
	_close = Parts.button(CLOSE)
	_close.pressed.connect(close)
	row.add_child(_close)


## Whether the window can take [param card] for what it was opened for.
func _can_take(card: DeckbuilderCard) -> bool:
	var is_power_nine: bool = card.run_card.base.rarity == MmCardDefinition.Rarity.POWER_NINE
	match _use:
		Use.SELL:
			return not is_power_nine
		Use.REMOVE:
			return card.is_modified()
	return not is_power_nine and not card.mods.any(func(mod: Mod) -> bool: return mod.rarity == Mod.Rarity.UNIQUE)


## Puts the cards the filter lets through in their cells, in its order, and hides the rest.
func _lay_out_grid(resets_scroll: bool) -> void:
	if _grid == null:
		return
	_shown = _filter.apply(_held.collection.cards())
	for cell: Control in _cells.values():
		cell.visible = false
	_to_make.clear()
	for index: int in _shown.size():
		var card: DeckbuilderCard = _shown[index]
		if not _cells.has(card.id):
			_make_cell(card)
		var cell: Control = _cells[card.id]
		cell.visible = true
		cell.position = GRID_PAD + Vector2(index % _columns, index / _columns) * (_card_size + CARD_GAP)
		if not _faces.has(card.id):
			_to_make.append(card)
	var rows: int = ceili(_shown.size() / float(_columns))
	_grid.custom_minimum_size = Vector2(0, 2.0 * GRID_PAD.y + rows * (_card_size.y + CARD_GAP.y) - CARD_GAP.y)
	if resets_scroll:
		_scroll.scroll_vertical = 0
	_filter_bar.show_count(_shown.size(), _held.collection.cards().size())
	if is_driven:
		# A picture shows every face at once.
		while not _to_make.is_empty():
			_make_face(_to_make.pop_front())


## A card's cell: where its face goes, the ring it wears when it is selected, its tag if
## it is in a Deck, and over them all what takes the mouse.
func _make_cell(card: DeckbuilderCard) -> void:
	var cell: Control = Control.new()
	cell.size = _card_size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(cell)
	_cells[card.id] = cell
	var ring: Panel = Panel.new()
	ring.position = Vector2(-4, -4)
	ring.size = _card_size + Vector2(8, 8)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style: StyleBoxFlat = StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = SELECTED_RING
	ring_style.set_border_width_all(3)
	ring_style.set_corner_radius_all(int(_card_size.x * CardGeometry.CORNER) + 4)
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.visible = card == _selected
	cell.add_child(ring)
	_rings[card.id] = ring
	var decks: int = _held.decks_of(card).size()
	if decks > 0:
		cell.add_child(_tag(Parts.deck_tag(decks)))
	var cover: Control = Control.new()
	cover.name = "Cover"
	cover.size = _card_size
	# Pass, not stop: the wheel over a card still scrolls the grid.
	cover.mouse_filter = Control.MOUSE_FILTER_PASS
	cover.mouse_entered.connect(func() -> void: _on_hover(card))
	cover.mouse_exited.connect(func() -> void: _on_hover(null))
	cover.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_on_click(card))
	cell.add_child(cover)
	_show_cell(card)


## Grays [param card]'s cell if the window cannot take it, and gives its cursor a hand if
## it can.
func _show_cell(card: DeckbuilderCard) -> void:
	var cell: Control = _cells[card.id]
	var can_take: bool = _can_take(card)
	cell.modulate = Color.WHITE if can_take else GRAY
	(cell.get_node("Cover") as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_take \
			else Control.CURSOR_ARROW


## A tag standing half above its card, in the middle of its top edge.
func _tag(words: String) -> Control:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = TAG_FILL
	style.border_color = TAG_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 0
	style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(Parts.text(words, 16, Parts.TEXT, true))
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = -13
	return pill


func _make_face(card: DeckbuilderCard) -> void:
	if not _cells.has(card.id) or _faces.has(card.id):
		return
	var face: CardFace = DeckbuilderFace.make(card, CARD_HEIGHT)
	_cells[card.id].add_child(face)
	_cells[card.id].move_child(face, 0)
	_faces[card.id] = face


func _on_hover(card: DeckbuilderCard) -> void:
	if card == null and is_driven:
		return
	_hovered = card
	_show_inspected()


## A click on a card the window can take selects it, or lets it go if it is selected.
func _on_click(card: DeckbuilderCard) -> void:
	if _can_take(card):
		_select(null if card == _selected else card)


func _select(card: DeckbuilderCard) -> void:
	if _selected != null and _rings.has(_selected.id):
		_rings[_selected.id].visible = false
	_selected = card
	_chosen_mod = -1
	if card != null:
		_rings[card.id].visible = true
	_show_inspected(true)
	_show_foot()


## Shows the selected card in the Inspector, or with none selected the one under the
## cursor. For a Removal the selected card's Mods and Hexes can be chosen there.
func _show_inspected(is_changed: bool = false) -> void:
	var card: DeckbuilderCard = _selected if _selected != null else _hovered
	if card == _inspected and not is_changed:
		return
	_inspected = card
	var face_height: float = (INSPECTOR_WIDTH - 20.0) / CardGeometry.ASPECT
	# A Removal's Mods are made clickable as soon as they are listed, so nothing is eased.
	_inspector.show_card(card, face_height, 0.0 if _use == Use.REMOVE else _ease_seconds)
	if _card_text != null:
		_card_text.visible = true
		_card_text = null
	if _use == Use.REMOVE and card != null and card == _selected:
		_offer_mods()


## Heads the Inspector's list of the selected card's Mods and Hexes with "Choose one to
## remove." and lets a click on one choose it.
func _offer_mods() -> void:
	var plates: Array[PanelContainer] = _mod_plates()
	if plates.is_empty():
		return
	# The Mods panel takes the Card Text panel's room while a Mod is being chosen: with
	# half the room, a card's second and third Mods are out of sight under the first.
	for panel: PanelContainer in _inspector.panels():
		if InspectorParts.title_of(panel).text == "Card Text":
			_card_text = panel
			panel.visible = false
	var list: Control = plates[0].get_parent() as Control
	var heading: Label = InspectorParts.label(CHOOSE_ONE, DeckbuilderInspector.BODY_SIZE, DeckbuilderLook.TEXT)
	heading.add_theme_font_override("font", InspectorParts.italic())
	list.add_child(heading)
	list.move_child(heading, 0)
	for index: int in plates.size():
		var plate: PanelContainer = plates[index]
		plate.mouse_filter = Control.MOUSE_FILTER_PASS
		plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		plate.gui_input.connect(func(event: InputEvent) -> void:
			var click: InputEventMouseButton = event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				_choose_mod(index))


## The plate of each Mod and Hex the Inspector lists, in slot order.
func _mod_plates() -> Array[PanelContainer]:
	var plates: Array[PanelContainer] = []
	for label: SymbolLabel in _inspector.mod_labels():
		plates.append(label.get_parent().get_parent() as PanelContainer)
	return plates


func _choose_mod(index: int) -> void:
	_chosen_mod = index
	var plates: Array[PanelContainer] = _mod_plates()
	for at: int in plates.size():
		var style: StyleBoxFlat = plates[at].get_theme_stylebox("panel") as StyleBoxFlat
		if not plates[at].has_meta(&"edge"):
			plates[at].set_meta(&"edge", style.border_color)
		style.border_color = CHOSEN_RING if at == index else plates[at].get_meta(&"edge") as Color
		style.border_width_top = 3 if at == index else 1
		style.border_width_right = 3 if at == index else 1
		style.border_width_bottom = 3 if at == index else 1
	_show_foot()


## What the foot says now: the Decks a card being sold is in, and on the button the price,
## red when it cannot be paid, the button off until there is something to confirm.
func _show_foot() -> void:
	_decks_line.text = ""
	match _use:
		Use.SELL:
			if _selected != null:
				_decks_line.text = Parts.currently_in(_held.decks_of(_selected))
			Parts.set_button_price(_confirm, Parts.sale_price(_selected) if _selected != null else -1, true,
					_selected != null)
		Use.REMOVE:
			var can_pay: bool = _gold >= Parts.REMOVAL_PRICE
			Parts.set_button_price(_confirm, Parts.REMOVAL_PRICE, can_pay, can_pay and _selected != null and _chosen_mod >= 0)
		Use.DUPLICATE:
			var price: int = Parts.card_price(_selected) if _selected != null else -1
			Parts.set_button_price(_confirm, price, _gold >= price, _selected != null and _gold >= price)


func _on_confirm() -> void:
	if _selected == null:
		return
	match _use:
		Use.SELL:
			_sell(_selected)
		Use.REMOVE:
			if _chosen_mod >= 0:
				_remove(_selected, _chosen_mod)
		Use.DUPLICATE:
			_duplicate(_selected)


## Sells [param card]: it leaves the Collection and every Deck, and the gold counts up.
func _sell(card: DeckbuilderCard) -> void:
	_pay(Parts.sale_price(card))
	_held.collection.remove(card)
	_held.deckbox.forget(card.id)
	var cell: Control = _cells[card.id]
	_cells.erase(card.id)
	_faces.erase(card.id)
	_rings.erase(card.id)
	Easing.fade_out_and_free(cell, _ease_seconds)
	_selected = null
	_hovered = null
	_lay_out_grid(false)
	_show_inspected(true)
	_show_foot()


## Takes the Mod or Hex at [param index] off [param card] for the flat price. A Mod goes
## back into the Satchel; a Hex is gone.
func _remove(card: DeckbuilderCard, index: int) -> void:
	if _gold < Parts.REMOVAL_PRICE:
		return
	_pay(-Parts.REMOVAL_PRICE)
	var mod: Mod = card.mods[index]
	if not mod.is_hex:
		_held.returned_mods.append(mod)
	# PROTOTYPE: the game has no way to take a Mod off a card yet, so the card is remade in
	# place from the Mods it keeps.
	card.mods.remove_at(index)
	card.run_card.modifications.clear()
	for kept: Mod in card.mods:
		card.run_card.modifications.append_array(kept.modifications())
	card.revision += 1
	card._characteristics = null
	if _faces.has(card.id):
		_faces[card.id].queue_free()
		_faces.erase(card.id)
	_chosen_mod = -1
	if not card.is_modified():
		_rings[card.id].visible = false
		_selected = null
	_show_cell(card)
	_lay_out_grid(false)
	_show_inspected(true)
	_show_foot()


## Makes an exact second Run Card of [param card], its Mods and Hexes included, which joins
## the Collection and no Deck, and closes the window: a visit has one Duplication.
func _duplicate(card: DeckbuilderCard) -> void:
	var price: int = Parts.card_price(card)
	if _gold < price:
		return
	_pay(-price)
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = card.run_card.base
	_held.collection.add(run_card, card.mods.duplicate())
	duplicated.emit()
	close()


## Adds [param amount] to the gold, or takes it away if it is negative, counting the panel
## and telling the shop.
func _pay(amount: int) -> void:
	_gold += amount
	Parts.count_gold(_count, _gold, _count_seconds)
	gold_changed.emit(_gold)


func close() -> void:
	closed.emit()
	Easing.fade_out_and_free(self, _ease_seconds)


# ---------------------------------------------------------------------------------------
# PROTOTYPE: driving the window for a picture, each with a real mouse event.
# ---------------------------------------------------------------------------------------

## Does what [param argument] asks of the window and returns true, or false if it asks
## nothing of it: --pick="Card Name" clicks that card, scrolling to it first;
## --pick-mod=2 clicks the second Mod or Hex listed in the Inspector; --confirm clicks the
## button that confirms; --close clicks Close.
func drive(argument: String) -> bool:
	if argument.begins_with("--pick="):
		for card: DeckbuilderCard in _shown:
			if card.card_name() == argument.trim_prefix("--pick="):
				_scroll.scroll_vertical = int(maxf(0.0, _cells[card.id].position.y - 60.0))
				_make_face(card)
				for frame: int in 2:
					await get_tree().process_frame
				Parts.click_on(_cells[card.id].get_node("Cover") as Control)
				return true
		return true
	if argument.begins_with("--pick-mod="):
		var plates: Array[PanelContainer] = _mod_plates()
		var index: int = int(argument.trim_prefix("--pick-mod=")) - 1
		if index >= 0 and index < plates.size():
			Parts.click_on(plates[index])
		return true
	if argument == "--confirm":
		Parts.click_on(_confirm)
		return true
	if argument == "--close":
		Parts.click_on(_close)
		return true
	return false
