extends GutTest
## CR 514.1: in the cleanup step, the active player discards down to their maximum hand size.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_the_active_player_discards_down_to_seven() -> void:
	# The Villain draws to 8 on game turn 2 and cannot play anything yet.
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	assert_eq(Scenario.play_until_step(engine, 2, Step.CLEANUP), "")

	var decision: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(decision)
	assert_eq(decision.player_id, engine.villain().id)
	assert_eq(decision.count, 1)
	assert_eq(decision.candidate_ids, engine.villain().hand.object_ids())


func test_a_discarded_card_goes_to_the_graveyard_as_a_new_object() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.play_until_step(engine, 2, Step.CLEANUP)
	var decision: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	var chosen: int = decision.candidate_ids[4]
	var chosen_card: int = engine.game_state().object(chosen).card_id

	assert_eq(engine.submit([chosen]), "")

	assert_eq(engine.villain().hand.size(), 7)
	assert_eq(Scenario.card_ids(engine.villain().graveyard), [chosen_card])
	assert_null(engine.game_state().object(chosen), "The discarded card is a new object now.")
	assert_true(engine.pending_decision() is PriorityDecision, "Play continues into the next turn.")
	assert_eq(engine.game_state().game_turn, 3)


func test_hand_size_at_or_below_the_maximum_needs_no_discard() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	# Game turn 1: the Hero has 7 cards, exactly the maximum.
	assert_eq(Scenario.play_until_game_turn(engine, 2), "")

	assert_eq(engine.hero().graveyard.size(), 0)


func test_a_smaller_maximum_hand_size_from_the_setup_discards_more() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.maximum_hand_size = 5
	var engine: MmEngine = MmEngine.start(setup)

	assert_eq(Scenario.play_until_step(engine, 1, Step.CLEANUP), "")

	var decision: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_eq(decision.count, 2)


func test_no_maximum_hand_size_never_discards() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.villain.maximum_hand_size = MmPlayerSetup.NO_MAXIMUM_HAND_SIZE
	var engine: MmEngine = MmEngine.start(setup)

	assert_eq(Scenario.play_until_game_turn(engine, 3), "")

	assert_eq(engine.villain().hand.size(), 8)
	assert_eq(engine.villain().graveyard.size(), 0)


func test_the_non_active_player_never_discards() -> void:
	# The Hero holds 7 cards against a maximum of 5 throughout the Villain's first turn.
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.VILLAIN_STARTS)
	setup.hero.maximum_hand_size = 5
	var engine: MmEngine = MmEngine.start(setup)

	assert_eq(Scenario.play_until_game_turn(engine, 2), "")
	assert_eq(engine.hero().hand.size(), 7, "No discard during the Villain's cleanup.")
	assert_eq(engine.hero().graveyard.size(), 0)

	assert_eq(Scenario.play_until_step(engine, 2, Step.CLEANUP), "")
	var decision: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.count, 3, "The Hero drew to 8 and discards down to 5 on their own turn.")


func test_invalid_discard_answers_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	Scenario.play_until_step(engine, 2, Step.CLEANUP)
	var decision: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	var hero_card: int = engine.hero().hand.object_ids()[0]
	var before: String = engine.fingerprint()

	for bad_answer: Variant in [[], [decision.candidate_ids[0], decision.candidate_ids[1]], [hero_card], decision.candidate_ids[0]]:
		assert_ne(engine.submit(bad_answer), "", "Answer %s should be rejected." % [bad_answer])

	assert_eq(engine.fingerprint(), before)
