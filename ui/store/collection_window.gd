class_name CollectionWindow
extends Control
## The Collection Window (game glossary; milestone 24, signed off as prototypes/store_screen/
## step 3): where a card of the Collection is chosen for a sale at a Store. It stands over the
## Store, which it dims and which takes no clicks while it is open, nearly the whole screen,
## and lays the Collection out as the deckbuilder does: the deckbuilder's Inspector down its
## left, its filter bar over a scrolling grid of the Collection eight to a row, and along its
## foot the gold held, the Decks a card being sold is in, the button that confirms, with the
## coin and the price on it, and Close.
##
## A click on a card selects it, ringing it and holding it in the Inspector; a click on it
## again lets it go. With none selected the Inspector shows the card under the cursor. A card
## in a Deck carries a tag, "In 2 Decks". A card the Store does not buy, a Power-9 card or a
## basic land, is gray and takes no clicks. Sell sells the selected card for a third of its
## Store price as it is: it leaves the Collection and its Decks, the rest close up, and the
## gold counts up here and on the Store. Only the faces near the view are made, a few each
## frame, as in the deckbuilder.
## Later (milestone 25): Remove Mods/Hexes and Duplicate a Card, the Workshop's uses of it.

## A card was sold, and the gold changed.
signal sold
## Closed, by Close.
signal closed

const TITLE: String = "Sell Cards"
const CONFIRM: String = "Sell"
const CLOSE: String = "Close"
const DIM: Color = Color(0, 0, 0, 0.6)
const WINDOW: Rect2 = Rect2(12, 12, 1896, 1056)
const PAD: float = 14.0
const TITLE_HEIGHT: float = 48.0
const FOOT_HEIGHT: float = 56.0
const GAP: float = 10.0
const INSPECTOR_WIDTH: float = StoreLayout.INSPECTOR_WIDTH
const FILTER_HEIGHT: float = 52.0
## As the deckbuilder's Collection has its cards before any zoom, less two pixels so that
## eight stand in a row here as they do there.
const CARD_HEIGHT: float = DeckbuilderLayout.COLLECTION_CARD_HEIGHT - 2.0
## Between two rows there is room for a tag to stand half above its card.
const CARD_GAP: Vector2 = Vector2(8, 22)
const GRID_PAD: Vector2 = Vector2(4, 16)
const GRAY: Color = Color(0.42, 0.42, 0.42, 0.6)
## The deckbuilder's ring round a selected card.
const SELECTED_RING: Color = Color("#7fd4ff")
const TAG_FILL: Color = Color("#23272e")
const TAG_EDGE: Color = Color("#aab2c2")
## Faces are made a few each frame, as in the deckbuilder, so opening never stalls.
const FACE_BUDGET_MSEC: int = 6
## How many rows beyond the view are made ahead of the scroll.
const ROWS_AHEAD: int = 2

var _run: Run = null
var _ease_seconds: float = 0.0
var _count_seconds: float = 0.0
var _window: Panel = null
var _title: Label = null
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
var _tags: Dictionary[int, String] = {}
var _shown: Array[DeckbuilderCard] = []
var _selected: DeckbuilderCard = null
var _hovered: DeckbuilderCard = null
var _inspected: DeckbuilderCard = null
var _inspector: DeckbuilderInspector = null
var _count: Label = null
var _decks_line: Label = null
var _confirm: Button = null
var _close: Button = null


## A Collection Window for selling [param run]'s cards, laid over everything on [param host],
## easing over [param ease_seconds] and counting the gold over [param count_seconds].
static func over(host: Control, run: Run, ease_seconds: float, count_seconds: float) -> CollectionWindow:
	var made: CollectionWindow = CollectionWindow.new()
	made._run = run
	made._ease_seconds = ease_seconds
	made._count_seconds = count_seconds
	host.add_child(made)
	made._build()
	return made


## "Currently in Aggro", "Currently in Aggro and Control" or "Currently in Aggro, Control,
## and Midrange": the Decks a card being sold is in, or nothing for none.
static func currently_in(decks: Array[String]) -> String:
	match decks.size():
		0:
			return ""
		1:
			return "Currently in %s" % decks[0]
		2:
			return "Currently in %s and %s" % [decks[0], decks[1]]
	return "Currently in %s, and %s" % [", ".join(decks.slice(0, decks.size() - 1)), decks[decks.size() - 1]]


## A card's tag: how many Decks it is in.
static func deck_tag(count: int) -> String:
	return "In 1 Deck" if count == 1 else "In %d Decks" % count


func _init() -> void:
	name = "CollectionWindow"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nothing under the window takes a click.
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = DeckbuilderLook.theme()


func _process(_delta: float) -> void:
	_follow_cursor()
	_make_faces_near_view()


func title_text() -> String:
	return _title.text


func window() -> Control:
	return _window


func inspector() -> DeckbuilderInspector:
	return _inspector


func filter_bar() -> FilterBar:
	return _filter_bar


func columns() -> int:
	return _columns


## The cards the filter lets through, in its order.
func shown_cards() -> Array[DeckbuilderCard]:
	return _shown.duplicate()


## What takes [param card]'s clicks, where it stands in the grid.
func cell_of(card: DeckbuilderCard) -> Control:
	return _cells[card.id].get_node("Cover") as Control


## The tag [param card] carries, or "" for none.
func tag_of(card: DeckbuilderCard) -> String:
	return _tags.get(card.id, "")


func is_gray(card: DeckbuilderCard) -> bool:
	return not _run.can_sell(card)


func selected() -> DeckbuilderCard:
	return _selected


func is_ringed(card: DeckbuilderCard) -> bool:
	return _rings.has(card.id) and _rings[card.id].visible


## What the Inspector shows: the selected card, or with none the one under the cursor.
func inspected() -> DeckbuilderCard:
	return _inspected


func confirm_button() -> Button:
	return _confirm


## What the button that confirms reads, and the price on it, or "" for none.
func confirm_words() -> String:
	return StoreLook.button_words(_confirm)


func confirm_price() -> String:
	return StoreLook.button_price(_confirm)


## "Currently in …", or "".
func decks_line() -> String:
	return _decks_line.text


func gold_text() -> String:
	return _count.text


func close_button() -> Button:
	return _close


func close() -> void:
	closed.emit()
	Easing.fade_out_and_free(self, _ease_seconds)


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_window = Panel.new()
	_window.position = WINDOW.position
	_window.size = WINDOW.size
	_window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_theme_stylebox_override("panel", WindowLook.plate(int(WINDOW.size.y)))
	add_child(_window)
	_title = StoreLook.text(TITLE, 32, StoreLook.TEXT, true)
	_title.position = Vector2(0, 6)
	_title.size = Vector2(WINDOW.size.x, TITLE_HEIGHT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_window.add_child(_title)
	var top: float = TITLE_HEIGHT + 8.0
	var body_height: float = WINDOW.size.y - top - PAD - FOOT_HEIGHT - GAP
	_inspector = StoreLook.add_inspector(_window, Rect2(PAD, top, INSPECTOR_WIDTH, body_height))
	var left: float = PAD + INSPECTOR_WIDTH + GAP
	var across: float = WINDOW.size.x - left - PAD
	_add_filter_bar(Rect2(left, top, across, FILTER_HEIGHT))
	_add_grid(Rect2(left, top + FILTER_HEIGHT + GAP, across, body_height - FILTER_HEIGHT - GAP))
	_add_foot(Rect2(PAD, WINDOW.size.y - PAD - FOOT_HEIGHT, WINDOW.size.x - 2.0 * PAD, FOOT_HEIGHT))
	_lay_out_grid(true)
	_show_foot()
	Easing.fade_in(self, _ease_seconds)


## The deckbuilder's pane, shaded in [param fill].
func _pane(place: Rect2, fill: Color) -> Panel:
	var made: Panel = Panel.new()
	made.position = place.position
	made.size = place.size
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(made)
	InspectorParts.shade_background(made, null, fill, DeckbuilderLook.PANEL_EDGE, DeckbuilderLook.PANEL_EDGE_WIDTH,
			DeckbuilderLook.PANEL_RADIUS)
	return made


func _add_filter_bar(place: Rect2) -> void:
	var pane: Panel = _pane(place, DeckbuilderLook.PANE)
	var owned: Array[DeckbuilderCard] = _run.collection.cards()
	_filter_bar = FilterBar.new()
	_filter_bar.setup(_filter, _filter.apply(owned).size(), owned.size())
	_filter_bar.changed.connect(func() -> void: _lay_out_grid(true))
	_filter_bar.position = Vector2(8, 8)
	_filter_bar.size = place.size - Vector2(16, 16)
	_filter_bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pane.add_child(_filter_bar)


func _add_grid(place: Rect2) -> void:
	var pane: Panel = _pane(place, DeckbuilderLook.COLUMN)
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


## The foot: the gold held at the left; at the right the Decks a card being sold is in, the
## button that confirms, and Close.
func _add_foot(place: Rect2) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.position = place.position
	row.size = place.size
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(row)
	var gold: Control = StoreLook.gold_panel(_run.gold)
	row.add_child(gold)
	_count = StoreLook.count_of(gold)
	var room: Control = Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(room)
	_decks_line = StoreLook.text("", 22, StoreLook.TEXT, false)
	_decks_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_decks_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_decks_line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(_decks_line)
	_confirm = StoreLook.price_button(CONFIRM)
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)
	_close = StoreLook.button(CLOSE)
	_close.pressed.connect(close)
	row.add_child(_close)


## Puts the cards the filter lets through in their cells, in its order, and hides the rest.
func _lay_out_grid(resets_scroll: bool) -> void:
	_shown = _filter.apply(_run.collection.cards())
	for cell: Control in _cells.values():
		cell.visible = false
	for index: int in _shown.size():
		var card: DeckbuilderCard = _shown[index]
		if not _cells.has(card.id):
			_make_cell(card)
		var cell: Control = _cells[card.id]
		cell.visible = true
		cell.position = GRID_PAD + Vector2(index % _columns, index / _columns) * (_card_size + CARD_GAP)
	var rows: int = ceili(_shown.size() / float(_columns))
	_grid.custom_minimum_size = Vector2(0, 2.0 * GRID_PAD.y + rows * (_card_size.y + CARD_GAP.y) - CARD_GAP.y)
	if resets_scroll:
		_scroll.scroll_vertical = 0
	_filter_bar.show_count(_shown.size(), _run.collection.cards().size())


## A card's cell: where its face goes, the ring it wears when it is selected, its tag if it is
## in a Deck, and over them all what takes the mouse.
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
	var decks: int = _decks_of(card).size()
	if decks > 0:
		_tags[card.id] = deck_tag(decks)
		cell.add_child(_tag(_tags[card.id]))
	var cover: Control = Control.new()
	cover.name = "Cover"
	cover.size = _card_size
	# Pass, not stop: the wheel over a card still scrolls the grid.
	cover.mouse_filter = Control.MOUSE_FILTER_PASS
	cover.set_meta(&"card_id", card.id)
	cover.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_on_click(card))
	cell.add_child(cover)
	var can_take: bool = _run.can_sell(card)
	cell.modulate = Color.WHITE if can_take else GRAY
	cover.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_take else Control.CURSOR_ARROW


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
	pill.add_child(StoreLook.text(words, 16, StoreLook.TEXT, true))
	pill.anchor_left = 0.5
	pill.anchor_right = 0.5
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.offset_top = -13
	return pill


## The names of the Decks [param card] is in, in the Deckbox's order.
func _decks_of(card: DeckbuilderCard) -> Array[String]:
	var names: Array[String] = []
	for deck: Deck in _run.deckbox.decks():
		if deck.card_ids.has(card.id):
			names.append(deck.name)
	return names


## Makes the faces of the shown cards in view and a little beyond that are not made yet, for
## as long as FACE_BUDGET_MSEC allows this frame, one at least.
func _make_faces_near_view() -> void:
	if _shown.is_empty():
		return
	var row_height: float = _card_size.y + CARD_GAP.y
	var first_row: int = maxi(0, floori((_scroll.scroll_vertical - GRID_PAD.y) / row_height) - ROWS_AHEAD)
	var last_row: int = ceili((_scroll.scroll_vertical + _scroll.size.y) / row_height) + ROWS_AHEAD
	var started: int = Time.get_ticks_msec()
	var has_made: bool = false
	for index: int in range(first_row * _columns, mini(_shown.size(), (last_row + 1) * _columns)):
		var card: DeckbuilderCard = _shown[index]
		if _faces.has(card.id):
			continue
		if has_made and Time.get_ticks_msec() - started >= FACE_BUDGET_MSEC:
			return
		var face: CardFace = DeckbuilderFace.make(card, CARD_HEIGHT)
		_cells[card.id].add_child(face)
		_cells[card.id].move_child(face, 0)
		_faces[card.id] = face
		has_made = true


## The card under the cursor, asked each frame (conventions, "Ask where the cursor is each
## frame"), which the Inspector shows while none is selected.
func _follow_cursor() -> void:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	var card: DeckbuilderCard = null
	if hovered != null and hovered.has_meta(&"card_id"):
		card = _run.collection.card(hovered.get_meta(&"card_id") as int)
	if card != _hovered:
		_hovered = card
		_show_inspected()


## A click on a card the Store buys selects it, or lets it go if it is selected.
func _on_click(card: DeckbuilderCard) -> void:
	if _run.can_sell(card):
		_select(null if card == _selected else card)


func _select(card: DeckbuilderCard) -> void:
	if _selected != null and _rings.has(_selected.id):
		_rings[_selected.id].visible = false
	_selected = card
	if card != null:
		_rings[card.id].visible = true
	_show_inspected()
	_show_foot()


## Shows the selected card in the Inspector, or with none selected the one under the cursor.
func _show_inspected() -> void:
	var card: DeckbuilderCard = _selected if _selected != null else _hovered
	if card == _inspected:
		return
	_inspected = card
	_inspector.show_card(card, (INSPECTOR_WIDTH - 20.0) / CardGeometry.ASPECT, _ease_seconds)


## What the foot says now: the Decks the selected card is in, and on the button what the Store
## pays for it, the button off until a card is selected.
func _show_foot() -> void:
	_decks_line.text = currently_in(_decks_of(_selected)) if _selected != null else ""
	StoreLook.set_button_price(_confirm, Prices.sale_of_card(_selected) if _selected != null else -1, true,
			_selected != null)


## Sells the selected card: it leaves the Collection and every Deck, the rest close up, and
## the gold counts up.
func _on_confirm() -> void:
	var card: DeckbuilderCard = _selected
	if card == null or _run.sell(card) != "":
		return
	var cell: Control = _cells[card.id]
	_cells.erase(card.id)
	_faces.erase(card.id)
	_rings.erase(card.id)
	_tags.erase(card.id)
	Easing.fade_out_and_free(cell, _ease_seconds)
	_selected = null
	_hovered = null
	_inspected = null
	_inspector.show_card(null, (INSPECTOR_WIDTH - 20.0) / CardGeometry.ASPECT)
	_lay_out_grid(false)
	_show_foot()
	StoreLook.count_gold(_count, _run.gold, _count_seconds)
	sold.emit()
