extends GutTest
## "[filter] spells you control can't be countered", as Destiny Spinner's "Creature and
## enchantment spells you control can't be countered." (engine ADR 0062's second addendum): a static
## ability of a permanent, asked by CounterRules for each spell a counter would counter, as
## the spell's own "This spell can't be countered." is. A counter may still target such a
## spell, and resolves doing nothing to it (CR 101.2). Spinner is a 2/3 Enchantment Creature
## costing {0} with that ability.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_a_creature_spell_you_control_resolves_through_a_counter() -> void:
	var engine: MmEngine = _hero_main([Scenario.spinner()], NO_CARDS)

	assert_eq(_cast_then_counter(engine, "Greeter"), "", "CR 101.2: it may still be targeted.")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Greeter"), -1)
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 0)


func test_an_enchantment_spell_you_control_resolves_through_a_counter() -> void:
	var engine: MmEngine = _hero_main([Scenario.spinner()], NO_CARDS)

	assert_eq(_cast_then_counter(engine, "Charm"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Charm"), -1)
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 0)


func test_an_instant_you_control_is_still_countered() -> void:
	var engine: MmEngine = _hero_main([Scenario.spinner()], NO_CARDS)
	var life: int = engine.villain().life

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"),
		[MmReference.to_player(engine.villain().id)]), "")
	assert_eq(_counter_the_top(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.villain().life, life, "The Shock was countered.")
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)


func test_an_opponents_spinner_does_not_stop_your_creature_spell_being_countered() -> void:
	var engine: MmEngine = _hero_main(NO_CARDS, [Scenario.spinner()])

	assert_eq(_cast_then_counter(engine, "Greeter"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Greeter"), -1)
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)


func test_once_the_spinner_has_left_a_creature_spell_can_be_countered_again() -> void:
	var engine: MmEngine = _hero_main([Scenario.spinner()], NO_CARDS)
	var spinner: int = Scenario.permanent_named(engine, engine.hero().id, "Spinner")
	assert_eq(Scenario.cast_and_resolve(engine, "Destroy", [MmReference.to_object(spinner)]), "")

	assert_eq(_cast_then_counter(engine, "Greeter"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Greeter"), -1)
	assert_eq(_moves_with(engine, Reason.COUNTER).size(), 1)


func test_counter_rules_answer_for_the_spell_on_the_stack() -> void:
	var engine: MmEngine = _hero_main([Scenario.spinner()], NO_CARDS)
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Greeter")), "")
	var greeter: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])
	assert_false(CounterRules.can_be_countered(engine.game_state(), greeter))

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"),
		[MmReference.to_player(engine.villain().id)]), "")
	var shock: MmGameObject = engine.game_state().object(Scenario.stack_ids(engine)[0])

	assert_true(CounterRules.can_be_countered(engine.game_state(), shock))


## Casts the card named [param card_name] from the Hero's hand, then a Counter at it.
func _cast_then_counter(engine: MmEngine, card_name: String) -> String:
	var cast: String = Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), card_name))
	if cast != "":
		return cast
	return _counter_the_top(engine)


func _counter_the_top(engine: MmEngine) -> String:
	return Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Counter"),
		[MmReference.to_object(Scenario.stack_ids(engine)[0])])


func _moves_with(engine: MmEngine, reason: Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		if (event as ZoneChangeEvent).reason == reason:
			found.append(event as ZoneChangeEvent)
	return found


## The Hero in their main phase of Game Turn 3 holding a Greeter (a 1/1 creature), a Charm
## (an enchantment), a Shock, a Counter and a Destroy, all costing {0}, with
## [param hero_permanents] and [param villain_permanents] on the battlefield.
func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition]) -> MmEngine:
	var extras: Array[MmCardDefinition] = [Scenario.creature("Greeter", 1, 1), Scenario.enchantment("Charm", []),
		Scenario.free_shock("Shock", 2), Scenario.free_counter("Counter"), _free_destroy()]
	var engine: MmEngine = Scenario.permanents_ready_with(Scenario.combat_setup(hero_permanents, villain_permanents, extras),
		hero_permanents, villain_permanents, extras, NO_CARDS, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## An instant costing {0}: "Destroy target creature."
func _free_destroy() -> MmCardDefinition:
	var destroy: DestroyEffect = DestroyEffect.new()
	destroy.selection = Scenario.targeted(0)
	return Scenario.instant("Destroy", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))],
		[destroy])
