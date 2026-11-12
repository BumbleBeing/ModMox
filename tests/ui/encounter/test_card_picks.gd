extends GutTest
## Choosing cards from the hand (13e-2): which to put on the bottom after keeping, and which
## to discard. The Hero's clicks build the answer, and the order clicked is the order given.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const HAND: Array[int] = [11, 12, 13, 14]


func test_it_covers_bottoming_and_discarding_and_nothing_else() -> void:
	assert_true(CardPicks.covers(_bottom(1)))
	assert_true(CardPicks.covers(_discard(1)))
	assert_false(CardPicks.covers(null))
	assert_false(CardPicks.covers(KeepOrMulliganDecision.new(HERO, 0, 0)))
	assert_false(CardPicks.new().is_active())
	assert_true(CardPicks.new(_discard(1)).is_active())
	assert_false(CardPicks.new(KeepOrMulliganDecision.new(HERO, 0, 0)).is_active())


func test_it_is_for_the_decision_it_was_made_for() -> void:
	var decision: ChooseCardsToDiscardDecision = _discard(2)
	var picks: CardPicks = CardPicks.new(decision)

	assert_true(picks.is_for(decision))
	assert_false(picks.is_for(_discard(2)), "Another decision needs new picks.")
	assert_true(CardPicks.new().is_for(null))


func test_cards_are_picked_in_the_order_clicked_and_the_answer_keeps_that_order() -> void:
	var decision: ChooseCardsToBottomDecision = _bottom(2)
	var picks: CardPicks = CardPicks.new(decision)
	assert_false(picks.is_complete())

	assert_true(picks.pick(13))
	assert_false(picks.is_complete())
	assert_true(picks.pick(11))

	assert_true(picks.is_complete())
	assert_eq(picks.picked(), [13, 11] as Array[int])
	assert_eq(picks.answer(), [13, 11], "The last one picked ends up lowest.")
	assert_eq(decision.validate(picks.answer()), "")
	assert_true(picks.is_picked(13))
	assert_false(picks.is_picked(12))


func test_no_more_than_the_count_can_be_picked_and_only_cards_of_the_decision() -> void:
	var picks: CardPicks = CardPicks.new(_discard(2))
	picks.pick(11)
	picks.pick(12)

	assert_false(picks.can_pick(13))
	assert_false(picks.pick(13), "Two are chosen already.")
	assert_eq(picks.picked(), [11, 12] as Array[int])
	var other: CardPicks = CardPicks.new(_discard(2))
	assert_false(other.pick(99), "Not a card of the hand.")
	assert_true(other.pick(11))
	assert_false(other.pick(11), "Already picked.")
	assert_false(CardPicks.new().pick(11), "Nothing is being asked.")


func test_toggling_picks_a_card_and_lets_it_go_again() -> void:
	var picks: CardPicks = CardPicks.new(_discard(2))

	assert_true(picks.toggle(12))
	assert_true(picks.toggle(14))
	assert_true(picks.toggle(12))

	assert_eq(picks.picked(), [14] as Array[int])
	assert_false(picks.toggle(99))
	picks.toggle(11)
	assert_false(picks.toggle(13), "Two are chosen: a third is not picked.")
	assert_eq(picks.picked(), [14, 11] as Array[int])


func test_undo_takes_back_one_click_at_a_time() -> void:
	var picks: CardPicks = CardPicks.new(_discard(2))
	assert_false(picks.can_undo())
	assert_false(picks.undo())
	picks.toggle(12)
	picks.toggle(14)
	picks.toggle(12)

	assert_true(picks.can_undo())
	assert_true(picks.undo())
	assert_eq(picks.picked(), [12, 14] as Array[int], "Letting a card go is a click too.")
	assert_true(picks.undo())
	assert_eq(picks.picked(), [12] as Array[int])
	assert_true(picks.undo())
	assert_eq(picks.picked(), [] as Array[int])
	assert_false(picks.can_undo())


func test_a_click_that_changes_nothing_is_nothing_to_undo() -> void:
	var picks: CardPicks = CardPicks.new(_discard(1))
	picks.pick(11)

	picks.pick(12)
	picks.toggle(13)

	assert_true(picks.undo())
	assert_false(picks.can_undo())


func test_the_prompt_says_what_is_asked_and_how_far_along_it_is() -> void:
	var discard: CardPicks = CardPicks.new(_discard(2))
	assert_eq(discard.prompt(), "Discard 2 cards (0 chosen)")
	discard.pick(11)
	assert_eq(discard.prompt(), "Discard 2 cards (1 chosen)")
	assert_eq(CardPicks.new(_discard(1)).prompt(), "Discard 1 card (0 chosen)")
	assert_eq(CardPicks.new(_bottom(1)).prompt(), "Put 1 card on the bottom")
	assert_eq(CardPicks.new(_bottom(3)).prompt(), "Put 3 cards on the bottom")
	assert_eq(CardPicks.new().prompt(), "")


func test_only_several_cards_put_on_the_bottom_have_an_order_that_matters() -> void:
	assert_true(CardPicks.new(_bottom(2)).is_ordered())
	assert_false(CardPicks.new(_bottom(1)).is_ordered())
	assert_false(CardPicks.new(_discard(2)).is_ordered(), "Discarded cards all go at once.")
	assert_true(CardPicks.new(_bottom(1)).is_bottoming())
	assert_false(CardPicks.new(_discard(1)).is_bottoming())
	assert_true(CardPicks.new(_discard(1)).is_discarding())
	assert_false(CardPicks.new().is_discarding())


func _bottom(count: int) -> ChooseCardsToBottomDecision:
	return ChooseCardsToBottomDecision.new(HERO, count, HAND)


func _discard(count: int) -> ChooseCardsToDiscardDecision:
	return ChooseCardsToDiscardDecision.new(HERO, count, HAND)
