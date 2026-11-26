extends GutTest
## The Hero's half-made answer to a look at the top cards of their library (game ADR 0085):
## the cards in a row, top first; one that may be taken selected at a time; the selected one
## taken into the hand, while fewer than the most have been; undo takes back the last card
## taken, and the answer is the cards taken. When the rest go to the bottom in any order, as
## Faerie Mechanist's do, the row is ordered by moving cards, undo takes back a move too, and
## the answer is the cards taken and then the row, leftmost first and rightmost deepest.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID


func test_it_covers_a_look_and_starts_with_the_cards_in_library_order() -> void:
	var choice: LookChoice = LookChoice.new(_look([11, 12, 13, 14], [12, 14]))

	assert_true(LookChoice.covers(_look([11], [])))
	assert_false(LookChoice.covers(PriorityDecision.new(HERO, [PassAction.new()] as Array[MmAction])))
	assert_true(choice.is_active())
	assert_false(LookChoice.new().is_active())
	assert_eq(choice.count(), 4)
	assert_eq(choice.row(), [11, 12, 13, 14] as Array[int])
	assert_eq(choice.taken(), [] as Array[int])
	assert_eq(choice.picked(), LookChoice.NONE)
	assert_eq(choice.answer(), [], "Done at once takes nothing.")


func test_only_a_card_that_may_be_taken_can_be_selected_and_a_second_click_lets_it_go() -> void:
	var choice: LookChoice = LookChoice.new(_look([11, 12, 13], [12]))

	assert_false(choice.can_pick(11))
	assert_true(choice.can_pick(12))
	choice.pick(11)
	assert_eq(choice.picked(), LookChoice.NONE, "Not one that may be taken.")
	choice.pick(12)
	assert_eq(choice.picked(), 12)
	choice.pick(12)

	assert_eq(choice.picked(), LookChoice.NONE)
	assert_false(choice.can_undo(), "Selecting changes no answer.")


func test_taking_the_selected_card_takes_it_out_of_the_row_and_then_no_other_may_be_taken() -> void:
	var choice: LookChoice = LookChoice.new(_look([11, 12, 13], [11, 13]))
	choice.pick(13)

	assert_eq(choice.take_picked(), 13)

	assert_eq(choice.row(), [11, 12] as Array[int])
	assert_eq(choice.taken(), [13] as Array[int])
	assert_eq(choice.picked(), LookChoice.NONE)
	assert_false(choice.can_pick(11), "Up to one, and one is taken.")
	assert_eq(choice.answer(), [13])
	assert_eq(choice.take_picked(), LookChoice.NONE, "Nothing selected.")


func test_undo_takes_back_the_card_taken() -> void:
	var choice: LookChoice = LookChoice.new(_look([11, 12, 13], [12]))
	choice.pick(12)
	choice.take_picked()
	assert_true(choice.can_undo())

	assert_true(choice.undo())

	assert_eq(choice.row(), [11, 12, 13] as Array[int], "Back in its place.")
	assert_eq(choice.taken(), [] as Array[int])
	assert_true(choice.can_pick(12))
	assert_false(choice.undo())


func test_it_is_for_its_own_decision_only() -> void:
	var look: ChooseLookedAtCardsDecision = _look([11], [11])
	var choice: LookChoice = LookChoice.new(look)

	assert_true(choice.is_for(look))
	assert_false(choice.is_for(_look([11], [11])))


func test_in_a_random_order_the_row_cannot_be_moved() -> void:
	var choice: LookChoice = LookChoice.new(_look([11, 12, 13], [12]))

	assert_false(choice.orders_rest())
	assert_false(choice.move_to(0, 2))

	assert_eq(choice.row(), [11, 12, 13] as Array[int])


func test_in_any_order_a_move_reorders_the_row_and_the_answer_puts_it_on_the_bottom_in_that_order() -> void:
	var choice: LookChoice = LookChoice.new(_ordered_look([11, 12, 13], [12]))
	assert_true(choice.orders_rest())
	assert_eq(choice.answer(), [[], [11, 12, 13]], "Done at once keeps the order looked at.")

	assert_true(choice.move_to(0, 2))
	choice.pick(12)
	choice.take_picked()

	assert_eq(choice.row(), [13, 11] as Array[int])
	assert_eq(choice.answer(), [[12], [13, 11]])


func test_in_any_order_undo_takes_back_a_move_as_well_as_a_card_taken() -> void:
	var choice: LookChoice = LookChoice.new(_ordered_look([11, 12, 13], [12]))
	choice.pick(12)
	choice.take_picked()
	assert_true(choice.move_to(1, 0))
	assert_eq(choice.row(), [13, 11] as Array[int])

	assert_true(choice.undo())
	assert_eq(choice.row(), [11, 13] as Array[int], "The move is taken back first.")
	assert_eq(choice.taken(), [12] as Array[int])
	assert_true(choice.undo())

	assert_eq(choice.row(), [11, 12, 13] as Array[int])
	assert_eq(choice.taken(), [] as Array[int])


func _ordered_look(card_ids: Array[int], candidate_ids: Array[int]) -> ChooseLookedAtCardsDecision:
	var decision: ChooseLookedAtCardsDecision = _look(card_ids, candidate_ids)
	decision.orders_rest = true
	return decision


func _look(card_ids: Array[int], candidate_ids: Array[int]) -> ChooseLookedAtCardsDecision:
	return ChooseLookedAtCardsDecision.new(HERO, 99, card_ids, candidate_ids, 1, null)
