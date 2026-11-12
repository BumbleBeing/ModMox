class_name DeckbuilderScreen
extends Control
## The deckbuilder: the Collection, the Working Deck in its eight columns, an inspector and
## a top bar. It only draws what the Working Deck and the Collection Filter say and places
## it where the DeckbuilderLayout works out.
##
## A left press picks a card up once the cursor has moved a little: dropped on a column it
## is added or moved there, and a Deck card dropped anywhere else is removed. A double-click
## adds a Collection card to its own column or takes a card out of the Deck. Nothing is
## rebuilt for any of this: faces are kept and moved.
##
## Steps 2 to 4 of the prototype. Selection, the inspector, Mods, Save and Exit come later.
## Add --screenshot=/absolute/path.png to save a picture and quit.

const BACKGROUND: Color = Color("#1a1d22")
const PANE: Color = Color("#23272e")
const PANE_BORDER: Color = Color("#3a404a")
const MUTED: Color = Color("#9aa3af")
const ILLEGAL: Color = Color("#e5484d")
## A Collection card that is already in the Deck is drawn this faint.
const IN_DECK_DIM: float = 0.5
## The face a held card was lifted from is drawn this faint until it is put down.
const LIFTED_DIM: float = 0.25
## How far the cursor must move with the button down before a card is picked up.
const DRAG_START: float = 6.0
const DROP_BORDER: Color = Color("#e8cf8a")
const COLUMN_TITLES: Array[String] = ["0", "1", "2", "3", "4", "5", "6+", "Lands"]
const LAND_SYMBOLS: Dictionary[String, String] = {
	"Plains": "w", "Island": "u", "Swamp": "b", "Mountain": "r", "Forest": "g",
}

## Whether the screen makes its own sample run when it is ready. Tests hand it one.
var starts_itself: bool = true

var _sample: DeckbuilderSample = null
var _working_deck: WorkingDeck = null
var _filter: CollectionFilter = CollectionFilter.new()
## The card the inspector is showing, or null.
var _inspected: DeckbuilderCard = null
var _root: Control = null
var _column_faces: Dictionary[int, CardFace] = {}
var _column_panes: Array[Panel] = []
var _column_scrolls: Array[ScrollContainer] = []
var _column_fans: Array[Control] = []
var _column_counts: Array[Label] = []
var _land_buttons: Dictionary[String, Button] = {}
var _sort_button: Button = null
## The card under a left press that has not been released, and where it was pressed.
var _pressed: DeckbuilderCard = null
var _press_point: Vector2 = Vector2.ZERO
## The face following the cursor while a card is held, or null.
var _held: CardFace = null
## The column the held card would drop into, or NO_COLUMN.
var _drop_column: int = WorkingDeck.NO_COLUMN
var _collection_faces: Dictionary[int, CardFace] = {}
var _count_label: Label = null
var _name_box: LineEdit = null
var _filter_bar: FilterBar = null
var _collection_scroll: ScrollContainer = null
var _collection_grid: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_redraw)
	if not starts_itself:
		return
	begin(DeckbuilderSample.make())
	var picture: String = EncounterScreen.screenshot_path(OS.get_cmdline_user_args())
	if picture != "":
		for frame: int in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Opens the deckbuilder on [param sample]'s saved Deck.
func begin(sample: DeckbuilderSample) -> void:
	_sample = sample
	_working_deck = sample.working_deck()
	var cards: Array[DeckbuilderCard] = _working_deck.cards()
	_inspected = null if cards.is_empty() else cards[0]
	_redraw()


func layout() -> DeckbuilderLayout:
	return DeckbuilderLayout.new(size)


## The face of a card in the columns, or null if it is not in the Deck.
func column_face(card: DeckbuilderCard) -> CardFace:
	return _column_faces.get(card.id, null) as CardFace


## The face of a card in the Collection pane, or null if it is filtered out.
func collection_face(card: DeckbuilderCard) -> CardFace:
	var face: CardFace = _collection_faces.get(card.id, null) as CardFace
	return null if face != null and not face.visible else face


func working_deck() -> WorkingDeck:
	return _working_deck


## The face following the cursor while a card is held, or null.
func held_face() -> CardFace:
	return _held


## The button that adds the basic land named [param land].
func land_button(land: String) -> Button:
	return _land_buttons.get(land, null) as Button


func sort_button() -> Button:
	return _sort_button


## The column a held card would drop into, or NO_COLUMN.
func drop_column() -> int:
	return _drop_column


## The card whose face is showing at [param point], or null. In a column it is the card
## whose face is on top there.
func card_at(point: Vector2) -> DeckbuilderCard:
	for column: int in _column_scrolls.size():
		if not _column_scrolls[column].get_global_rect().has_point(point):
			continue
		var cards: Array[DeckbuilderCard] = _working_deck.cards_in(column)
		for index: int in range(cards.size() - 1, -1, -1):
			if _column_faces[cards[index].id].get_global_rect().has_point(point):
				return cards[index]
		return null
	if _collection_scroll.get_global_rect().has_point(point):
		for card: DeckbuilderCard in _sample.collection.cards():
			var face: CardFace = _collection_faces[card.id]
			if face.visible and face.get_global_rect().has_point(point):
				return card
	return null


## The column a card released at [param point] goes to, or NO_COLUMN outside the columns.
func column_at(point: Vector2) -> int:
	var strip: Rect2 = layout().deck()
	if not strip.has_point(point):
		return WorkingDeck.NO_COLUMN
	return clampi(floori((point.x - strip.position.x) / strip.size.x * WorkingDeck.COLUMN_COUNT),
			0, WorkingDeck.COLUMN_COUNT - 1)


## The left button goes down at [param point].
func press_at(point: Vector2) -> void:
	_put_down()
	_pressed = card_at(point)
	_press_point = point


## The cursor moves to [param point]. With a card pressed, this picks it up once it has
## moved far enough, and then carries it.
func drag_to(point: Vector2) -> void:
	if _pressed == null:
		return
	if _held == null:
		if point.distance_to(_press_point) < DRAG_START:
			return
		if not _lift():
			_pressed = null
			return
	_held.position = point - _held.size / 2.0
	_show_drop_column(column_at(point))


## The left button comes up at [param point]: a held card is dropped there.
func release_at(point: Vector2) -> void:
	var card: DeckbuilderCard = _pressed
	if _held == null:
		_pressed = null
		return
	var column: int = column_at(point)
	if column != WorkingDeck.NO_COLUMN:
		if _working_deck.contains(card):
			_working_deck.move(card, column)
		else:
			_working_deck.add(card, column)
	elif _working_deck.contains(card):
		_working_deck.remove(card)
	_put_down()
	_show_deck()


## A double-click at [param point]: a Collection card joins the Deck in its own column, and
## a card in the Deck leaves it.
func double_click_at(point: Vector2) -> void:
	_put_down()
	var card: DeckbuilderCard = card_at(point)
	if card == null:
		return
	if _working_deck.contains(card):
		_working_deck.remove(card)
	else:
		_working_deck.add_to_own_column(card)
	_show_deck()


func _input(event: InputEvent) -> void:
	if _working_deck == null:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if not button.pressed:
			release_at(button.position)
		elif button.double_click:
			double_click_at(button.position)
		else:
			press_at(button.position)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		drag_to(motion.position)


## Picks the pressed card up. False if it cannot be: a Collection card that is already in
## the Deck is moved from its column, not from the Collection pane.
func _lift() -> bool:
	var source: CardFace = _source_face(_pressed, _press_point)
	if source == null:
		return false
	_held = CardFace.new()
	_held.setup(_pressed.look(), source.size.y)
	_held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_held)
	source.modulate.a = LIFTED_DIM
	return true


## The face the pressed card is lifted from, or null if it may not be lifted from there.
func _source_face(card: DeckbuilderCard, point: Vector2) -> CardFace:
	if not _working_deck.contains(card):
		return _collection_faces[card.id]
	return _column_faces[card.id] if column_at(point) != WorkingDeck.NO_COLUMN else null


## Ends a press and frees the held face. The faces are put right by _show_deck().
func _put_down() -> void:
	_pressed = null
	if _held != null:
		_held.queue_free()
		_held = null
		_show_deck()
	_show_drop_column(WorkingDeck.NO_COLUMN)


func _show_drop_column(column: int) -> void:
	if column == _drop_column:
		return
	_drop_column = column
	for index: int in _column_panes.size():
		var style: StyleBoxFlat = _column_panes[index].get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = DROP_BORDER if index == column else PANE_BORDER
		style.set_border_width_all(2 if index == column else 1)


## Shows the Working Deck as it is now: the columns, which Collection cards are dimmed,
## and the size in the top bar. Faces are kept; nothing is rebuilt.
func _show_deck() -> void:
	_lay_out_columns()
	_lay_out_collection(false)
	_show_count()


func _show_count() -> void:
	_count_label.text = "%d / %d cards" % [_working_deck.size(), WorkingDeck.MINIMUM_SIZE]
	_count_label.add_theme_color_override("font_color", Color.WHITE if _working_deck.is_legal() else ILLEGAL)


func count_label() -> Label:
	return _count_label


func name_box() -> LineEdit:
	return _name_box


func filter_bar() -> FilterBar:
	return _filter_bar


## The search, filters and sort order the Collection pane is showing.
func collection_filter() -> CollectionFilter:
	return _filter


## Shows [param filter] in the bar and the Collection pane.
func show_filter(filter: CollectionFilter) -> void:
	_filter = filter
	_redraw()


func _redraw() -> void:
	if _root != null:
		_root.queue_free()
	_column_faces.clear()
	_collection_faces.clear()
	_column_panes.clear()
	_column_scrolls.clear()
	_column_fans.clear()
	_column_counts.clear()
	_land_buttons.clear()
	_pressed = null
	_held = null
	_drop_column = WorkingDeck.NO_COLUMN
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	if _working_deck == null:
		return
	var places: DeckbuilderLayout = layout()
	_draw_top_bar(places.top_bar())
	_draw_inspector(places)
	_draw_filter_bar(places.filter_bar())
	_draw_collection(places)
	for column: int in WorkingDeck.COLUMN_COUNT:
		_draw_column(places, column)
	_lay_out_columns()


func _draw_top_bar(place: Rect2) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_fill(_pane(place), row)
	_name_box = LineEdit.new()
	_name_box.text = _working_deck.name
	_name_box.placeholder_text = "Deck name"
	_name_box.custom_minimum_size = Vector2(360, 0)
	_name_box.add_theme_font_size_override("font_size", 20)
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_name_box)
	_count_label = _label("", 20)
	_count_label.custom_minimum_size = Vector2(150, 0)
	row.add_child(_count_label)
	_show_count()
	row.add_child(_spacer())
	row.add_child(_label("Add a basic land", 16, MUTED))
	for land: String in LAND_SYMBOLS:
		var button: Button = _button("")
		button.icon = ManaSymbols.texture(LAND_SYMBOLS[land])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(44, 0)
		button.tooltip_text = land
		_make_live(button)
		button.pressed.connect(_on_land_pressed.bind(land))
		row.add_child(button)
		_land_buttons[land] = button
	row.add_child(_spacer())
	_sort_button = _button("Sort")
	_sort_button.tooltip_text = "Put every card back in its own column."
	_make_live(_sort_button)
	_sort_button.pressed.connect(_on_sort_pressed)
	row.add_child(_sort_button)
	for text: String in ["Save", "Exit"]:
		row.add_child(_button(text))


func _on_land_pressed(land: String) -> void:
	_working_deck.add_basic_land(land)
	_show_deck()


func _on_sort_pressed() -> void:
	_working_deck.sort()
	_show_deck()


func _draw_inspector(places: DeckbuilderLayout) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_fill(_pane(places.inspector()), column)
	if _inspected == null:
		column.add_child(_label("Hover or right-click a card to read it here.", 16, MUTED))
		return
	var face: CardFace = CardFace.new()
	face.setup(_inspected.look(), places.inspector_card_height())
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(face)
	column.add_child(_label("Mod Slots", 16, MUTED))
	for slot: int in _inspected.mod_slots():
		var filled: bool = slot < _inspected.mods.size()
		var mod: Mod = _inspected.mods[slot] if filled else null
		var text: String = "Empty" if mod == null else "%s%s: %s" % [mod.name, " (Hex)" if mod.is_hex else "", mod.description]
		var line: Label = _label(text, 15, MUTED if mod == null else Color.WHITE)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	column.add_child(_button("Modify"))
	column.add_child(_label("What its abilities mean", 16, MUTED))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var reminder: Label = Label.new()
	reminder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reminder.text = _inspected.look().rules_text
	reminder.add_theme_font_size_override("font_size", 15)
	reminder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(reminder)


func _draw_filter_bar(place: Rect2) -> void:
	var owned: Array[DeckbuilderCard] = _sample.collection.cards()
	_filter_bar = FilterBar.new()
	_filter_bar.setup(_filter, _filter.apply(owned).size(), owned.size())
	_filter_bar.changed.connect(_on_filter_changed)
	_fill(_pane(place), _filter_bar, 8.0)


## Only the Collection pane changes with the filter, and its faces are kept: the bar is not
## rebuilt, so typing a search never loses the cursor.
func _on_filter_changed() -> void:
	var shown: int = _lay_out_collection(true)
	_filter_bar.show_count(shown, _sample.collection.cards().size())


func _draw_collection(places: DeckbuilderLayout) -> void:
	_collection_scroll = ScrollContainer.new()
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fill(_pane(places.collection()), _collection_scroll)
	_collection_grid = Control.new()
	_collection_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_scroll.add_child(_collection_grid)
	for card: DeckbuilderCard in _sample.collection.cards():
		var face: CardFace = CardFace.new()
		face.setup(card.look(), DeckbuilderLayout.COLLECTION_CARD_HEIGHT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_collection_grid.add_child(face)
		_collection_faces[card.id] = face
	_lay_out_collection(true)


## Shows the faces the filter lets through, in its order, and hides the rest. Returns how
## many are showing. A change of filter goes back to the top; a change of Deck stays put.
func _lay_out_collection(resets_scroll: bool) -> int:
	var places: DeckbuilderLayout = layout()
	var shown: Array[DeckbuilderCard] = _filter.apply(_sample.collection.cards())
	for face: CardFace in _collection_faces.values():
		face.visible = false
	for index: int in shown.size():
		var face: CardFace = _collection_faces[shown[index].id]
		face.visible = true
		face.position = places.collection_cell(index).position
		face.modulate.a = IN_DECK_DIM if _working_deck.contains(shown[index]) else 1.0
	_collection_grid.custom_minimum_size = Vector2(0, places.collection_grid_height(shown.size()))
	if resets_scroll:
		_collection_scroll.scroll_vertical = 0
	return shown.size()


## Draws a column's pane, heading and the scrolling fan its cards go in.
func _draw_column(places: DeckbuilderLayout, column: int) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var pane: Panel = _pane(places.column(column))
	_fill(pane, box, DeckbuilderLayout.COLUMN_PAD)
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, DeckbuilderLayout.COLUMN_HEADER - 4.0)
	box.add_child(header)
	header.add_child(_label(COLUMN_TITLES[column], 20))
	header.add_child(_spacer())
	var count: Label = _label("", 18, MUTED)
	header.add_child(count)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var fan: Control = Control.new()
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(fan)
	_column_panes.append(pane)
	_column_scrolls.append(scroll)
	_column_fans.append(fan)
	_column_counts.append(count)


## Puts every Deck card's face in its column's fan, in order, making a face for a card that
## has just come in and freeing the face of one that has left.
func _lay_out_columns() -> void:
	var places: DeckbuilderLayout = layout()
	var in_deck: Dictionary[int, bool] = {}
	for column: int in WorkingDeck.COLUMN_COUNT:
		var cards: Array[DeckbuilderCard] = _working_deck.cards_in(column)
		var fan: Control = _column_fans[column]
		for index: int in cards.size():
			var card: DeckbuilderCard = cards[index]
			in_deck[card.id] = true
			var face: CardFace = _column_faces.get(card.id, null) as CardFace
			if face == null:
				face = CardFace.new()
				face.setup(card.look(), places.column_card_height())
				face.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_column_faces[card.id] = face
			if face.get_parent() != fan:
				if face.get_parent() != null:
					face.get_parent().remove_child(face)
				fan.add_child(face)
			fan.move_child(face, index)
			face.position = Vector2(0, places.fan_offset(index))
			face.modulate.a = 1.0
		fan.custom_minimum_size = Vector2(0, places.fan_height(cards.size()))
		_column_counts[column].text = str(cards.size())
	for id: int in _column_faces.keys():
		if not in_deck.has(id):
			_column_faces[id].queue_free()
			_column_faces.erase(id)


## A bordered pane at [param place], added to the screen.
func _pane(place: Rect2) -> Panel:
	var pane: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANE
	style.border_color = PANE_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	pane.add_theme_stylebox_override("panel", style)
	pane.position = place.position
	pane.size = place.size
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pane)
	return pane


## Puts [param content] inside [param pane], [param pad] in from every edge.
func _fill(pane: Panel, content: Control, pad: float = DeckbuilderLayout.PAD) -> void:
	content.position = Vector2(pad, pad)
	content.size = pane.size - 2.0 * Vector2(pad, pad)
	pane.add_child(content)


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Lets a button made by _button() take clicks.
func _make_live(button: Button) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE


## A button that looks live but takes no clicks yet.
func _button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(84, 0)
	button.add_theme_font_size_override("font_size", 18)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer
