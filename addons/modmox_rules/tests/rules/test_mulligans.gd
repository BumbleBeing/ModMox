extends GutTest
## CR 103.5: the London mulligan. Each player in turn order keeps or mulligans; mulligans
## shuffle the hand away and draw a new one; on keeping, a player puts one card on the
## bottom for each mulligan taken beyond their Free Mulligans.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const KEEP: KeepOrMulliganDecision.Choice = KeepOrMulliganDecision.Choice.KEEP
const MULLIGAN: KeepOrMulliganDecision.Choice = KeepOrMulliganDecision.Choice.MULLIGAN


func test_players_decide_in_turn_order_starting_with_the_starting_player() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.VILLAIN_STARTS))

	assert_eq(engine.pending_decision().player_id, engine.villain().id)
	engine.submit(KEEP)
	assert_eq(engine.pending_decision().player_id, engine.hero().id)


func test_keeping_seven_needs_no_bottom_decision() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	_submit_all(engine, [KEEP, KEEP])

	assert_null(engine.pending_decision(), "The pregame is over once both players keep seven.")
	assert_eq(engine.hero().hand.size(), 7)
	assert_eq(engine.villain().hand.size(), 7)


func test_a_mulligan_shuffles_the_hand_away_and_draws_a_new_one() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	_submit_all(engine, [MULLIGAN, KEEP])

	assert_eq(engine.hero().mulligans_taken, 1)
	assert_eq(engine.hero().hand.size(), 7)
	assert_eq(engine.hero().library.size(), 33)
	assert_true(_has_mulligan_event_for(engine, engine.hero().id))


func test_london_mulligan_twice_without_free_mulligans_keeps_five() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	_submit_all(engine, [MULLIGAN, KEEP, MULLIGAN, KEEP])

	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	assert_not_null(bottom, "Keeping after two mulligans asks for two cards to bottom.")
	assert_eq(bottom.player_id, engine.hero().id)
	assert_eq(bottom.count, 2)
	engine.submit(bottom.candidate_ids.slice(0, 2))
	assert_eq(engine.hero().hand.size(), 5)
	assert_eq(engine.hero().library.size(), 35)
	assert_null(engine.pending_decision())


func test_london_mulligan_twice_with_one_free_mulligan_keeps_six() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.free_mulligans = 1
	var engine: MmEngine = MmEngine.start(setup)

	_submit_all(engine, [MULLIGAN, KEEP, MULLIGAN, KEEP])

	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	assert_eq(bottom.count, 1)
	engine.submit(bottom.candidate_ids.slice(0, 1))
	assert_eq(engine.hero().hand.size(), 6)


func test_a_free_mulligan_keeps_the_full_hand() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.free_mulligans = 1
	var engine: MmEngine = MmEngine.start(setup)

	_submit_all(engine, [MULLIGAN, KEEP, KEEP])

	assert_null(engine.pending_decision(), "A free mulligan puts nothing on the bottom.")
	assert_eq(engine.hero().hand.size(), 7)


func test_a_forgetful_hero_who_mulligans_once_keeps_five() -> void:
	# The game resolves the Forgetful Affliction into an opening hand size of 6 (ADR 0011).
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.opening_hand_size = 6
	var engine: MmEngine = MmEngine.start(setup)
	assert_eq(engine.hero().hand.size(), 6)

	_submit_all(engine, [MULLIGAN, KEEP, KEEP])

	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	assert_eq(bottom.count, 1)
	engine.submit(bottom.candidate_ids.slice(0, 1))
	assert_eq(engine.hero().hand.size(), 5)


func test_keep_or_mulligan_says_how_many_cards_keeping_would_bottom() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	_submit_all(engine, [MULLIGAN, KEEP])

	var decision: KeepOrMulliganDecision = engine.pending_decision() as KeepOrMulliganDecision
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.cards_to_bottom_if_kept, 1)


func test_bottomed_cards_go_to_the_bottom_in_the_chosen_order() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	_submit_all(engine, [MULLIGAN, KEEP, KEEP])
	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	var chosen_card_id: int = engine.game_state().object(bottom.candidate_ids[3]).card_id

	engine.submit([bottom.candidate_ids[3]])

	var library: Array[int] = Scenario.card_ids(engine.hero().library)
	assert_eq(library[library.size() - 1], chosen_card_id)


func test_several_bottomed_cards_keep_their_order_with_the_last_chosen_lowest() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	_submit_all(engine, [MULLIGAN, KEEP, MULLIGAN, KEEP])
	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	var first_choice: int = bottom.candidate_ids[5]
	var second_choice: int = bottom.candidate_ids[1]
	var expected: Array[int] = [
		engine.game_state().object(first_choice).card_id,
		engine.game_state().object(second_choice).card_id,
	]

	engine.submit([first_choice, second_choice])

	assert_eq(Scenario.card_ids(engine.hero().library).slice(-2), expected)


func test_invalid_bottom_answers_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	_submit_all(engine, [MULLIGAN, KEEP, MULLIGAN, KEEP])
	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	var villain_card: int = engine.villain().hand.object_ids()[0]
	var first: int = bottom.candidate_ids[0]
	var before: String = engine.fingerprint()
	var logged: int = engine.decision_log().size()

	var bad_answers: Array = [
		[first],                        # too few
		[first, bottom.candidate_ids[1], bottom.candidate_ids[2]],  # too many
		[first, villain_card],          # not in this hand
		[first, first],                 # duplicate
		[first, "two"],                 # not an ID
		first,                          # not a list
	]
	for bad_answer: Variant in bad_answers:
		assert_ne(engine.submit(bad_answer), "", "Answer %s should be rejected." % [bad_answer])

	assert_eq(engine.fingerprint(), before)
	assert_eq(engine.decision_log().size(), logged)
	assert_eq(engine.pending_decision(), bottom, "The same decision stays pending.")


func test_an_invalid_keep_or_mulligan_answer_is_rejected() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	var before: String = engine.fingerprint()

	assert_ne(engine.submit(7), "")
	assert_ne(engine.submit("keep"), "")
	assert_eq(engine.fingerprint(), before)


func _submit_all(engine: MmEngine, answers: Array) -> void:
	for answer: Variant in answers:
		var error: String = engine.submit(answer)
		assert_eq(error, "", "Answer %s was rejected: %s" % [answer, error])


func _has_mulligan_event_for(engine: MmEngine, player_id: int) -> bool:
	for event: MmEvent in engine.event_log():
		if event is MulliganEvent and (event as MulliganEvent).player_id == player_id:
			return true
	return false
