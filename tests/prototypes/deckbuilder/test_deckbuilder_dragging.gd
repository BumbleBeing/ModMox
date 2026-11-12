extends GutTest
## Building a Deck with the mouse: dragging cards into, between and out of the columns,
## double-clicking them in and out, and the basic land and Sort buttons.

const OUTSIDE: Vector2 = Vector2(170, 900)

var _sample: DeckbuilderSample
var _screen: DeckbuilderScreen
var _deck: WorkingDeck


func before_each() -> void:
	_sample = DeckbuilderSample.make()
	_screen = DeckbuilderScreen.new()
	_screen.starts_itself = false
	add_child_autofree(_screen)
	_screen.size = Vector2(1920, 1080)
	_screen.begin(_sample)
	_deck = _screen.working_deck()
	await wait_process_frames(2)


func after_each() -> void:
	await wait_process_frames(2)


func test_the_card_at_a_point_is_the_one_whose_face_is_on_top_there() -> void:
	var column: Array[DeckbuilderCard] = _deck.cards_in(1)

	assert_eq(_screen.card_at(_strip_of(column[0])), column[0])
	assert_eq(_screen.card_at(_strip_of(column[2])), column[2])
	assert_eq(_screen.card_at(_middle_of_last(1)), column[-1], "The last card of a column shows in full.")
	assert_eq(_screen.card_at(_in_collection(_spare("Serra Angel"))), _spare("Serra Angel"))
	assert_null(_screen.card_at(OUTSIDE))


func test_dragging_a_collection_card_onto_a_column_adds_it_there() -> void:
	var angel: DeckbuilderCard = _spare("Serra Angel")

	_drag(_in_collection(angel), _column_point(2))

	assert_eq(_deck.column_of(angel), 2, "It stays where it was dropped, not where its cost says.")
	assert_not_null(_screen.column_face(angel))
	assert_eq(_screen.count_label().text, "41 / 40 cards")
	assert_eq(_screen.collection_face(angel).modulate.a, DeckbuilderScreen.IN_DECK_DIM)
	assert_null(_screen.held_face())


func test_a_card_is_not_picked_up_until_the_cursor_has_moved_a_little() -> void:
	var from: Vector2 = _in_collection(_spare("Serra Angel"))
	_screen.press_at(from)

	_screen.drag_to(from + Vector2(3, 0))
	assert_null(_screen.held_face())

	_screen.drag_to(from + Vector2(30, 0))
	assert_not_null(_screen.held_face())
	assert_almost_eq(_screen.held_face().get_global_rect().get_center(), from + Vector2(30, 0), Vector2(0.01, 0.01))
	assert_eq(_screen.collection_face(_spare("Serra Angel")).modulate.a, DeckbuilderScreen.LIFTED_DIM)

	_screen.release_at(from + Vector2(30, 0))
	assert_false(_deck.contains(_spare("Serra Angel")), "Dropped back on the Collection, it is not added.")
	assert_eq(_screen.collection_face(_spare("Serra Angel")).modulate.a, 1.0)


func test_the_column_a_held_card_would_drop_into_is_marked() -> void:
	_screen.press_at(_in_collection(_spare("Serra Angel")))

	_screen.drag_to(_column_point(4))
	assert_eq(_screen.drop_column(), 4)

	_screen.drag_to(OUTSIDE)
	assert_eq(_screen.drop_column(), WorkingDeck.NO_COLUMN)

	_screen.release_at(OUTSIDE)


func test_dragging_between_columns_moves_the_card_and_keeps_its_face() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]
	var face: CardFace = _screen.column_face(bolt)

	_drag(_strip_of(bolt), _column_point(5))

	assert_eq(_deck.column_of(bolt), 5)
	assert_eq(_screen.column_face(bolt), face, "The face is moved, not rebuilt.")
	assert_eq(_deck.size(), 40)
	assert_true(_screen.layout().column(5).has_point(face.global_position + Vector2(2, 2)))


func test_dragging_a_deck_card_out_of_the_columns_removes_it() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]

	_drag(_strip_of(bolt), OUTSIDE)

	assert_false(_deck.contains(bolt))
	assert_null(_screen.column_face(bolt))
	assert_eq(_screen.collection_face(bolt).modulate.a, 1.0, "It is no longer dimmed in the Collection.")
	assert_eq(_screen.count_label().text, "39 / 40 cards")
	assert_eq(_screen.count_label().get_theme_color("font_color"), DeckbuilderScreen.ILLEGAL)


func test_a_card_already_in_the_deck_cannot_be_dragged_from_the_collection() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]
	_screen.filter_bar().search_box().text = "bolt"
	_screen.filter_bar().search_box().text_changed.emit("bolt")

	_drag(_in_collection(bolt), _column_point(6))

	assert_eq(_deck.column_of(bolt), 1)


func test_double_clicking_a_collection_card_adds_it_to_its_own_column() -> void:
	var angel: DeckbuilderCard = _spare("Serra Angel")

	_screen.double_click_at(_in_collection(angel))

	assert_eq(_deck.column_of(angel), 5)


func test_double_clicking_a_deck_card_removes_it() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]

	_screen.double_click_at(_strip_of(bolt))

	assert_false(_deck.contains(bolt))


func test_double_clicking_a_dimmed_collection_card_takes_it_out_of_the_deck() -> void:
	var angel: DeckbuilderCard = _spare("Serra Angel")
	_screen.double_click_at(_in_collection(angel))

	_screen.double_click_at(_in_collection(angel))

	assert_false(_deck.contains(angel))


func test_a_basic_land_button_adds_one_land_and_it_leaves_like_any_card() -> void:
	_screen.land_button("Swamp").pressed.emit()

	var lands: Array[DeckbuilderCard] = _deck.cards_in(WorkingDeck.LANDS_COLUMN)
	var swamp: DeckbuilderCard = lands[-1]
	assert_eq(swamp.look().name, "Swamp")
	assert_eq(lands.size(), 18)
	assert_not_null(_screen.column_face(swamp))
	assert_eq(_screen.count_label().text, "41 / 40 cards")
	await wait_process_frames(2)

	_drag(_strip_of(lands[0]), OUTSIDE)

	assert_eq(_deck.cards_in(WorkingDeck.LANDS_COLUMN).size(), 17)


func test_sort_puts_a_hand_placed_card_back_in_its_own_column() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]
	_drag(_strip_of(bolt), _column_point(5))

	_screen.sort_button().pressed.emit()

	assert_eq(_deck.column_of(bolt), 1)
	assert_true(_screen.layout().column(1).has_point(_screen.column_face(bolt).global_position + Vector2(2, 2)))


func test_real_mouse_events_drag_a_card() -> void:
	var angel: DeckbuilderCard = _spare("Serra Angel")
	var from: Vector2 = _in_collection(angel)

	_screen._input(_button_event(from, true))
	_screen._input(_motion_event(_column_point(3)))
	_screen._input(_button_event(_column_point(3), false))

	assert_eq(_deck.column_of(angel), 3)

	_screen._input(_button_event(from, true, true))

	assert_false(_deck.contains(angel), "A double-click takes it out again.")


func _drag(from: Vector2, to: Vector2) -> void:
	_screen.press_at(from)
	_screen.drag_to(to)
	_screen.release_at(to)


## A point on the name strip of a Deck card, which shows even under the cards after it.
func _strip_of(card: DeckbuilderCard) -> Vector2:
	return _screen.column_face(card).global_position + Vector2(40, 8)


func _middle_of_last(column: int) -> Vector2:
	return _screen.column_face(_deck.cards_in(column)[-1]).get_global_rect().get_center()


func _in_collection(card: DeckbuilderCard) -> Vector2:
	return _screen.collection_face(card).get_global_rect().get_center()


## A point low in [param column], under its cards.
func _column_point(column: int) -> Vector2:
	var place: Rect2 = _screen.layout().column(column)
	return Vector2(place.get_center().x, place.end.y - 20.0)


## A plain copy of the card named [param card_name] that is not in the Deck and is showing
## in the first rows of the Collection pane.
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
