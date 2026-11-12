extends GutTest
## CR 701.6: to counter a spell is to move it from the stack to its owner's graveyard, so
## it never resolves. CR 115.1: "target spell" is chosen among the spells on the stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason


func test_the_legal_targets_are_the_spells_on_the_stack_top_first_without_abilities_or_itself() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	var villain: MmReference = MmReference.to_player(engine.villain().id)
	Scenario.activate(engine, Scenario.first_permanent_of(engine, hero.id), [villain])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [villain])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [villain])
	var on_stack: Array[int] = Scenario.stack_ids(engine)

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, hero, "Counter")))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	var offered: Array[int] = []
	for candidate: MmReference in decision.candidates:
		assert_true(candidate.is_object())
		offered.append(candidate.id)
	assert_eq(offered, [on_stack[0], on_stack[1]], "Both Shocks, top first; not the ability under them, and not the Counter.")


func test_it_cannot_be_cast_with_no_spell_on_the_stack() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	var counter: int = Scenario.card_in_hand(engine, hero, "Counter")

	assert_false(Scenario.offers_cast(engine, counter), "CR 601.2c: there is nothing to target.")
	Scenario.activate(engine, Scenario.first_permanent_of(engine, hero.id), [MmReference.to_player(hero.id)])
	assert_false(Scenario.offers_cast(engine, counter), "An ability on the stack is not a spell.")
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(hero.id)])
	assert_true(Scenario.offers_cast(engine, counter))


func test_a_countered_spell_goes_to_its_owners_graveyard_and_does_nothing() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	var shock: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(shock)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 20, "The Shock never resolved.")
	assert_eq(Scenario.names(engine, hero.graveyard), ["Shock", "Counter"], "CR 701.6a, then CR 608.2n.")
	var countered: Array[ZoneChangeEvent] = _moves_with(engine, Reason.COUNTER)
	assert_eq(countered.size(), 1)
	assert_eq(countered[0].object_id, shock)
	assert_eq(countered[0].from_zone_kind, MmZone.Kind.STACK)
	assert_eq(countered[0].to_zone_kind, MmZone.Kind.GRAVEYARD)


func test_a_countered_creature_spell_never_enters_the_battlefield() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Greeter"))
	var greeter: int = Scenario.stack_ids(engine)[0]

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(greeter)])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, hero.id, "Greeter"), [] as Array[int])
	assert_true(Scenario.names(engine, hero.graveyard).has("Greeter"))
	assert_eq(hero.life, 20, "It never entered, so its trigger never happened.")
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), 0)


func test_a_spell_cast_without_being_countered_still_enters_and_triggers() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Greeter"))
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, 25)


func test_a_counter_whose_target_was_countered_first_does_not_resolve() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	var shock: MmReference = MmReference.to_object(Scenario.stack_ids(engine)[0])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [shock])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [shock]), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 20)
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)
	assert_eq(_moves_with(engine, Reason.DID_NOT_RESOLVE).size(), 1, "CR 608.2b: its only target had left the stack.")
	assert_eq(Scenario.names(engine, hero.graveyard), ["Shock", "Counter", "Counter"])


func test_countering_a_counter_lets_the_first_spell_resolve() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(Scenario.stack_ids(engine)[0])])

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(Scenario.stack_ids(engine)[0])])
	Scenario.resolve_stack(engine)

	assert_eq(engine.villain().life, 18, "The Shock's counter was countered.")
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)


func test_a_filter_narrows_which_spells_may_be_targeted() -> void:
	var engine: MmEngine = _engine(_creature_counter())
	var hero: MmPlayer = engine.hero()

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Counter")), "A Shock is not a creature spell.")


func test_a_filtered_counter_may_target_a_spell_its_filter_matches() -> void:
	var engine: MmEngine = _engine(_creature_counter())
	var hero: MmPlayer = engine.hero()

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Greeter"))

	assert_true(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Counter")))


func test_a_spell_that_targets_players_and_permanents_is_never_offered_a_spell() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Greeter"))
	var greeter: int = Scenario.stack_ids(engine)[0]

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, hero, "Shock")))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	for candidate: MmReference in decision.candidates:
		assert_false(candidate.is_object() and candidate.id == greeter, "A creature spell is not a creature on the battlefield (CR 115.4).")
	assert_eq(TargetSpec.new().among, TargetSpec.Among.PLAYERS_AND_PERMANENTS, "The default every saved card relies on.")


func test_casting_a_counter_can_be_undone_but_a_countered_spell_cannot_come_back() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(engine.villain().id)])
	var shock: int = Scenario.stack_ids(engine)[0]
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(shock)])

	assert_eq(engine.undo(), "")
	assert_eq(engine.undo(), "")

	assert_eq(Scenario.stack_ids(engine), [shock], "The Counter is back in hand, and the Shock is the same object.")
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(shock)])
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)
	assert_false(engine.can_undo(), "ADR 0015: something left the stack, which is an undo barrier.")


func test_a_spell_with_protection_can_still_be_targeted_on_the_stack() -> void:
	var warded: MmCardDefinition = Scenario.creature("Greeter", 1, 1,
		[Scenario.protection_from(Scenario.of_type(MmCardTypes.CardType.INSTANT))])
	var engine: MmEngine = _engine(null, warded)
	var hero: MmPlayer = engine.hero()
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Greeter"))
	var greeter: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"), [MmReference.to_object(greeter)]), "",
		"CR 113.6: protection works only on the battlefield.")
	Scenario.resolve_stack(engine)

	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)


func test_an_ability_on_the_stack_is_never_a_legal_spell_target() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.activate(engine, Scenario.first_permanent_of(engine, hero.id), [MmReference.to_player(hero.id)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(hero.id)])
	var on_stack: Array[int] = Scenario.stack_ids(engine)
	var spec: TargetSpec = Scenario.target_spell()
	var context: MmEffectContext = MmEffectContext.new(hero.id, 0)

	assert_true(spec.is_still_legal(engine.game_state(), MmReference.to_object(on_stack[0]), context), "The Shock.")
	assert_false(spec.is_still_legal(engine.game_state(), MmReference.to_object(on_stack[1]), context), "CR 112.1: an ability is not a spell.")


func test_only_a_spell_on_the_stack_is_countered() -> void:
	var sweep: MmCardDefinition = Scenario.instant("Counter", Scenario.mana_cost(0), [],
		[Scenario.counter(Scenario.each(Scenario.of_type(MmCardTypes.CardType.LAND)))])
	var engine: MmEngine = _engine(sweep)
	var hero: MmPlayer = engine.hero()

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Counter"))
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, hero.id, "Life Land").size(), 1, "A permanent cannot be countered.")
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 0)


func _creature_counter() -> MmCardDefinition:
	return Scenario.instant("Counter", Scenario.mana_cost(0),
		[Scenario.target_spell(Scenario.of_type(MmCardTypes.CardType.CREATURE))], [Scenario.counter(Scenario.targeted(0))])


## The Hero in their first main phase with a Life Land on the battlefield, holding free
## Shocks, Greeters ("when this enters, you gain 5 life") and [param counter] spells.
func _engine(counter: MmCardDefinition = null, creature: MmCardDefinition = null) -> MmEngine:
	var greeter: MmCardDefinition = creature
	if greeter == null:
		greeter = Scenario.creature("Greeter", 1, 1,
			[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(5, Scenario.you())])])
	var counter_card: MmCardDefinition = Scenario.free_counter("Counter") if counter == null else counter
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.life_land(), Scenario.free_shock("Shock", 2), counter_card, greeter])
	return Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 1, "Counter"):
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.count("Shock") >= 2 and held.count("Counter") >= 2 and held.has("Greeter"))


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found
