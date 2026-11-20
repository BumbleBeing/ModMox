extends GutTest
## The Hero's half-made answer to a surveil (game ADR 0069): the cards in a row, leftmost on
## top, ordered by moves; one selected at a time; the selected one sent to the graveyard;
## undo takes back the last move or sending, and the answer is the cards sent, in the order
## sent, then the row.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID


func test_it_covers_a_surveil_and_starts_with_the_cards_in_library_order() -> void:
	var choice: SurveilChoice = SurveilChoice.new(_surveil([11, 12, 13]))

	assert_true(SurveilChoice.covers(_surveil([11])))
	assert_false(SurveilChoice.covers(PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])))
	assert_true(choice.is_active())
	assert_false(SurveilChoice.new().is_active())
	assert_eq(choice.row(), [11, 12, 13] as Array[int])
	assert_eq(choice.sent(), [] as Array[int])
	assert_eq(choice.picked(), SurveilChoice.NONE)
	assert_eq(choice.answer(), [[], [11, 12, 13]], "Done at once keeps every card in order.")


func test_a_click_selects_a_card_and_a_second_lets_it_go() -> void:
	var choice: SurveilChoice = SurveilChoice.new(_surveil([11, 12]))

	choice.pick(12)
	assert_eq(choice.picked(), 12)
	choice.pick(11)
	assert_eq(choice.picked(), 11, "One at a time.")
	choice.pick(11)

	assert_eq(choice.picked(), SurveilChoice.NONE)
	assert_false(choice.can_undo(), "Selecting changes no answer.")


func test_sending_the_selected_card_takes_it_out_of_the_row() -> void:
	var choice: SurveilChoice = SurveilChoice.new(_surveil([11, 12, 13]))
	choice.pick(13)

	assert_eq(choice.send_picked(), 13)
	choice.pick(11)
	assert_eq(choice.send_picked(), 11)

	assert_eq(choice.row(), [12] as Array[int])
	assert_eq(choice.sent(), [13, 11] as Array[int])
	assert_eq(choice.picked(), SurveilChoice.NONE)
	assert_eq(choice.answer(), [[13, 11], [12]], "In the order sent: the last is the newest.")


func test_with_nothing_selected_nothing_is_sent() -> void:
	var choice: SurveilChoice = SurveilChoice.new(_surveil([11]))

	assert_eq(choice.send_picked(), SurveilChoice.NONE)
	assert_eq(choice.row(), [11] as Array[int])


func test_a_move_puts_a_card_at_its_new_place_and_the_rest_make_room() -> void:
	var choice: SurveilChoice = SurveilChoice.new(_surveil([11, 12, 13]))

	assert_true(choice.move_to(0, 2))

	assert_eq(choice.row(), [12, 13, 11] as Array[int])
	assert_false(choice.move_to(1, 1), "Where it is already is no move.")
	assert_false(choice.move_to(0, 3), "Nor is a place past the row.")


func test_undo_takes_back_the_last_sending_or_move_one_at_a_time() -> void:
	var choice: SurveilChoice = SurveilChoice.new(_surveil([11, 12, 13]))
	choice.move_to(2, 0)
	choice.pick(12)
	choice.send_picked()

	assert_true(choice.undo())
	assert_eq(choice.row(), [13, 11, 12] as Array[int], "The card comes back to its place.")
	assert_eq(choice.sent(), [] as Array[int])
	assert_true(choice.undo())
	assert_eq(choice.row(), [11, 12, 13] as Array[int])
	assert_false(choice.undo())
	assert_false(choice.can_undo())


func test_it_is_for_the_decision_it_was_made_for() -> void:
	var asked: SurveilDecision = _surveil([11])
	var choice: SurveilChoice = SurveilChoice.new(asked)

	assert_true(choice.is_for(asked))
	assert_false(choice.is_for(_surveil([11])))
	assert_eq(choice.count(), 1)


func _surveil(ids: Array[int]) -> SurveilDecision:
	return SurveilDecision.new(HERO, 5, ids)
