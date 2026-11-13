extends GutTest
## A target requirement can ask for abilities on the stack (ADR 0014), and to counter an
## ability is to remove it from the stack (CR 701.6a): it never resolves, and the costs
## paid for it stay paid. A mana ability never uses the stack, so it is never a target.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason


func test_the_legal_targets_are_the_abilities_on_the_stack_top_first_without_spells() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_put_trigger_on_the_stack(engine)
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Life Land"), [MmReference.to_player(hero.id)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(hero.id)])
	var on_stack: Array[int] = Scenario.stack_ids(engine)

	engine.submit(Scenario.cast_index(engine.pending_decision() as PriorityDecision, Scenario.card_in_hand(engine, hero, "Stifle")))

	var decision: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(decision)
	var offered: Array[int] = []
	for candidate: MmReference in decision.candidates:
		assert_true(candidate.is_object())
		offered.append(candidate.id)
	assert_eq(offered, [on_stack[1], on_stack[2]], "The activated ability, then the trigger; not the Shock, not the Stifle.")


func test_it_cannot_be_cast_with_no_ability_on_the_stack() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	var stifle: int = Scenario.card_in_hand(engine, hero, "Stifle")

	assert_false(Scenario.offers_cast(engine, stifle), "CR 601.2c: there is nothing to target.")
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(hero.id)])
	assert_false(Scenario.offers_cast(engine, stifle), "A spell is not an ability.")
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Life Land"), [MmReference.to_player(hero.id)])
	assert_true(Scenario.offers_cast(engine, stifle))


func test_a_countered_activated_ability_does_nothing_and_its_cost_stays_paid() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	var land: int = Scenario.permanent_named(engine, hero.id, "Life Land")
	Scenario.activate(engine, land, [MmReference.to_player(hero.id)])
	var ability: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Stifle"), [MmReference.to_object(ability)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, 20, "The ability never resolved.")
	assert_true(engine.game_state().object(land).is_tapped, "CR 701.6a: the cost stays paid.")
	assert_null(engine.game_state().object(ability), "It stopped existing.")
	var left: Array[AbilityLeftStackEvent] = _abilities_left(engine)
	assert_eq(left.size(), 1)
	assert_eq(left[0].object_id, ability)
	assert_true(left[0].was_countered)
	assert_false(left[0].did_resolve)
	assert_eq(Scenario.names(engine, hero.graveyard), ["Stifle"])


func test_a_countered_triggered_ability_does_nothing() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	_put_trigger_on_the_stack(engine)
	var trigger: int = Scenario.stack_ids(engine)[0]

	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Stifle"), [MmReference.to_object(trigger)])
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, 20, "The Greeter's trigger never resolved.")
	assert_eq(Scenario.permanents_named(engine, hero.id, "Greeter").size(), 1, "The Greeter itself is untouched.")


func test_an_ability_that_resolves_is_not_marked_as_countered() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()

	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Life Land"), [MmReference.to_player(hero.id)])
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, 21)
	assert_false(_abilities_left(engine)[0].was_countered)
	assert_true(_abilities_left(engine)[0].did_resolve)


func test_a_counter_whose_ability_was_countered_first_does_not_resolve() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Life Land"), [MmReference.to_player(hero.id)])
	var ability: MmReference = MmReference.to_object(Scenario.stack_ids(engine)[0])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Stifle"), [ability])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Stifle"), [ability]), "")
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, 20)
	assert_eq(_moves_with(engine, Reason.DID_NOT_RESOLVE).size(), 1, "CR 608.2b: its only target had left the stack.")


func test_a_spell_is_never_a_legal_ability_target() -> void:
	var engine: MmEngine = _engine()
	var hero: MmPlayer = engine.hero()
	Scenario.activate(engine, Scenario.permanent_named(engine, hero.id, "Life Land"), [MmReference.to_player(hero.id)])
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Shock"), [MmReference.to_player(hero.id)])
	var on_stack: Array[int] = Scenario.stack_ids(engine)
	var spec: TargetSpec = Scenario.target_ability()
	var context: MmEffectContext = MmEffectContext.new(hero.id, 0)

	assert_false(spec.is_still_legal(engine.game_state(), MmReference.to_object(on_stack[0]), context), "The Shock is a spell.")
	assert_true(spec.is_still_legal(engine.game_state(), MmReference.to_object(on_stack[1]), context))
	assert_false(spec.is_still_legal(engine.game_state(), MmReference.to_player(hero.id), context))
	var land: MmReference = MmReference.to_object(Scenario.permanent_named(engine, hero.id, "Life Land"))
	assert_false(spec.is_still_legal(engine.game_state(), land, context), "A permanent with an ability is not an ability.")


func test_a_mana_ability_is_never_on_the_stack_to_be_countered() -> void:
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.basic_land("Forest"), Scenario.free_stifle("Stifle")])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 1, 1, "Stifle"))
	var hero: MmPlayer = engine.hero()

	Scenario.activate(engine, Scenario.first_permanent_of(engine, hero.id))

	assert_false(Scenario.offers_cast(engine, Scenario.card_in_hand(engine, hero, "Stifle")), "CR 605.3a: it resolved at once.")


## Casts the Greeter and lets it resolve, leaving its trigger on the stack with the Hero
## holding priority.
func _put_trigger_on_the_stack(engine: MmEngine) -> void:
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Greeter"))
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(Scenario.stacked_abilities(engine).size(), 1, "The Greeter's trigger is waiting.")


## The Hero in their first main phase with a Life Land on the battlefield, holding free
## Shocks, Stifles ("counter target activated or triggered ability") and a Greeter ("when
## this enters, you gain 5 life").
func _engine() -> MmEngine:
	var greeter: MmCardDefinition = Scenario.creature("Greeter", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.gain_life(5, Scenario.you())])])
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.life_land(), Scenario.free_shock("Shock", 2), Scenario.free_stifle("Stifle"), greeter])
	return Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 1, "Stifle"):
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.has("Shock") and held.count("Stifle") >= 2 and held.has("Greeter"))


func _abilities_left(engine: MmEngine) -> Array[AbilityLeftStackEvent]:
	var found: Array[AbilityLeftStackEvent] = []
	for event: MmEvent in Scenario.events_of(engine, AbilityLeftStackEvent):
		found.append(event as AbilityLeftStackEvent)
	return found


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found
