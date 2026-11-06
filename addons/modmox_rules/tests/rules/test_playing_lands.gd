extends GutTest
## CR 305: playing a land is a special action, once per turn, in your own main phase with
## an empty stack. It does not use the stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_playing_a_land_puts_it_onto_the_battlefield_untapped_under_your_control() -> void:
	var engine: MmEngine = _forests_vs_forests()
	assert_eq(Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN), "")
	var in_hand: int = engine.hero().hand.object_ids()[0]

	assert_eq(engine.submit(Scenario.play_land_index(_priority(engine), in_hand)), "")

	var state: MmGameState = engine.game_state()
	assert_eq(state.battlefield.size(), 1)
	var land: MmGameObject = state.battlefield.objects()[0]
	assert_ne(land.id, in_hand, "A land entering the battlefield is a new object.")
	assert_false(land.is_tapped)
	assert_eq(land.controller_id, engine.hero().id)
	assert_eq(engine.hero().hand.size(), 6)


func test_a_land_play_is_offered_for_every_land_in_hand_in_object_id_order() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	var decision: PriorityDecision = _priority(engine)

	assert_true(decision.actions[0] is PassAction, "Pass is always the first action.")
	var offered: Array[int] = []
	for action: MmAction in decision.actions:
		if action is PlayLandAction:
			offered.append((action as PlayLandAction).object_id)
	var expected: Array[int] = engine.hero().hand.object_ids()
	expected.sort()
	assert_eq(offered, expected)


func test_only_lands_can_be_played_as_lands() -> void:
	var hero_cards: Array[MmCardDefinition] = []
	for index: int in 20:
		hero_cards.append(Scenario.basic_land("Forest"))
		hero_cards.append(Scenario.vanilla("Bear %d" % index))
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(hero_cards, Scenario.copies(Scenario.vanilla("Card"), 40)))
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	var lands_in_hand: int = 0
	for object: MmGameObject in engine.hero().hand.objects():
		if engine.game_state().characteristics_of(object).has_card_type(MmCardTypes.CardType.LAND):
			lands_in_hand += 1
	var land_plays: int = 0
	for action: MmAction in _priority(engine).actions:
		if action is PlayLandAction:
			land_plays += 1
			var object: MmGameObject = engine.game_state().object((action as PlayLandAction).object_id)
			assert_true(engine.game_state().characteristics_of(object).has_card_type(MmCardTypes.CardType.LAND))
	assert_eq(land_plays, lands_in_hand)


func test_only_one_land_may_be_played_each_turn() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	Scenario.play_first_land(engine)

	assert_false(_offers_land_play(_priority(engine)), "The land play for this turn is used up.")
	assert_eq(Scenario.play_until_step(engine, 1, Step.POSTCOMBAT_MAIN), "")
	assert_false(_offers_land_play(_priority(engine)), "Still used up in the second main phase.")
	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")
	assert_true(_offers_land_play(_priority(engine)), "A new turn brings a new land play.")


func test_lands_are_not_offered_outside_your_main_phases() -> void:
	var engine: MmEngine = _forests_vs_forests()
	assert_eq(Scenario.keep_all(engine), "")

	assert_eq(engine.game_state().step, Step.UPKEEP)
	assert_false(_offers_land_play(_priority(engine)))
	Scenario.play_until_step(engine, 1, Step.BEGINNING_OF_COMBAT)
	assert_false(_offers_land_play(_priority(engine)))


func test_lands_are_not_offered_on_your_opponents_turn() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	engine.submit(Scenario.pass_index(_priority(engine)))

	assert_eq(engine.pending_decision().player_id, engine.villain().id)
	assert_false(_offers_land_play(_priority(engine)), "The Villain holds lands but it is not their turn.")


func test_playing_a_land_keeps_priority_and_both_players_must_still_pass() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)

	Scenario.play_first_land(engine)

	assert_eq(engine.pending_decision().player_id, engine.hero().id)
	assert_eq(engine.game_state().stack.size(), 0, "A land play does not use the stack.")
	engine.submit(Scenario.pass_index(_priority(engine)))
	assert_eq(engine.game_state().step, Step.PRECOMBAT_MAIN)
	engine.submit(Scenario.pass_index(_priority(engine)))
	assert_eq(engine.game_state().step, Step.BEGINNING_OF_COMBAT)


func _forests_vs_forests() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	return MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))


func _priority(engine: MmEngine) -> PriorityDecision:
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_not_null(decision, "Expected a priority decision.")
	return decision


func _offers_land_play(decision: PriorityDecision) -> bool:
	for action: MmAction in decision.actions:
		if action is PlayLandAction:
			return true
	return false
