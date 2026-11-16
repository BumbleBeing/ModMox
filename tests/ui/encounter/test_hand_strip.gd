extends GutTest
## The Hand Strip (game glossary, 13j): the Hero's hand as the Encounter Screen draws it,
## driven here from a hand-built HandShow with no engine. What a card's click would do is
## handed to it; it says what the Hero did and plays nothing itself.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const SCREEN: Vector2 = Vector2(1920, 1080)
const FIELD: Vector2 = Vector2(1000, 500)
## Card Identities for the seven cards of the hand.
const CARDS: Array[int] = [101, 102, 103, 104, 105, 106, 107]
const PLAY_ANSWER: int = 7
const CAST_ANSWER: int = 8

var _regions: Dictionary[String, Rect2] = EncounterLayout.regions(SCREEN)
var _strip: HandStrip
var _drag_layer: Control


func before_each() -> void:
	_strip = HandStrip.new()
	_strip.size = SCREEN
	add_child_autofree(_strip)
	_drag_layer = Control.new()
	_drag_layer.size = SCREEN
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child_autofree(_drag_layer)
	_strip.setup(_drag_layer)


# --- Drawing the hand ---


func test_the_hand_is_drawn_in_the_heros_order_fanned_and_deaf_to_the_mouse() -> void:
	_strip.show_hand(_seven())

	assert_eq(_strip.order(), CARDS, "New cards join at the right end, in the order they came.")
	var first: CardFace = _strip.face_of(CARDS[0])
	assert_eq(first.pivot_offset, Vector2(first.size.x / 2.0, first.size.y), "A card turns about the middle of its bottom edge.")
	assert_eq(first.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(first.get_parent(), _strip)
	assert_almost_eq(first.rotation, EncounterLayout.fan_angle(0, 7), 0.0001)
	assert_eq(first.position, EncounterLayout.hand_rest(7, _regions["hero_hand"], first.size)[0])
	assert_true(_is_left_to_right(CARDS))


func test_a_card_new_to_the_hand_joins_at_the_right_and_the_hand_closes_up_when_one_leaves() -> void:
	_strip.show_hand(_seven())
	_strip.show_hand(_hand_of([108, 101, 102, 103, 104, 105, 106, 107]))
	assert_eq(_strip.order(), [101, 102, 103, 104, 105, 106, 107, 108] as Array[int])

	_strip.show_hand(_hand_of([101, 102, 104, 105, 106, 107, 108]))
	assert_eq(_strip.order(), [101, 102, 104, 105, 106, 107, 108] as Array[int])
	assert_null(_strip.face_of(103))


func test_showing_the_hand_again_keeps_each_face_where_it_is() -> void:
	_strip.show_hand(_seven())
	var face: CardFace = _strip.face_of(CARDS[2])
	face.position += Vector2(0, -20)
	var was: Vector2 = face.position
	var easing: HandShow = _seven()
	easing.is_easing = true

	_strip.show_hand(easing)

	assert_eq(_strip.face_of(CARDS[2]), face, "The same face: nothing was rebuilt.")
	assert_eq(face.position, was, "While the hand eases it carries on from where it was.")
	_strip.show_hand(_seven())
	assert_almost_eq(face.position, EncounterLayout.hand_rest(7, _regions["hero_hand"], face.size)[2], Vector2(0.01, 0.01), "Otherwise it is put at its place at once.")


func test_a_rewind_puts_a_card_back_where_it_was() -> void:
	_strip.show_hand(_seven())
	_strip.show_hand(_hand_of([101, 102, 104, 105, 106, 107]))

	var rewind: HandShow = _seven()
	rewind.is_rewind = true
	_strip.show_hand(rewind)

	assert_eq(_strip.order(), CARDS, "A canceled cast or an undo puts it where it was.")


func test_a_card_chosen_to_be_discarded_rests_a_quarter_of_its_height_higher() -> void:
	var hand: HandShow = _seven()
	hand.raised = [CARDS[3]]
	_strip.show_hand(hand)
	_settle()

	var size: Vector2 = _strip.face_of(CARDS[0]).size
	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, _regions["hero_hand"], size)
	assert_almost_eq(_strip.face_of(CARDS[3]).position.y, rest[3].y - size.y * EncounterLayout.PICKED_RISE, 0.5, "A401.")
	assert_almost_eq(_strip.face_of(CARDS[2]).position.y, rest[2].y, 0.5)


func test_a_card_shown_again_with_another_glow_keeps_its_face_and_takes_the_new_glow() -> void:
	_strip.show_hand(_seven())
	var face: CardFace = _strip.face_of(CARDS[0])
	assert_eq(BorderEffects.glow_color(face), _green())

	var hand: HandShow = _hand_of(CARDS, false)
	hand.glows[CARDS[0]] = [Color.WHITE] as Array[Color]
	_strip.show_hand(hand)

	assert_eq(_strip.face_of(CARDS[0]), face)
	assert_eq(BorderEffects.glow_color(face), Color.WHITE)
	assert_null(BorderEffects.glow_color(_strip.face_of(CARDS[1])))


# --- Cards on their way in ---


func test_cards_still_flying_in_are_left_out_of_the_row_and_each_lands_after_those_before_it() -> void:
	var hand: HandShow = _hand_of([101, 102, 103, 104, 105, 106, 107])
	hand.arriving = [106, 107]
	_strip.show_hand(hand)

	assert_eq(_row(), [101, 102, 103, 104, 105] as Array[int])
	assert_null(_strip.face_of(106))
	var size: Vector2 = _strip.face_of(101).size
	var six: Array[Vector2] = EncounterLayout.hand_rest(6, _regions["hero_hand"], size)
	assert_almost_eq(_strip.rest_of(106).center, _middle(six[5], EncounterLayout.fan_angle(5, 6), size), Vector2(0.5, 0.5), "The first lands as the sixth card.")
	var seven: Array[Vector2] = EncounterLayout.hand_rest(7, _regions["hero_hand"], size)
	assert_almost_eq(_strip.rest_of(107).center, _middle(seven[6], EncounterLayout.fan_angle(6, 7), size), Vector2(0.5, 0.5), "The second as the seventh, with the first already there.")
	assert_eq(_strip.rest_of(107).height, size.y)

	hand.arriving = [107]
	_strip.show_hand(hand)
	assert_eq(_row(), [101, 102, 103, 104, 105, 106] as Array[int], "A card joins the row when it has landed.")


func test_cards_the_opening_overlay_is_still_flying_keep_their_places_but_are_not_shown() -> void:
	var hand: HandShow = _seven()
	hand.hidden = [CARDS[1], CARDS[4]]
	_strip.show_hand(hand)

	assert_eq(_row(), CARDS)
	assert_false(_strip.face_of(CARDS[1]).visible)
	assert_true(_strip.face_of(CARDS[2]).visible)
	var size: Vector2 = _strip.face_of(CARDS[0]).size
	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, _regions["hero_hand"], size)
	assert_almost_eq(_strip.rest_of(CARDS[4]).center, _middle(rest[4], EncounterLayout.fan_angle(4, 7), size), Vector2(0.5, 0.5))

	hand.hidden = []
	_strip.show_hand(hand)
	assert_true(_strip.face_of(CARDS[1]).visible)


func test_a_card_not_shown_yet_takes_no_press_and_is_under_no_cursor() -> void:
	var hand: HandShow = _seven()
	hand.hidden = [CARDS[6]]
	_strip.show_hand(hand)
	var face: CardFace = _strip.face_of(CARDS[6])
	# Near its right edge, where no other card lies.
	var point: Vector2 = face.get_transform() * Vector2(face.size.x - 12.0, 40.0)

	assert_eq(_strip.card_under(point), DragCard.NONE)
	assert_false(_strip.press(point, false))


# --- What the cursor is on ---


func test_the_card_under_the_cursor_is_the_one_drawn_there_and_a_risen_one_is_on_top() -> void:
	_strip.show_hand(_seven())
	var at: Vector2 = _on(CARDS[3])

	assert_eq(_strip.card_under(at), CARDS[3])
	assert_eq(_strip.card_under(FIELD), DragCard.NONE)
	_strip.face_of(CARDS[2]).z_index = 1
	var overlap: Vector2 = _strip.face_of(CARDS[3]).get_transform() * Vector2(6, 60)
	assert_eq(_strip.card_under(overlap), CARDS[2], "A raised card is drawn over the rest.")


func test_where_a_card_is_drawn_is_its_face_held_or_not() -> void:
	_strip.show_hand(_seven())
	var face: CardFace = _strip.face_of(CARDS[1])
	var place: FacePose = _strip.place_of(CARDS[1])
	assert_almost_eq(place.center, face.get_transform() * (face.size / 2.0), Vector2(0.01, 0.01))
	assert_eq(place.height, face.size.y)

	_strip.press(_on(CARDS[1]), false)
	_strip.drag_to(FIELD)
	assert_almost_eq(_strip.place_of(CARDS[1]).center, face.position + face.size / 2.0, Vector2(0.01, 0.01), "A held card flies from where it is held.")
	assert_null(_strip.place_of(999))


func test_the_card_under_the_cursor_is_lit_and_the_hand_parts_around_it() -> void:
	_strip.show_hand(_seven())
	# Well inside the part of the card no other covers, since the card moves under it.
	var at: Vector2 = _strip.face_of(CARDS[2]).get_transform() * Vector2(40, 70)
	var rest: Vector2 = _strip.face_of(CARDS[3]).position

	for frame: int in 30:
		_strip.frame(1.0 / 60.0, at)

	assert_ne(_strip.face_of(CARDS[3]).position, rest, "The hand parts under the cursor.")
	assert_eq(_strip.face_of(CARDS[2]).z_index, 1, "The card under it comes to the front.")
	assert_almost_eq(_strip.face_of(CARDS[2]).modulate.r, HandStrip.HOVER_LIGHT.r, 0.01)
	assert_almost_eq(_strip.face_of(CARDS[1]).modulate.r, 1.0, 0.01)


func test_the_hand_eases_as_far_in_one_slow_frame_as_in_the_frames_it_replaced() -> void:
	_strip.show_hand(_seven())
	_strip.press(_on(CARDS[5]), false)
	_strip.release(_on(CARDS[0]))
	var face: CardFace = _strip.face_of(CARDS[5])
	var from: Vector2 = face.position
	var to: Vector2 = EncounterLayout.hand_rest(7, _regions["hero_hand"], face.size)[0]

	_strip.frame(3.0 / 60.0, Vector2.ZERO)

	assert_almost_eq(face.position, from.lerp(to, 0.657), Vector2(0.5, 0.5))
	assert_eq(HandStrip.EASE, 0.3)


func test_a_hand_of_more_than_seven_eases_a_little_more_slowly_for_each_card_past_seven() -> void:
	assert_eq(HandStrip.ease_for(5), HandStrip.EASE)
	assert_eq(HandStrip.ease_for(7), HandStrip.EASE)
	assert_almost_eq(HandStrip.ease_for(8), 0.2625, 0.0001)
	assert_almost_eq(HandStrip.ease_for(10), 0.21, 0.0001)
	assert_eq(HandStrip.ease_for(40), HandStrip.CALMEST_EASE, "But never slower than this.")

	_strip.show_hand(_hand_of([101, 102, 103, 104, 105, 106, 107, 108]))
	var face: CardFace = _strip.face_of(101)
	var from: Vector2 = face.position
	var cursor: Vector2 = _on(104)
	var to: Vector2 = EncounterLayout.hand_spread_within(EncounterLayout.hand_rest(8, _regions["hero_hand"], face.size), face.size, cursor, _regions["hero_hand"])[0]

	_strip.frame(1.0 / 60.0, cursor)

	assert_almost_eq(face.position, from.lerp(to, 0.2625), Vector2(0.01, 0.01))


# --- Pressing and clicking ---


func test_one_click_on_a_card_says_it_was_clicked_and_plays_nothing() -> void:
	_strip.show_hand(_seven())
	watch_signals(_strip)

	assert_true(_strip.press(_on(CARDS[0]), false), "The press landed on a card.")
	_strip.release(_on(CARDS[0]))

	assert_signal_emitted_with_parameters(_strip, "clicked", [CARDS[0]])
	assert_signal_not_emitted(_strip, "answered", "A371.")
	assert_false(_strip.is_pressing())
	assert_eq(_strip.held(), DragCard.NONE)


func test_a_press_off_the_hand_is_not_a_press_on_a_card_but_a_card_is_a_little_bigger_to_the_mouse() -> void:
	_strip.show_hand(_seven())
	var first: CardFace = _strip.face_of(CARDS[0])
	var rise: float = first.size.y * EncounterLayout.HAND_RISE

	assert_false(_strip.press(FIELD, false))
	assert_false(_strip.press(FIELD, true))
	assert_false(_strip.is_pressing())
	assert_true(_strip.press(first.position + Vector2(30, -5), false), "A card is a little bigger to the mouse than it looks.")
	_strip.cancel()
	assert_true(_strip.press(first.position + Vector2(30, -rise - 7.0), false), "Above it too, where it rises to under the cursor.")
	_strip.cancel()
	assert_false(_strip.press(first.position + Vector2(30, -rise - 9.0), false), "But no higher than it rises.")


func test_a_press_made_before_the_hand_has_caught_up_with_the_cursor_still_finds_the_card() -> void:
	_strip.show_hand(_seven())
	var face: CardFace = _strip.face_of(CARDS[6])
	var spread: Vector2 = EncounterLayout.hand_spread_within(EncounterLayout.hand_rest(7, _regions["hero_hand"], face.size), face.size, face.position + Vector2(face.size.x - 10.0, 30.0), _regions["hero_hand"])[6]

	assert_true(_strip.press(spread + Vector2(face.size.x - 12.0, 30.0), false), "The card counts where the cursor is sending it.")
	assert_eq(_strip.pressed(), CARDS[6])


func test_a_double_click_on_a_card_with_one_way_to_be_played_answers_at_once() -> void:
	_strip.show_hand(_seven())
	watch_signals(_strip)

	_strip.press(_on(CARDS[0]), true)

	assert_signal_emitted_with_parameters(_strip, "answered", [PLAY_ANSWER])
	assert_false(_strip.is_pressing(), "A double-click starts no drag.")


func test_a_double_click_on_a_card_with_several_ways_asks_for_the_option_menu_at_the_card() -> void:
	var hand: HandShow = _seven()
	hand.options[CARDS[1]] = [ClickOption.new(CAST_ANSWER, "Bears"), ClickOption.new(CAST_ANSWER + 1, "Bears, kicked")] as Array[ClickOption]
	_strip.show_hand(hand)
	watch_signals(_strip)
	var at: Vector2 = _on(CARDS[1])

	_strip.press(at, true)

	assert_signal_emitted(_strip, "menu_wanted")
	var asked: Array = get_signal_parameters(_strip, "menu_wanted")
	assert_eq((asked[0] as Array).size(), 2)
	assert_eq(asked[1], at)
	assert_signal_not_emitted(_strip, "answered")


func test_a_double_click_on_a_card_that_cannot_be_played_is_a_press_like_any_other() -> void:
	var hand: HandShow = _seven()
	hand.options.erase(CARDS[0])
	_strip.show_hand(hand)
	watch_signals(_strip)

	assert_true(_strip.press(_on(CARDS[0]), true))

	assert_signal_not_emitted(_strip, "answered")
	assert_signal_not_emitted(_strip, "menu_wanted")
	assert_true(_strip.is_pressing(), "A second try at a drag is not swallowed.")


# --- Dragging ---


func test_a_press_becomes_a_drag_after_three_pixels_and_lifts_the_cards_own_face() -> void:
	_strip.show_hand(_seven())
	var face: CardFace = _strip.face_of(CARDS[0])
	var at: Vector2 = _on(CARDS[0])
	var grabbed: Vector2 = at - face.position
	face.z_index = 1

	_strip.press(at, false)
	_strip.drag_to(at + Vector2(2, 0))
	assert_eq(_strip.held(), DragCard.NONE)
	assert_eq(face.get_parent(), _strip)
	_strip.drag_to(at + Vector2(0, -3))

	assert_eq(_strip.held(), CARDS[0])
	assert_eq(face.get_parent(), _drag_layer, "Nothing was rebuilt: its own face is lifted above the windows.")
	assert_eq(face.z_index, 0, "A card that had risen must not be drawn over the Option Menu.")
	assert_eq(face.rotation, 0.0, "Upright.")
	assert_eq(face.position, at + Vector2(0, -3) - grabbed, "Under the cursor as it was grabbed.")
	assert_false(_row().has(CARDS[0]), "It is out of the row.")
	assert_eq(_row().size(), 6)
	_strip.drag_to(Vector2(1200, 300))
	assert_eq(face.position, Vector2(1200, 300) - grabbed)


func test_the_hand_makes_room_where_the_held_card_hovers_and_closes_up_above_the_strip() -> void:
	_strip.show_hand(_seven())
	var hand: Rect2 = _regions["hero_hand"]
	var size: Vector2 = _strip.face_of(CARDS[0]).size
	var seven: Array[Vector2] = EncounterLayout.hand_rest(7, hand, size)
	_strip.press(_on(CARDS[3]), false)

	_strip.drag_to(seven[1] + Vector2(size.x / 2.0, 60))
	_settle()
	assert_almost_eq(_strip.face_of(CARDS[1]).position, seven[2], Vector2(0.5, 0.5), "The others ease to make room.")
	assert_almost_eq(_strip.face_of(CARDS[1]).rotation, EncounterLayout.fan_angle(2, 7), 0.001)
	assert_almost_eq(_strip.face_of(CARDS[0]).position, seven[0], Vector2(0.5, 0.5))

	_strip.drag_to(FIELD)
	_settle()
	assert_almost_eq(_strip.face_of(CARDS[1]).position, EncounterLayout.hand_rest(6, hand, size)[1], Vector2(0.5, 0.5), "Above the strip they close up.")


func test_the_hand_does_not_part_around_the_cursor_while_a_card_is_held() -> void:
	_strip.show_hand(_seven())
	_strip.press(_on(CARDS[5]), false)
	_strip.drag_to(FIELD)
	_settle()
	var before: Vector2 = _strip.face_of(CARDS[2]).position

	_settle(_on(CARDS[2]))

	assert_almost_eq(_strip.face_of(CARDS[2]).position, before, Vector2(0.5, 0.5))


func test_a_card_let_go_over_the_strip_is_put_down_where_the_hand_made_room() -> void:
	_strip.show_hand(_seven())
	var size: Vector2 = _strip.face_of(CARDS[0]).size
	var seven: Array[Vector2] = EncounterLayout.hand_rest(7, _regions["hero_hand"], size)
	var face: CardFace = _strip.face_of(CARDS[5])
	watch_signals(_strip)
	_strip.press(_on(CARDS[5]), false)

	_strip.release(seven[1] + Vector2(size.x / 2.0, 60))

	var order: Array[int] = [CARDS[0], CARDS[5], CARDS[1], CARDS[2], CARDS[3], CARDS[4], CARDS[6]]
	assert_eq(_strip.order(), order)
	assert_eq(_row(), order)
	assert_eq(_strip.face_of(CARDS[5]), face, "The same face went back into the row.")
	assert_eq(face.get_parent(), _strip)
	assert_eq(face.get_index(), _strip.face_of(CARDS[0]).get_index() + 1, "Drawn over the card to its left")
	assert_eq(face.get_index(), _strip.face_of(CARDS[1]).get_index() - 1, "and under the one to its right.")
	assert_eq(_strip.held(), DragCard.NONE)
	assert_signal_not_emitted(_strip, "answered", "Rearranging answers nothing.")
	assert_signal_not_emitted(_strip, "clicked")
	_settle()
	assert_almost_eq(face.position, seven[1], Vector2(0.5, 0.5), "It eases into its place from where it was let go.")
	assert_almost_eq(face.rotation, EncounterLayout.fan_angle(1, 7), 0.001)
	_strip.show_hand(_seven())
	assert_eq(_strip.order(), order, "Showing the hand again keeps the Hero's order.")


func test_a_card_let_go_past_either_end_or_over_the_info_panel_goes_to_that_end() -> void:
	_strip.show_hand(_seven())

	_strip.press(_on(CARDS[2]), false)
	_strip.release(_regions["info"].get_center())
	assert_eq(_strip.order()[0], CARDS[2], "The Info Panel is in the strip (A382).")
	assert_eq(_strip.face_of(CARDS[2]).get_index(), _strip.face_of(CARDS[0]).get_index() - 1, "Drawn under the card that was first.")

	_settle()
	_strip.press(_on(CARDS[2]), false)
	_strip.release(Vector2(_regions["hero_hand"].end.x + 100.0, 1000))
	assert_eq(_strip.order()[6], CARDS[2])
	assert_eq(_strip.face_of(CARDS[2]).get_index(), _strip.face_of(CARDS[6]).get_index() + 1, "Drawn over the card that was last.")


func test_a_playable_card_let_go_above_the_strip_is_let_go_of_and_then_answers() -> void:
	_strip.show_hand(_seven())
	watch_signals(_strip)
	var held_when_answered: Array[int] = []
	_strip.answered.connect(func(_answer: int) -> void: held_when_answered.append(_strip.held()))

	_strip.press(_on(CARDS[0]), false)
	_strip.release(FIELD)

	assert_signal_emitted_with_parameters(_strip, "answered", [PLAY_ANSWER])
	assert_eq(held_when_answered, [DragCard.NONE] as Array[int], "The answer brings a redraw, accepted or refused, and nothing may stay held (A378).")

	_strip.press(_on(CARDS[1]), false)
	_strip.release(_regions["hero_graveyard"].get_center())
	assert_signal_emitted_with_parameters(_strip, "answered", [CAST_ANSWER], 1)


func test_a_card_that_cannot_be_played_goes_back_to_its_place_without_a_word() -> void:
	var hand: HandShow = _seven()
	hand.options.erase(CARDS[0])
	hand.glows.erase(CARDS[0])
	_strip.show_hand(hand)
	watch_signals(_strip)

	_strip.press(_on(CARDS[0]), false)
	_strip.drag_to(FIELD)
	assert_null(BorderEffects.glow_color(_strip.face_of(CARDS[0])), "It does not glow.")
	_strip.release(FIELD)

	assert_signal_not_emitted(_strip, "answered", "A380: silently.")
	assert_eq(_strip.order(), CARDS)
	assert_eq(_row(), CARDS)
	assert_eq(_strip.held(), DragCard.NONE)


func test_held_where_letting_go_would_play_it_a_card_glows_brighter_and_says_what_it_offers() -> void:
	_strip.show_hand(_seven())
	var face: CardFace = _strip.face_of(CARDS[0])
	var at: Vector2 = _on(CARDS[0])
	watch_signals(_strip)
	_strip.press(at, false)

	_strip.drag_to(at + Vector2(0, -5))
	assert_eq(BorderEffects.glow_color(face), _green(), "Over the strip it glows as it did")
	assert_signal_not_emitted(_strip, "offer_changed", "and offers nothing.")

	_strip.drag_to(FIELD)
	assert_eq(BorderEffects.glow_color(face), DecisionClicks.bright_color_of(DecisionClicks.Kind.PLAY))
	assert_eq((get_signal_parameters(_strip, "offer_changed")[0] as ClickOption).answer, PLAY_ANSWER)

	_strip.drag_to(at)
	assert_eq(BorderEffects.glow_color(face), _green())
	assert_null(get_signal_parameters(_strip, "offer_changed")[0])

	_strip.drag_to(FIELD)
	_strip.cancel()
	assert_eq(BorderEffects.glow_color(face), _green(), "Back in the hand it glows as before")
	assert_null(get_signal_parameters(_strip, "offer_changed")[0], "and offers nothing.")


func test_moving_over_the_left_panels_lets_go_of_the_card() -> void:
	_strip.show_hand(_seven())
	watch_signals(_strip)
	_strip.press(_on(CARDS[0]), false)
	_strip.drag_to(FIELD)

	_strip.drag_to(_regions["hero_panel"].get_center())

	assert_eq(_strip.held(), DragCard.NONE, "A371: before any release.")
	assert_eq(_row(), CARDS)
	_strip.release(_regions["hero_panel"].get_center())
	assert_signal_not_emitted(_strip, "answered")
	_strip.drag_to(FIELD)
	assert_eq(_strip.held(), DragCard.NONE, "The drag is over: moving on picks nothing up.")


func test_canceling_puts_a_held_card_back_and_lets_go_of_a_press() -> void:
	_strip.show_hand(_seven())
	_strip.press(_on(CARDS[2]), false)
	_strip.drag_to(FIELD)

	_strip.cancel()
	assert_eq(_strip.held(), DragCard.NONE)
	assert_eq(_row(), CARDS)
	assert_eq(_strip.face_of(CARDS[2]).get_parent(), _strip)

	_settle()
	_strip.press(_on(CARDS[2]), false)
	_strip.cancel()
	assert_false(_strip.is_pressing(), "A press that never became a drag is let go of too.")


func test_a_held_card_stays_held_while_the_hand_is_shown_again() -> void:
	_strip.show_hand(_seven())
	_strip.press(_on(CARDS[2]), false)
	_strip.drag_to(FIELD)
	var face: CardFace = _strip.face_of(CARDS[2])

	_strip.show_hand(_seven())

	assert_eq(_strip.held(), CARDS[2], "A380.")
	assert_eq(_strip.face_of(CARDS[2]), face)
	assert_eq(face.get_parent(), _drag_layer)


func test_showing_the_hand_again_keeps_the_room_made_for_a_held_card() -> void:
	_strip.show_hand(_seven())
	var size: Vector2 = _strip.face_of(CARDS[0]).size
	var seven: Array[Vector2] = EncounterLayout.hand_rest(7, _regions["hero_hand"], size)
	_strip.press(_on(CARDS[3]), false)
	_strip.drag_to(seven[1] + Vector2(size.x / 2.0, 60))

	_strip.show_hand(_seven())
	_settle(seven[1] + Vector2(size.x / 2.0, 60))

	assert_almost_eq(_strip.face_of(CARDS[1]).position, seven[2], Vector2(0.5, 0.5))


func test_a_held_card_that_leaves_the_hand_is_no_longer_held() -> void:
	_strip.show_hand(_seven())
	_strip.press(_on(CARDS[2]), false)
	_strip.drag_to(FIELD)

	_strip.show_hand(_hand_of([101, 102, 104, 105, 106, 107]))

	assert_eq(_strip.held(), DragCard.NONE)
	assert_eq(_drag_layer.get_child_count(), 0, "Nothing is left under the cursor.")


func test_a_card_with_several_ways_to_be_played_waits_where_it_was_let_go_for_the_option_menu() -> void:
	var hand: HandShow = _seven()
	hand.options[CARDS[1]] = [ClickOption.new(CAST_ANSWER, "Bears"), ClickOption.new(CAST_ANSWER + 1, "Bears, kicked")] as Array[ClickOption]
	_strip.show_hand(hand)
	var face: CardFace = _strip.face_of(CARDS[1])
	var grabbed: Vector2 = _on(CARDS[1]) - face.position
	watch_signals(_strip)
	_strip.press(_on(CARDS[1]), false)

	_strip.release(FIELD)

	assert_signal_emitted(_strip, "menu_wanted")
	assert_eq(get_signal_parameters(_strip, "menu_wanted")[1], FIELD, "A372: the menu opens where it was let go")
	assert_eq(_strip.held(), CARDS[1], "and the card waits there.")
	assert_eq(face.get_parent(), _drag_layer)
	_strip.drag_to(Vector2(200, 200))
	assert_eq(face.position, FIELD - grabbed, "A waiting card does not follow the cursor.")

	_strip.menu_closed()
	assert_eq(_strip.held(), DragCard.NONE, "The menu closed: the card goes back.")
	assert_eq(_row(), CARDS)


# --- Helpers ---


## Seven cards, each glowing green and played with one answer: a Forest with PLAY_ANSWER,
## and Grizzly Bears with CAST_ANSWER.
func _seven() -> HandShow:
	return _hand_of(CARDS)


func _hand_of(cards: Array[int], is_playable: bool = true) -> HandShow:
	var hand: HandShow = HandShow.new()
	hand.regions = _regions
	var forest: CardLook = CardLook.of_definition(load(ALPHA % "forest") as MmCardDefinition)
	var bears: CardLook = CardLook.of_definition(load(ALPHA % "grizzly_bears") as MmCardDefinition)
	for card_id: int in cards:
		var is_forest: bool = card_id % 2 == 1
		var options: Array[ClickOption] = []
		var glow: Array[Color] = []
		var held_glow: Array[Color] = []
		if is_playable:
			options.append(ClickOption.new(PLAY_ANSWER if is_forest else CAST_ANSWER, "Forest" if is_forest else "Grizzly Bears"))
			glow.append(_green())
			held_glow.append(DecisionClicks.bright_color_of(DecisionClicks.Kind.PLAY))
		hand.add(card_id, forest if is_forest else bears, options, glow, held_glow)
	return hand


func _green() -> Color:
	return DecisionClicks.color_of(DecisionClicks.Kind.PLAY)


## A point on the part of the card that no other card covers, where it is drawn.
func _on(card_id: int) -> Vector2:
	return _strip.face_of(card_id).get_transform() * _on_offset()


func _on_offset() -> Vector2:
	return Vector2(14, 40)


## The cards of the row, left to right, as their faces are ordered among the strip's children.
func _row() -> Array[int]:
	var row: Array[int] = []
	for card_id: int in _strip.order():
		var face: CardFace = _strip.face_of(card_id)
		if face != null and face.get_parent() == _strip:
			row.append(card_id)
	return row


func _is_left_to_right(cards: Array[int]) -> bool:
	for index: int in range(1, cards.size()):
		if _strip.face_of(cards[index]).position.x <= _strip.face_of(cards[index - 1]).position.x:
			return false
		if _strip.face_of(cards[index]).get_index() <= _strip.face_of(cards[index - 1]).get_index():
			return false
	return true


## Lets the hand ease all the way to where it belongs, with the cursor at [param cursor].
func _settle(cursor: Vector2 = Vector2.ZERO) -> void:
	for frame: int in 120:
		_strip.frame(1.0 / 60.0, cursor)


## The middle of a hand card whose top left corner rests at [param corner], turned by
## [param turn] about the middle of its bottom edge.
func _middle(corner: Vector2, turn: float, size: Vector2) -> Vector2:
	return corner + Vector2(size.x / 2.0, size.y) + Vector2(0.0, -size.y / 2.0).rotated(turn)
