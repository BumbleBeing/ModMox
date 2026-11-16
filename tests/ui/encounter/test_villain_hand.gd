extends GutTest
## The Villain Hand (game glossary): the Villain's hand as the Encounter Screen draws it, a
## fan of card backs hanging from the top. Like the Hand Strip it is kept across a redraw,
## so a card that lands in it makes the others ease aside rather than jump.

const SCREEN: Vector2 = Vector2(1920, 1080)

var _hand: VillainHand
var _rect: Rect2 = EncounterLayout.regions(SCREEN)["villain_hand"]
var _card: Vector2 = Vector2(EncounterLayout.VILLAIN_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.VILLAIN_CARD_HEIGHT)


func before_each() -> void:
	_hand = VillainHand.new()
	_hand.size = SCREEN
	add_child_autofree(_hand)


func test_the_hand_is_that_many_card_backs_fanned_from_the_top_and_deaf_to_the_mouse() -> void:
	_hand.show_hand(5, _rect, false)

	assert_eq(_hand.count(), 5)
	var places: Array[Vector2] = EncounterLayout.villain_hand(5, _rect, _card)
	for index: int in 5:
		var back: Control = _hand.back(index)
		assert_eq(back.get_parent(), _hand)
		assert_almost_eq(back.position, places[index], Vector2(0.01, 0.01))
		assert_almost_eq(back.rotation, -EncounterLayout.fan_angle(index, 5), 0.0001)
		assert_eq(back.pivot_offset, Vector2(_card.x / 2.0, 0.0), "It turns about the middle of its top edge.")
	assert_eq(_hand.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_card_that_lands_makes_the_others_ease_aside_and_joins_at_its_place() -> void:
	_hand.show_hand(5, _rect, false)
	var first: Control = _hand.back(0)
	var was: Vector2 = first.position

	_hand.show_hand(6, _rect, true)

	assert_eq(_hand.back(0), first, "The same backs: nothing was rebuilt.")
	assert_eq(first.position, was, "It has not jumped")
	var six: Array[Vector2] = EncounterLayout.villain_hand(6, _rect, _card)
	assert_almost_eq(_hand.back(5).position, six[5], Vector2(0.01, 0.01), "and the new one is where it belongs.")
	_hand.frame(1.0 / 60.0)
	assert_almost_eq(first.position, was.lerp(six[0], HandStrip.EASE), Vector2(0.01, 0.01), "It eases as the Hero's hand does.")
	for frame: int in 120:
		_hand.frame(1.0 / 60.0)
	assert_almost_eq(first.position, six[0], Vector2(0.5, 0.5))
	assert_almost_eq(first.rotation, -EncounterLayout.fan_angle(0, 6), 0.001)


func test_a_redraw_that_is_not_easing_puts_every_back_at_its_place_at_once() -> void:
	_hand.show_hand(5, _rect, false)

	_hand.show_hand(3, _rect, false)

	assert_eq(_hand.count(), 3)
	assert_eq(_hand.get_child_count(), 3)
	var three: Array[Vector2] = EncounterLayout.villain_hand(3, _rect, _card)
	for index: int in 3:
		assert_almost_eq(_hand.back(index).position, three[index], Vector2(0.01, 0.01))


func test_a_larger_hand_eases_more_slowly_as_the_heros_does() -> void:
	_hand.show_hand(8, _rect, false)
	var first: Control = _hand.back(0)
	var was: Vector2 = first.position

	_hand.show_hand(9, _rect, true)
	_hand.frame(1.0 / 60.0)

	var nine: Array[Vector2] = EncounterLayout.villain_hand(9, _rect, _card)
	assert_almost_eq(first.position, was.lerp(nine[0], HandStrip.ease_for(9)), Vector2(0.01, 0.01))


func test_a_drawn_card_lands_where_its_back_will_be_once_those_before_it_have_landed() -> void:
	_hand.show_hand(5, _rect, false)

	var first: FacePose = _hand.landing_place(0)
	var second: FacePose = _hand.landing_place(1)

	assert_almost_eq(first.center, _middle(EncounterLayout.villain_hand(6, _rect, _card)[5], -EncounterLayout.fan_angle(5, 6)), Vector2(0.01, 0.01))
	assert_almost_eq(second.center, _middle(EncounterLayout.villain_hand(7, _rect, _card)[6], -EncounterLayout.fan_angle(6, 7)), Vector2(0.01, 0.01))
	assert_eq(first.height, _card.y)


## The middle of a card back whose top left corner hangs at [param corner], turned by
## [param turn] about the middle of its top edge.
func _middle(corner: Vector2, turn: float) -> Vector2:
	return corner + Vector2(_card.x / 2.0, 0.0) + Vector2(0.0, _card.y / 2.0).rotated(turn)
