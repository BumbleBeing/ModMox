extends GutTest
## CR 603.3b: triggers go on the stack in APNAP order, each player ordering their own.
## CR 603.3d: targets are chosen as a trigger is put on the stack; one with no legal target
## is removed. CR 601.2i: "whenever a player casts" triggers once the spell is cast.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose
const CardType := MmCardTypes.CardType


func test_the_active_players_triggers_go_on_the_stack_first() -> void:
	var hero_chime: MmCardDefinition = _upkeep_gain("Hero Chime", Whose.ANY)
	var villain_chime: MmCardDefinition = _upkeep_gain("Villain Chime", Whose.ANY)
	var engine: MmEngine = _engine_at([hero_chime], [villain_chime], 3, Step.UPKEEP)

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)

	assert_eq(stacked.size(), 2)
	assert_eq(stacked[0].controller_id, engine.hero().id, "Active player's first, so it resolves last.")
	assert_eq(stacked[1].controller_id, engine.villain().id)


func test_a_player_orders_their_own_simultaneous_triggers() -> void:
	var first: MmCardDefinition = _upkeep_gain("First Chime", Whose.YOU)
	var second: MmCardDefinition = _upkeep_gain("Second Chime", Whose.YOU)
	var engine: MmEngine = _engine_at([first, second], [], 3, Step.UPKEEP)
	var first_id: int = Scenario.permanent_named(engine, engine.hero().id, "First Chime")
	var second_id: int = Scenario.permanent_named(engine, engine.hero().id, "Second Chime")

	var decision: OrderTriggersDecision = engine.pending_decision() as OrderTriggersDecision
	assert_not_null(decision)
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.source_object_ids, [first_id, second_id])
	assert_eq(engine.submit([1, 0]), "")

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked[0].source_object_id, second_id, "The first index listed goes on the stack first.")
	assert_eq(stacked[1].source_object_id, first_id)


func test_illegal_trigger_orders_are_rejected_and_change_nothing() -> void:
	var engine: MmEngine = _engine_at([_upkeep_gain("First Chime", Whose.YOU), _upkeep_gain("Second Chime", Whose.YOU)], [], 3, Step.UPKEEP)
	var before: String = engine.fingerprint()

	assert_ne(engine.submit([0, 0]), "")
	assert_ne(engine.submit([0]), "")
	assert_ne(engine.submit([0, 2]), "")
	assert_ne(engine.submit(0), "")

	assert_eq(engine.fingerprint(), before)


func test_a_single_trigger_is_not_ordered() -> void:
	var engine: MmEngine = _engine_at([_upkeep_gain("Chime", Whose.YOU)], [], 3, Step.UPKEEP)

	assert_true(engine.pending_decision() is PriorityDecision)


func test_a_trigger_with_a_target_asks_for_it_as_it_goes_on_the_stack() -> void:
	var sniper: MmCardDefinition = Scenario.artifact("Sniper", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU),
		[Scenario.deal_damage(1, Scenario.targeted(0))], [Scenario.any_target()])])
	var engine: MmEngine = _engine_at([sniper], [], 3, Step.UPKEEP)

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(Scenario.choose_target(engine, MmReference.to_player(engine.villain().id)), "")
	Scenario.resolve_stack(engine)
	assert_eq(engine.villain().life, 19)


func test_a_trigger_with_no_legal_target_is_removed() -> void:
	var picker: MmCardDefinition = Scenario.artifact("Picker", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU),
		[Scenario.deal_damage(1, Scenario.targeted(0))], [Scenario.target(Scenario.of_type(CardType.CREATURE))])])
	var engine: MmEngine = _engine_at([picker], [], 3, Step.UPKEEP)

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.game_state().stack.size(), 0)
	assert_eq(engine.game_state().pending_triggers.size(), 0)
	assert_eq(Scenario.events_of(engine, TriggerRemovedEvent).size(), 1)


func test_a_cast_trigger_resolves_before_the_spell() -> void:
	var chant: MmCardDefinition = Scenario.artifact("Chant", [Scenario.triggered(
		Scenario.casts(Scenario.of_type(CardType.INSTANT), Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 2)
	var engine: MmEngine = _engine_with_extras([chant], [], [shock], 3, Step.PRECOMBAT_MAIN)

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [MmReference.to_player(engine.villain().id)])

	assert_eq(engine.game_state().stack.size(), 2, "The trigger sits above the spell.")
	assert_eq(Scenario.stacked_abilities(engine)[0].triggering_object_id, engine.game_state().stack.object_ids()[0])
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(engine.hero().life, 21)
	assert_eq(engine.villain().life, 20, "The spell has not resolved yet.")
	Scenario.resolve_stack(engine)
	assert_eq(engine.villain().life, 18)


func test_a_your_cast_trigger_ignores_the_opponents_spells() -> void:
	var chant: MmCardDefinition = Scenario.artifact("Chant", [Scenario.triggered(
		Scenario.casts(Scenario.of_type(CardType.INSTANT), Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var shock: MmCardDefinition = Scenario.free_shock("Shock", 2)
	var engine: MmEngine = _engine_with_extras([chant], [], [], 3, Step.PRECOMBAT_MAIN, [shock])
	Scenario.pass_priority(engine)

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.villain(), "Shock"), [MmReference.to_player(engine.hero().id)])

	assert_eq(Scenario.stacked_abilities(engine).size(), 0)


func test_the_view_of_a_triggered_ability_names_its_source_card() -> void:
	var engine: MmEngine = _engine_at([_upkeep_gain("Chime", Whose.YOU)], [], 3, Step.UPKEEP)
	var chime: MmGameObject = engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Chime"))

	var view: MmObjectView = engine.view_for(engine.villain()).stack[0]

	assert_eq(view.source_object_id, chime.id)
	assert_eq(view.source_card_id, chime.card_id)
	assert_eq(view.name, "Chime ability")


## "At the beginning of [whose] upkeep, you gain 1 life."
func test_an_order_decision_says_what_each_trigger_does_and_what_triggered_it() -> void:
	var first: MmCardDefinition = _upkeep_gain("First Chime", Whose.YOU)
	var second: MmCardDefinition = _upkeep_gain("Second Chime", Whose.YOU)
	var engine: MmEngine = _engine_at([first, second], [], 3, Step.UPKEEP)

	var decision: OrderTriggersDecision = engine.pending_decision() as OrderTriggersDecision

	assert_eq(decision.abilities.size(), 2)
	for index: int in 2:
		var source: MmGameObject = engine.game_state().object(decision.source_object_ids[index])
		assert_true(engine.game_state().characteristics_of(source).abilities.has(decision.abilities[index]), "The source's own ability.")
	assert_eq(decision.triggering_player_ids, [engine.hero().id, engine.hero().id] as Array[int], "It was the Hero's upkeep.")
	assert_eq(decision.triggering_object_ids, [0, 0] as Array[int], "No object triggered them.")


func test_an_order_decision_names_the_other_player_when_their_step_triggered_it() -> void:
	var engine: MmEngine = _engine_at([_upkeep_gain("First Chime", Whose.ANY), _upkeep_gain("Second Chime", Whose.ANY)], [], 4, Step.UPKEEP)

	var decision: OrderTriggersDecision = engine.pending_decision() as OrderTriggersDecision

	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.triggering_player_ids, [engine.villain().id, engine.villain().id] as Array[int], "It was the Villain's upkeep.")


func _upkeep_gain(card_name: String, whose: Whose) -> MmCardDefinition:
	return Scenario.artifact(card_name, [Scenario.triggered(Scenario.at_step(Step.UPKEEP, whose), [Scenario.gain_life(1, Scenario.you())])])


func _engine_at(hero_cards: Array[MmCardDefinition], villain_cards: Array[MmCardDefinition], game_turn: int, step: Step) -> MmEngine:
	return _engine_with_extras(hero_cards, villain_cards, [], game_turn, step)


func _engine_with_extras(hero_cards: Array[MmCardDefinition], villain_cards: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition], game_turn: int, step: Step,
		villain_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, villain_cards, hero_extras, villain_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, villain_cards, hero_extras, villain_extras, game_turn, step)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
