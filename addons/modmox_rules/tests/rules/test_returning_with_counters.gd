extends GutTest
## "Exile target creature you control, then return that card to the battlefield under its
## owner's control with a +1/+1 counter on it" (Daydream). "That card" is the card this
## spell exiled (CR 607.2a, ExiledWithSourceSelection with the spell as the source). It
## returns as a new object (ADR 0008), with the counter on it as it enters (CR 122.6), so
## its "enters" abilities see the counter. A token that left the battlefield never comes
## back (CR 111.8).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_it_returns_as_a_new_untapped_object_with_a_counter_and_summoning_sickness() -> void:
	var engine: MmEngine = Scenario.combat_ready([Scenario.creature("Bear", 2, 2)], [], [_dream()])
	assert_not_null(engine)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.declare_attackers(engine, [bear])
	Scenario.pass_until_step(engine, Step.POSTCOMBAT_MAIN)
	assert_true(engine.game_state().object(bear).is_tapped)

	assert_eq(Scenario.cast_and_resolve(engine, "Dream", [MmReference.to_object(bear)]), "")

	var returned: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_ne(returned, bear, "ADR 0008: a new object.")
	assert_eq(Scenario.counters_on(engine, returned, PLUS), 1)
	assert_eq(Scenario.pt(engine, returned), [3, 3])
	assert_false(engine.game_state().object(returned).is_tapped)
	assert_true(engine.game_state().is_summoning_sick(engine.game_state().object(returned)))
	assert_eq(Scenario.exiled_by_owner(engine, engine.hero()).size(), 0, "Nothing is left in exile.")
	var moves: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent)
	var arrival: ZoneChangeEvent = moves[moves.size() - 2] as ZoneChangeEvent
	assert_eq(arrival.counters_on_arrival, {PLUS: 1} as Dictionary[MmCounter.Kind, int], "It enters with the counter.")
	assert_eq(Scenario.events_of(engine, CountersPutEvent).size(), 0, "Never put on afterward.")


func test_its_enters_ability_sees_the_counter() -> void:
	var proud: MmCardDefinition = Scenario.creature("Proud", 1, 1, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.gain_life(3, Scenario.you())], [], Scenario.condition(SourceSelection.new(), Scenario.has_counters(PLUS, 1)))])
	var engine: MmEngine = _hero_main([proud], [_dream()])
	assert_eq(engine.hero().life, 20, "Cast with no counter, the condition was false.")

	Scenario.cast_and_resolve(engine, "Dream", [MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Proud"))])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 23, "CR 603.4: true as it entered.")


func test_an_exiled_token_does_not_come_back() -> void:
	var engine: MmEngine = _hero_main([], [Scenario.free_tokens("Litter", Scenario.cat()), _dream()])
	Scenario.cast_and_resolve(engine, "Litter")
	var cat: int = Scenario.tokens_on_battlefield(engine)[0]

	Scenario.cast_and_resolve(engine, "Dream", [MmReference.to_object(cat)])

	assert_eq(Scenario.tokens_on_battlefield(engine), [] as Array[int], "CR 111.8")
	assert_eq(Scenario.exiled_by_owner(engine, engine.hero()).size(), 0, "CR 704.5d: it ceased to exist.")


func test_only_a_creature_you_control_can_be_its_target() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2)], [_dream()], [Scenario.creature("Wolf", 2, 2)])
	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Dream")))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_eq(decision.candidates.size(), 1)
	assert_eq(decision.candidates[0].id, Scenario.permanent_named(engine, engine.hero().id, "Bear"))


## A sorcery costing {0}: "Exile target creature you control, then return that card to the
## battlefield under its owner's control with a +1/+1 counter on it."
func _dream() -> MmCardDefinition:
	var mine: ControlledByFilter = ControlledByFilter.new()
	mine.whose = MmTrigger.Whose.YOU
	var back: ReturnToBattlefieldEffect = ReturnToBattlefieldEffect.new()
	back.selection = ExiledWithSourceSelection.new()
	back.counter_kind = PLUS
	back.counters = Scenario.constant(1)
	return Scenario.sorcery("Dream", Scenario.mana_cost(0),
		[Scenario.target(Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), mine]))],
		[Scenario.exile(Scenario.targeted(0)), back])


func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
