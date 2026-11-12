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
	assert_eq(_screen.card_at(_in_collection(_spare("Savannah Lions"))), _spare("Savannah Lions"))
	assert_null(_screen.card_at(OUTSIDE))


func test_dragging_a_collection_card_onto_a_column_adds_it_there() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")

	_drag(_in_collection(lions), _column_point(2))

	assert_eq(_deck.column_of(lions), 2, "It stays where it was dropped, not where its cost says.")
	assert_not_null(_screen.column_face(lions))
	assert_eq(_screen.count_label().text, "41 / 40 cards")
	assert_eq(_screen.collection_face(lions).modulate.a, DeckbuilderScreen.IN_DECK_DIM)
	assert_null(_screen.held_face())


func test_a_card_is_not_picked_up_until_the_cursor_has_moved_a_little() -> void:
	var from: Vector2 = _in_collection(_spare("Savannah Lions"))
	_screen.press_at(from)

	_screen.drag_to(from + Vector2(3, 0))
	assert_null(_screen.held_face())

	_screen.drag_to(from + Vector2(30, 0))
	assert_not_null(_screen.held_face())
	assert_almost_eq(_screen.held_face().get_global_rect().get_center(), from, Vector2(0.01, 0.01),
			"It starts where it lay and does not jump to the cursor.")
	_screen._process(0.02)
	var on_the_way: float = _screen.held_face().get_global_rect().get_center().x
	assert_between(on_the_way, from.x + 1.0, from.x + 29.0, "It glides to the cursor.")
	_screen._process(1.0)
	assert_almost_eq(_screen.held_face().get_global_rect().get_center(), from + Vector2(30, 0), Vector2(0.01, 0.01))
	assert_eq(_screen.collection_face(_spare("Savannah Lions")).modulate.a, DeckbuilderScreen.LIFTED_DIM)

	_screen.release_at(from + Vector2(30, 0))
	assert_false(_deck.contains(_spare("Savannah Lions")), "Dropped back on the Collection, it is not added.")
	assert_eq(_screen.collection_face(_spare("Savannah Lions")).modulate.a, 1.0)


func test_the_column_a_held_card_would_drop_into_is_marked() -> void:
	_screen.press_at(_in_collection(_spare("Savannah Lions")))

	_screen.drag_to(_column_point(4))
	assert_eq(_screen.drop_column(), 4)
	assert_eq(_screen.column_light(4), 0.0, "Its border eases in, it does not snap.")
	_screen._process(0.02)
	assert_between(_screen.column_light(4), 0.05, 0.95)
	_screen._process(1.0)
	assert_almost_eq(_screen.column_light(4), 1.0, 0.01)

	_screen.drag_to(OUTSIDE)
	assert_eq(_screen.drop_column(), WorkingDeck.NO_COLUMN)
	_screen._process(1.0)
	assert_almost_eq(_screen.column_light(4), 0.0, 0.01)

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
	var lions: DeckbuilderCard = _spare("Savannah Lions")

	_screen.double_click_at(_in_collection(lions))

	assert_eq(_deck.column_of(lions), 1)


func test_double_clicking_a_deck_card_removes_it() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]

	_screen.double_click_at(_strip_of(bolt))

	assert_false(_deck.contains(bolt))


func test_double_clicking_a_dimmed_collection_card_takes_it_out_of_the_deck() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.double_click_at(_in_collection(lions))

	_screen.double_click_at(_in_collection(lions))

	assert_false(_deck.contains(lions))


func test_the_card_under_the_cursor_glows_and_the_glow_eases() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var face: CardFace = _screen.collection_face(lions)

	_screen.drag_to(_in_collection(lions))
	assert_eq(_screen.hovered_face(), face)
	_screen._process(0.02)
	assert_between(_screen.glow_of(face), 0.05, 0.95)
	_screen._process(1.0)
	assert_almost_eq(_screen.glow_of(face), 1.0, 0.01)

	_screen.drag_to(_strip_of(_deck.cards_in(1)[0]))
	assert_eq(_screen.hovered_face(), _screen.column_face(_deck.cards_in(1)[0]))
	_screen._process(1.0)
	assert_almost_eq(_screen.glow_of(face), 0.0, 0.01, "The glow fades from the card the cursor left.")

	_screen.drag_to(OUTSIDE)
	assert_null(_screen.hovered_face())


func test_a_dropped_card_glides_to_its_place_in_the_column() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var drop: Vector2 = _column_point(2)
	_screen.press_at(_in_collection(lions))
	_screen.drag_to(drop)
	_screen._process(1.0)

	_screen.release_at(drop)

	var seat: CardFace = _screen.column_face(lions)
	var flying: CardFace = _screen.flyer(lions)
	assert_not_null(flying)
	assert_almost_eq(flying.get_global_rect().get_center(), drop, Vector2(0.5, 0.5), "It starts where it was let go.")
	assert_eq(seat.modulate.a, 0.0, "Its place in the column is kept, unseen, until it lands.")
	_screen._process(0.02)
	assert_between(flying.global_position.y, seat.global_position.y + 1.0, drop.y)
	_screen._process(1.0)
	assert_null(_screen.flyer(lions))
	assert_eq(seat.modulate.a, 1.0)
	await wait_process_frames(2)


func test_a_double_clicked_card_glides_from_the_collection_to_its_column() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var from: Vector2 = _screen.collection_face(lions).global_position
	_screen.set_process(false)

	_screen.double_click_at(_in_collection(lions))

	assert_almost_eq(_screen.flyer(lions).global_position, from, Vector2(0.01, 0.01))
	_screen._process(1.0)
	assert_null(_screen.flyer(lions))
	assert_eq(_screen.column_face(lions).modulate.a, 1.0)
	await wait_process_frames(2)


func test_a_double_clicked_card_goes_to_the_bottom_of_its_column() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")

	_screen.double_click_at(_in_collection(lions))

	assert_eq(_deck.cards_in(1)[-1], lions, "Nothing is sorted: it goes under the cards already there.")


func test_the_cards_under_a_held_card_slide_down_to_leave_a_gap() -> void:
	var pile: Array[DeckbuilderCard] = _deck.cards_in(1)
	var step: float = _screen.layout().fan_step()
	_screen.set_process(false)
	_screen.press_at(_in_collection(_spare("Savannah Lions")))

	_screen.drag_to(_strip_of(pile[2]) + Vector2(0, -6))

	assert_eq(_screen.drop_column(), 1)
	assert_eq(_screen.drop_place(), 2, "Over the top of the third card's strip, it would go above that card.")
	assert_almost_eq(_screen.column_face(pile[2]).position.y, 2.0 * step, 0.01, "Nothing has jumped.")
	_screen._process(1.0)
	assert_almost_eq(_screen.column_face(pile[1]).position.y, step, 0.01)
	assert_almost_eq(_screen.column_face(pile[2]).position.y, 3.0 * step, 0.01, "It and those under it move down one place.")
	assert_almost_eq(_screen.column_face(pile[-1]).position.y, pile.size() * step, 0.01)

	_screen.drag_to(OUTSIDE)
	_screen._process(1.0)
	assert_almost_eq(_screen.column_face(pile[2]).position.y, 2.0 * step, 0.01, "The gap closes when it leaves.")
	_screen.release_at(OUTSIDE)


func test_a_card_dropped_on_a_gap_goes_in_at_that_place() -> void:
	var pile: Array[DeckbuilderCard] = _deck.cards_in(1)
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var drop: Vector2 = _strip_of(pile[2]) + Vector2(0, -6)

	_drag(_in_collection(lions), drop)

	var names: Array[DeckbuilderCard] = _deck.cards_in(1)
	assert_eq(names.find(lions), 2)
	assert_eq(names[3], pile[2])
	assert_eq(names.size(), pile.size() + 1)
	await wait_process_frames(2)


func test_a_deck_card_can_be_moved_to_another_place_in_its_own_column() -> void:
	var pile: Array[DeckbuilderCard] = _deck.cards_in(1)
	var from: Vector2 = _strip_of(pile[0])
	_screen.set_process(false)
	_screen.press_at(from)

	_screen.drag_to(_middle_of_last(1))
	_screen._process(1.0)
	assert_eq(_screen.column_face(pile[0]).modulate.a, 0.0, "The held card has left its seat.")
	assert_almost_eq(_screen.column_face(pile[1]).position.y, 0.0, 0.01, "The others close up.")
	_screen.release_at(_middle_of_last(1))

	assert_eq(_deck.cards_in(1)[-1], pile[0])
	assert_eq(_deck.cards_in(1)[0], pile[1])
	assert_eq(_deck.size(), 40)
	await wait_process_frames(2)


func test_the_hovered_card_of_a_column_is_drawn_over_the_others() -> void:
	var pile: Array[DeckbuilderCard] = _deck.cards_in(1)

	_screen.drag_to(_strip_of(pile[1]))
	assert_eq(_screen.column_face(pile[1]).z_index, 1)
	assert_eq(_screen.column_face(pile[2]).z_index, 0)

	_screen.drag_to(_strip_of(pile[2]))
	assert_eq(_screen.column_face(pile[1]).z_index, 0)
	assert_eq(_screen.column_face(pile[2]).z_index, 1, "The strip under the cursor decides, not the raised face.")

	_screen.drag_to(_in_collection(_spare("Savannah Lions")))
	assert_eq(_screen.column_face(pile[2]).z_index, 0)
	assert_eq(_screen.collection_face(_spare("Savannah Lions")).z_index, 0)


func test_each_basic_land_button_shows_how_many_are_in_the_deck() -> void:
	assert_eq(_screen.land_count_label("Forest").text, "9")
	assert_eq(_screen.land_count_label("Mountain").text, "8")
	assert_eq(_screen.land_count_label("Island").text, "0")

	_screen.land_button("Island").pressed.emit()
	assert_eq(_screen.land_count_label("Island").text, "1")

	_screen.double_click_at(_strip_of(_deck.cards_in(WorkingDeck.LANDS_COLUMN)[0]))
	assert_eq(_screen.land_count_label("Forest").text, "8", "A Forest was taken out.")
	await wait_process_frames(2)


func test_the_deck_zoom_slider_widens_the_columns_and_the_strip_scrolls_sideways() -> void:
	var bolt: DeckbuilderCard = _deck.cards_in(1)[0]
	var fitted: float = _screen.column_face(bolt).size.y
	assert_false(_screen.layout().columns_overflow())

	_screen.deck_zoom_slider().value = 1.5
	assert_almost_eq(_screen.column_face(bolt).get_global_rect().size.y, fitted * 1.5, 0.01,
			"While the slider moves the faces are scaled.")
	_screen.deck_zoom_slider().drag_ended.emit(true)
	await wait_process_frames(2)

	var places: DeckbuilderLayout = _screen.layout()
	assert_almost_eq(_screen.column_face(bolt).size.y, fitted * 1.5, 0.01, "Let go, they are redrawn sharp.")
	assert_almost_eq(places.column(0).size.x, places.column_card_height() * CardGeometry.ASPECT
			+ 2.0 * DeckbuilderLayout.COLUMN_PAD + DeckbuilderLayout.SCROLL_BAR, 0.01)
	assert_true(places.columns_overflow())
	assert_true(_screen.deck_scroll().get_h_scroll_bar().visible, "The strip scrolls sideways.")
	assert_eq(_screen.column_at(places.column(1).get_center()), 1)

	_screen.deck_scroll().scroll_horizontal = int(places.column_width() + DeckbuilderLayout.COLUMN_GAP)
	await wait_process_frames(2)
	assert_eq(_screen.column_at(places.column(1).get_center()), 2, "Scrolled along by a column, the next one is there.")
	assert_eq(_deck.size(), 40)


func test_a_glowing_card_can_leave_the_deck() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	_screen.double_click_at(_in_collection(lions))
	_screen._process(1.0)
	var strip: Vector2 = _strip_of(lions)
	_screen.drag_to(strip)
	_screen._process(1.0)

	# The face can be freed before the screen's next pass, on a frame with a physics step.
	_screen.set_process(false)
	_screen.double_click_at(strip)
	await wait_process_frames(3)
	_screen._process(0.02)

	assert_null(_screen.column_face(lions))
	assert_null(_screen.hovered_face(), "The face that glowed is gone.")


func test_nothing_glows_while_a_card_is_held() -> void:
	_screen.press_at(_in_collection(_spare("Savannah Lions")))

	_screen.drag_to(_strip_of(_deck.cards_in(1)[0]))

	assert_null(_screen.hovered_face())
	_screen.release_at(OUTSIDE)


func test_the_basic_land_buttons_are_named_for_their_lands() -> void:
	var names: Array[String] = []
	for land: String in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		names.append(_screen.land_button(land).text)

	assert_eq(names, ["+Plains", "+Island", "+Swamp", "+Mountain", "+Forest"] as Array[String])


func test_the_zoom_slider_resizes_the_collection_cards() -> void:
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	assert_almost_eq(_screen.zoom_slider().value, DeckbuilderLayout.COLLECTION_CARD_HEIGHT, 0.01)

	_screen.zoom_slider().value = 180.0
	assert_almost_eq(_screen.collection_face(lions).get_global_rect().size.y, 180.0, 0.01,
			"While the slider moves the faces are scaled.")
	assert_eq(_screen.layout().collection_columns(), 11)

	_screen.zoom_slider().drag_ended.emit(true)
	assert_almost_eq(_screen.collection_face(lions).size.y, 180.0, 0.01, "Let go, they are redrawn sharp.")
	assert_eq(_screen.collection_face(lions).scale, Vector2.ONE)
	assert_eq(_screen.card_at(_in_collection(lions)), lions)
	await wait_process_frames(2)


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
	var lions: DeckbuilderCard = _spare("Savannah Lions")
	var from: Vector2 = _in_collection(lions)

	_screen._input(_button_event(from, true))
	_screen._input(_motion_event(_column_point(3)))
	_screen._input(_button_event(_column_point(3), false))

	assert_eq(_deck.column_of(lions), 3)

	_screen._input(_button_event(from, true, true))

	assert_false(_deck.contains(lions), "A double-click takes it out again.")


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
