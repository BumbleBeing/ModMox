extends GutTest
## CR 305: playing a land is a special action, once per turn, in your own main phase with
## an empty stack. It does not use the stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step

var _scouting_setup: MmEncounterSetup


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


# --- "You may play an additional land this turn" (CR 305.2, 505.6b) ------------------
# Scout is a sorcery costing {0}: "You may play an additional land this turn." Surveyor is
# one costing {0}: "Target player may play an additional land this turn."


func test_a_spell_granting_an_additional_land_play_allows_a_second_land_this_turn() -> void:
	var engine: MmEngine = _scouting(1, 3)

	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")

	assert_ne(Scenario.play_first_land(engine), -1)
	assert_ne(Scenario.play_first_land(engine), -1, "The additional land play.")
	assert_eq(Scenario.play_first_land(engine), -1, "Only one additional land.")


func test_a_land_played_before_the_spell_still_leaves_the_additional_play() -> void:
	var engine: MmEngine = _scouting(1, 3)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_false(_offers_land_play(_priority(engine)))

	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")

	assert_ne(Scenario.play_first_land(engine), -1, "CR 305.2: the count of plays allowed, not the next land.")
	assert_eq(Scenario.play_first_land(engine), -1)


func test_the_additional_land_play_lasts_only_this_turn() -> void:
	var engine: MmEngine = _scouting(1, 4)
	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")
	assert_ne(Scenario.play_first_land(engine), -1)

	assert_eq(Scenario.play_until_step(engine, 2, Step.PRECOMBAT_MAIN), "")
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1, "The Villain got no additional land play.")
	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1, "CR 514.2: the additional play ended with the turn it was for.")


func test_two_additional_land_plays_in_one_turn_allow_three_lands() -> void:
	var engine: MmEngine = _scouting(2, 4)

	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")

	assert_ne(Scenario.play_first_land(engine), -1)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1, "CR 305.2: each additional play adds one.")


func test_an_additional_land_play_this_turn_adds_to_an_emblems() -> void:
	var extra: AdditionalLandPlaysAbility = AdditionalLandPlaysAbility.new()
	extra.count = 1
	var engine: MmEngine = _scouting(1, 4, [Scenario.emblem("Explorer", [extra])])

	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")

	assert_ne(Scenario.play_first_land(engine), -1)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1)


func test_only_the_player_it_selects_gets_the_additional_land_play() -> void:
	var engine: MmEngine = _scouting(1, 3)
	var surveyor: int = Scenario.card_in_hand(engine, engine.hero(), "Surveyor")

	assert_eq(Scenario.cast(engine, surveyor, [MmReference.to_player(engine.villain().id)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.play_first_land(engine), -1)
	assert_eq(Scenario.play_first_land(engine), -1, "The Villain was chosen, not the Hero.")


func test_a_copy_and_a_replay_keep_the_additional_land_play() -> void:
	var engine: MmEngine = _scouting(1, 3)
	assert_eq(Scenario.cast_and_resolve(engine, "Scout"), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1), true)
	var replayed: MmEngine = MmEngine.replay(_scouting_setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	for each_engine: MmEngine in [copy, replayed]:
		assert_ne(Scenario.play_first_land(each_engine), -1)
		assert_ne(Scenario.play_first_land(each_engine), -1, "The additional land play was kept.")


## The Hero in their main phase of Game Turn 1, holding at least [param scouts] Scouts, a
## Surveyor and [param forests] Forests, with [param emblems].
func _scouting(scouts: int, forests: int, emblems: Array[MmCardDefinition] = []) -> MmEngine:
	var forest: MmCardDefinition = Scenario.basic_land("Forest")
	var scout: MmCardDefinition = Scenario.sorcery("Scout", Scenario.mana_cost(0), [],
		[Scenario.additional_land_plays(1, Scenario.you())])
	var surveyor: MmCardDefinition = Scenario.sorcery("Surveyor", Scenario.mana_cost(0), [Scenario.target_player()],
		[Scenario.additional_land_plays(1, Scenario.targeted(0))])
	var hero_cards: Array[MmCardDefinition] = []
	for index: int in 40:
		hero_cards.append([forest, scout, forest, surveyor][index % 4])
	_scouting_setup = Scenario.setup_with(hero_cards, Scenario.copies(forest, 40))
	_scouting_setup.hero.emblems = emblems
	var engine: MmEngine = Scenario.find_engine(_scouting_setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, Step.PRECOMBAT_MAIN) != "":
			return false
		return _count_named(running, "Scout") >= scouts and _count_named(running, "Surveyor") >= 1 \
			and _count_named(running, "Forest") >= forests)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine


func _count_named(engine: MmEngine, card_name: String) -> int:
	var found: int = 0
	for card: MmGameObject in engine.hero().hand.objects():
		if engine.game_state().characteristics_of(card).name == card_name:
			found += 1
	return found
