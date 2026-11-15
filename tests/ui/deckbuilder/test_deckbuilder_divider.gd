extends GutTest
## The Divider between the Collection and the deck columns: dragging it gives one pane the
## height the other loses, it stops at both limits, a double-click puts it back, and it
## leaves the cards alone.

var _sample: Run
var _screen: DeckbuilderScreen
var _deck: WorkingDeck


func before_each() -> void:
	_sample = DeckbuilderSample.make()
	_screen = DeckbuilderScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_sample, _sample.deckbox.active())
	_deck = _screen.working_deck()
	await wait_process_frames(2)


func after_each() -> void:
	await wait_process_frames(2)


func test_dragging_the_divider_resizes_both_panes_live_and_keeps_every_face() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var in_column: DeckbuilderCard = _deck.cards_in(1)[0]
	var collection_face: CardFace = _screen.collection_face(lions)
	var column_face: CardFace = _screen.column_face(in_column)
	var collection: float = _screen.collection_pane().size.y
	var column: float = _screen.column_pane(0).size.y
	var from: Vector2 = _on_divider()

	_screen._input(_button_event(from, true))
	_screen._input(_motion_event(from + Vector2(0, 100)))

	assert_almost_eq(_screen.collection_pane().size.y, collection + 100.0, 0.01, "It follows the cursor before it is let go.")
	assert_almost_eq(_screen.collection_scroll().size.y, collection + 100.0 - 2.0 * DeckbuilderLayout.PAD, 0.01)
	assert_almost_eq(_screen.deck_scroll().position.y, _screen.layout().deck().position.y, 0.01)
	for index: int in WorkingDeck.COLUMN_COUNT:
		assert_almost_eq(_screen.column_pane(index).size.y, column - 100.0, 0.01, "Column %d is shorter." % index)
	assert_eq(_screen.collection_face(lions), collection_face, "No face is rebuilt.")
	assert_eq(_screen.column_face(in_column), column_face)
	assert_almost_eq(_screen.collection_face(lions).get_global_rect().size.y, DeckbuilderLayout.COLLECTION_CARD_HEIGHT, 0.01)

	_screen._input(_button_event(from + Vector2(0, 100), false))

	assert_almost_eq(_screen.layout().collection().size.y, collection + 100.0, 0.01, "It stays where it was let go.")
	assert_eq(_screen.column_face(in_column), column_face)


func test_the_divider_stops_at_both_limits() -> void:
	var from: Vector2 = _on_divider()
	_screen.press_at(from)

	_screen.drag_to(Vector2(from.x, 0))
	assert_almost_eq(_screen.collection_pane().size.y, _screen.layout().shortest_collection(), 0.01)

	_screen.drag_to(Vector2(from.x, 1080))
	assert_almost_eq(_screen.collection_pane().size.y, _screen.layout().tallest_collection(), 0.01)
	_screen.release_at(Vector2(from.x, 1080))


func test_a_double_click_on_the_divider_puts_it_back() -> void:
	_drag(_on_divider(), _on_divider() + Vector2(0, 150))
	var moved: Vector2 = _on_divider()

	_screen._input(_button_event(moved, true))
	_screen._input(_button_event(moved, false))
	_screen._input(_button_event(moved, true, true))
	_screen._input(_button_event(moved, false))

	assert_almost_eq(_screen.collection_pane().size.y, DeckbuilderLayout.DEFAULT_COLLECTION_HEIGHT, 0.01)
	assert_almost_eq(_screen.column_pane(0).size.y, _screen.layout().column(0).size.y, 0.01)


func test_a_press_on_the_divider_picks_up_no_card_and_clears_nothing() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.right_click_at(_in_collection(lions))
	assert_eq(_screen.selected(), lions)
	# Just inside the Collection pane, over a card's bottom edge, is still the Divider.
	var from: Vector2 = _on_divider() - Vector2(0, DeckbuilderLayout.GUTTER / 2.0 + 2.0)

	_screen.press_at(from)
	_screen.drag_to(from + Vector2(0, 80))

	assert_null(_screen.held_face())
	assert_eq(_screen.drop_column(), WorkingDeck.NO_COLUMN)
	_screen.release_at(from + Vector2(0, 80))
	assert_eq(_screen.selected(), lions)
	assert_eq(_deck.cards().size(), 40)
	assert_almost_eq(_screen.collection_pane().size.y, DeckbuilderLayout.DEFAULT_COLLECTION_HEIGHT + 80.0, 0.01)


func test_a_carried_card_passes_over_the_divider() -> void:
	var card: DeckbuilderCard = _deck.cards_in(1)[0]
	var from: Vector2 = _screen.column_face(card).global_position + Vector2(40, 8)

	_screen.press_at(from)
	_screen.drag_to(_on_divider())

	assert_not_null(_screen.held_face())
	assert_eq(_screen.drop_column(), WorkingDeck.NO_COLUMN)
	_screen.release_at(_on_divider())
	assert_false(_deck.contains(card), "Let go on the gutter, it leaves the Deck as anywhere outside the columns.")
	assert_almost_eq(_screen.collection_pane().size.y, DeckbuilderLayout.DEFAULT_COLLECTION_HEIGHT, 0.01)


func test_the_divider_shows_the_resize_cursor_and_its_grip_brightens_while_hovered_or_dragged() -> void:
	assert_eq(_screen.divider().mouse_default_cursor_shape, Control.CURSOR_VSIZE)
	var dim: Color = _screen.divider_grip_color()

	_screen.drag_to(_on_divider())
	assert_gt(_screen.divider_grip_color().v, dim.v, "Hovered.")

	_screen.drag_to(Vector2(170, 900))
	assert_eq(_screen.divider_grip_color(), dim)

	_screen.press_at(_on_divider())
	_screen.drag_to(Vector2(_on_divider().x, 1000))
	assert_gt(_screen.divider_grip_color().v, dim.v, "Dragged, though the cursor has gone past it.")

	_screen.release_at(Vector2(_on_divider().x, 1000))
	_screen.drag_to(Vector2(170, 900))
	assert_eq(_screen.divider_grip_color(), dim)


func test_the_divider_is_kept_through_a_redraw_and_a_new_deckbuilder_starts_at_the_default() -> void:
	_drag(_on_divider(), _on_divider() + Vector2(0, 90))
	var moved: float = DeckbuilderLayout.DEFAULT_COLLECTION_HEIGHT + 90.0

	_screen.show_filter(CollectionFilter.new())
	assert_almost_eq(_screen.collection_pane().size.y, moved, 0.01, "A change of filter redraws the screen.")

	_screen.zoom_deck(1.4)
	assert_almost_eq(_screen.collection_pane().size.y, moved, 0.01)
	assert_almost_eq(_screen.column_pane(0).size.y, _screen.layout().column(0).size.y, 0.01)

	var other: DeckbuilderScreen = DeckbuilderScreen.new()
	other.starts_itself = false
	add_child_autofree(other)
	other.set_deferred("size", Vector2(1920, 1080))
	await wait_process_frames(1)
	other.begin(_sample, _sample.deckbox.active())
	assert_almost_eq(other.collection_pane().size.y, DeckbuilderLayout.DEFAULT_COLLECTION_HEIGHT, 0.01)


func test_the_divider_is_flat_and_the_columns_are_shaded_again_for_their_height_once_it_is_let_go() -> void:
	for node: Node in _screen.divider().find_children("*", "Panel", true, false):
		assert_null((node as Panel).get_theme_stylebox("panel") as StyleBoxTexture, "Flat: no Dither Shading.")
	var painted: int = (_screen.column_pane(0).get_theme_stylebox("panel") as StyleBoxTexture).texture.get_height()
	var from: Vector2 = _on_divider()

	_screen.press_at(from)
	_screen.drag_to(from + Vector2(0, 120))
	assert_eq((_screen.column_pane(0).get_theme_stylebox("panel") as StyleBoxTexture).texture.get_height(), painted,
			"While it is dragged the shading is only stretched, which is quick.")

	_screen.release_at(from + Vector2(0, 120))
	for index: int in WorkingDeck.COLUMN_COUNT:
		var pane: Panel = _screen.column_pane(index)
		var face: StyleBoxTexture = pane.get_theme_stylebox("panel") as StyleBoxTexture
		assert_eq(face.texture.get_height(), int(pane.size.y), "Column %d is shaded for its new height." % index)


func test_the_collection_keeps_its_scroll_where_it_can() -> void:
	var scroll: ScrollContainer = _screen.collection_scroll()
	scroll.scroll_vertical = 300
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, 300)

	_drag(_on_divider(), _on_divider() + Vector2(0, 60))
	await wait_process_frames(2)
	assert_eq(scroll.scroll_vertical, 300, "Taller, it still shows the same cards at the top.")

	scroll.scroll_vertical = 1000000
	await wait_process_frames(2)
	var bottom: int = scroll.scroll_vertical
	_drag(_on_divider(), Vector2(_on_divider().x, 1080))
	await wait_process_frames(2)
	var room: float = scroll.size.y
	assert_almost_eq(float(scroll.scroll_vertical), _screen.collection_grid().custom_minimum_size.y - room, 1.0,
			"Scrolled to the bottom, it shows the bottom still: as far as it can go.")
	assert_lt(scroll.scroll_vertical, bottom)


## The middle of the Divider, where it is now.
func _on_divider() -> Vector2:
	return _screen.layout().divider().get_center()


func _drag(from: Vector2, to: Vector2) -> void:
	_screen.press_at(from)
	_screen.drag_to(to)
	_screen.release_at(to)


func _in_collection(card: DeckbuilderCard) -> Vector2:
	return _screen.collection_face(card).get_global_rect().get_center()


## A plain copy of the card named [param card_name] that is not in the Deck and is showing
## in the first row of the Collection pane.
func _spare(card_name: String) -> DeckbuilderCard:
	for card: DeckbuilderCard in _sample.collection.cards():
		if card.run_card.base.name == card_name and card.mods.is_empty():
			return card
	return null


func _button_event(point: Vector2, is_pressed: bool, is_double: bool = false) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = is_pressed
	event.double_click = is_double
	event.position = point
	return event


func _motion_event(point: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	return event
