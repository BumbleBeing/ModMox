extends GutTest
## What the opening-hand overlay says (13e-2): who chooses, who plays first, how many
## mulligans have cost a card, what the buttons read and what the Villain has decided.

const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const Frame := OpeningHand.Frame


func test_it_covers_the_three_pregame_decisions() -> void:
	assert_true(OpeningHand.covers(ChoosePlayOrDrawDecision.new(HERO)))
	assert_true(OpeningHand.covers(KeepOrMulliganDecision.new(HERO, 0, 0)))
	assert_true(OpeningHand.covers(ChooseCardsToBottomDecision.new(HERO, 1, [1, 2] as Array[int])))
	assert_false(OpeningHand.covers(ChooseCardsToDiscardDecision.new(HERO, 1, [1, 2] as Array[int])))
	assert_false(OpeningHand.covers(null))


func test_it_is_closed_before_anything_is_shown_and_once_the_first_turn_begins() -> void:
	var opening: OpeningHand = OpeningHand.new()
	assert_eq(opening.frame(), Frame.CLOSED)
	assert_false(opening.is_open())

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0)))
	assert_true(opening.is_open())

	var playing: EncounterSnapshot = _snapshot(null)
	playing.view.game_turn = 1
	opening.read(playing)
	assert_eq(opening.frame(), Frame.CLOSED)
	var over: EncounterSnapshot = _snapshot(KeepOrMulliganDecision.new(HERO, 0, 0))
	over.view.is_over = true
	opening.read(over)
	assert_false(opening.is_open(), "A concession in the pregame ends it.")


func test_the_chooser_is_asked_to_play_or_draw_and_told_how_they_came_to_choose() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(ChoosePlayOrDrawDecision.new(HERO, true)))
	assert_eq(opening.frame(), Frame.PLAY_OR_DRAW)
	assert_eq(opening.heading(), "You won the coin flip")
	assert_eq(opening.under_heading(), "", "Nobody plays first yet.")

	opening.read(_snapshot(ChoosePlayOrDrawDecision.new(HERO, false)))
	assert_eq(opening.heading(), "You choose", "The setup named the Hero (ADR 0011).")


func test_it_says_who_plays_first_for_the_rest_of_the_pregame() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [StartingPlayerEvent.new(VILLAIN, VILLAIN)]))
	assert_eq(opening.under_heading(), "The Villain plays first")
	opening.read(_snapshot(null))
	assert_eq(opening.under_heading(), "The Villain plays first", "It was said once and still holds.")

	var other: OpeningHand = OpeningHand.new()
	other.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [StartingPlayerEvent.new(HERO)]))
	assert_eq(other.under_heading(), "You play first")


func test_the_first_hand_has_no_heading_and_keeps_all_it_holds() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [], 7))

	assert_eq(opening.frame(), Frame.KEEP_OR_MULLIGAN)
	assert_eq(opening.heading(), "")
	assert_eq(opening.keep_text(), "Keep 7")
	assert_eq(opening.mulligan_text(), "Mulligan")


func test_the_heading_counts_only_mulligans_that_cost_a_card() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 1, 0, false), [], 7))
	assert_eq(opening.heading(), "", "The one taken was free (A396).")
	assert_eq(opening.keep_text(), "Keep 7")

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 3, 2, false), [], 7))
	assert_eq(opening.heading(), "Mulligans taken: 2")
	assert_eq(opening.keep_text(), "Keep 5", "What the hand will be once two cards are put down.")
	opening.read(_snapshot(null, [], 7))
	assert_eq(opening.frame(), Frame.WAITING)
	assert_eq(opening.heading(), "Mulligans taken: 2", "It stays while the Villain decides.")


func test_a_free_mulligan_says_so_on_its_button() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0, true), [], 7))

	assert_eq(opening.mulligan_text(), "Free Mulligan")


func test_bottoming_says_how_many_cards_and_how_their_order_is_read() -> void:
	var opening: OpeningHand = OpeningHand.new()
	var hand: Array[int] = [1, 2, 3]
	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 2, 2), [StartingPlayerEvent.new(HERO)], 3))

	opening.read(_snapshot(ChooseCardsToBottomDecision.new(HERO, 2, hand), [], 3))
	assert_eq(opening.frame(), Frame.BOTTOM)
	assert_eq(opening.heading(), "Put 2 cards on the bottom")
	assert_eq(opening.under_heading(), "The last card clicked -> bottom of library")

	opening.read(_snapshot(ChooseCardsToBottomDecision.new(HERO, 1, hand), [], 3))
	assert_eq(opening.heading(), "Put 1 card on the bottom")
	assert_eq(opening.under_heading(), "You play first", "One card has no order to explain.")


func test_it_says_the_villain_is_deciding_while_they_think() -> void:
	var opening: OpeningHand = OpeningHand.new()
	var thinking: EncounterSnapshot = _snapshot(null)
	thinking.is_villain_thinking = true

	opening.read(thinking)

	assert_eq(opening.frame(), Frame.WAITING)
	assert_eq(opening.villain_text(), "Villain is deciding…")
	assert_eq(OpeningHand.new().villain_text(), "", "Nothing before they have been asked.")


func test_it_says_what_hand_the_villain_kept() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [KeepOrMulliganEvent.new(VILLAIN, true, 0)], 7, 7))
	assert_eq(opening.villain_text(), "Villain has kept a 7 card hand")
	opening.read(_snapshot(null, [], 7, 7))
	assert_eq(opening.villain_text(), "Villain has kept a 7 card hand", "It stays until the overlay closes.")

	var owing: OpeningHand = OpeningHand.new()
	owing.read(_snapshot(null, [KeepOrMulliganEvent.new(VILLAIN, true, 2)], 7, 7))
	assert_eq(owing.villain_text(), "Villain has kept a 5 card hand", "Said before they have put the two down.")
	owing.read(_snapshot(null, [], 7, 5))
	assert_eq(owing.villain_text(), "Villain has kept a 5 card hand")


func test_a_hand_of_eight_or_eleven_takes_an() -> void:
	for size: int in [8, 11, 18]:
		var opening: OpeningHand = OpeningHand.new()
		opening.read(_snapshot(null, [KeepOrMulliganEvent.new(VILLAIN, true, 0)], 7, size))
		assert_eq(opening.villain_text(), "Villain has kept an %d card hand" % size)
	var ten: OpeningHand = OpeningHand.new()
	ten.read(_snapshot(null, [KeepOrMulliganEvent.new(VILLAIN, true, 0)], 7, 10))
	assert_eq(ten.villain_text(), "Villain has kept a 10 card hand")


func test_it_counts_the_villains_mulligans_free_ones_too() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [KeepOrMulliganEvent.new(VILLAIN, false)]))
	assert_eq(opening.villain_text(), "Villain has taken 1 mulligan")
	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [KeepOrMulliganEvent.new(VILLAIN, false)]))
	assert_eq(opening.villain_text(), "Villain has taken 2 mulligans")
	opening.read(_snapshot(null, [KeepOrMulliganEvent.new(HERO, false)]))
	assert_eq(opening.villain_text(), "Villain has taken 2 mulligans", "The Hero's own choices are not the Villain's.")


func test_a_mulligan_of_the_heros_brings_a_new_hand() -> void:
	var opening: OpeningHand = OpeningHand.new()

	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [], 7))
	assert_true(opening.is_new_hand(), "The first hand is new.")
	opening.read(_snapshot(null, [], 7))
	assert_false(opening.is_new_hand())
	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 1, 1), [MulliganEvent.new(HERO)], 7))
	assert_true(opening.is_new_hand())
	opening.read(_snapshot(KeepOrMulliganDecision.new(HERO, 1, 1), [MulliganEvent.new(VILLAIN)], 7))
	assert_false(opening.is_new_hand(), "The Villain's mulligan changes nothing the Hero holds.")


func test_a_villain_with_a_name_is_called_by_it() -> void:
	var opening: OpeningHand = OpeningHand.new()
	var named: EncounterSnapshot = _snapshot(KeepOrMulliganDecision.new(HERO, 0, 0), [StartingPlayerEvent.new(VILLAIN, VILLAIN)])
	named.names = PlayerNames.new("", "Mishra")
	named.is_villain_thinking = true

	opening.read(named)

	assert_eq(opening.under_heading(), "Mishra plays first")
	assert_eq(opening.villain_text(), "Mishra is deciding…")


func _snapshot(decision: MmPendingDecision, events: Array = [], hand_size: int = 0, villain_hand_size: int = 7) -> EncounterSnapshot:
	var snapshot: EncounterSnapshot = EncounterSnapshot.new()
	snapshot.view = MmPlayerView.new()
	snapshot.view.viewer_id = HERO
	for index: int in hand_size:
		var seen: MmObjectView = MmObjectView.new()
		seen.id = index + 1
		seen.card_id = index + 101
		snapshot.view.hand.append(seen)
	snapshot.view.hand_sizes = {HERO: hand_size, VILLAIN: villain_hand_size}
	snapshot.decision = decision
	snapshot.events.assign(events)
	return snapshot
