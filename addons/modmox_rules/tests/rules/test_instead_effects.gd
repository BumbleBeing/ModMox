extends GutTest
## "[Effect]. If [condition], [other effect] instead." (CR 608.2c): an effect replaced by
## another when a condition holds, checked as the effect begins on resolution. Unlike an
## intervening "if" (CR 603.4), it never stops anything from triggering or resolving.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_with_the_condition_true_only_the_instead_effect_happens() -> void:
	var engine: MmEngine = _hero_main()

	assert_eq(Scenario.cast_and_resolve(engine, "Comeback"), "")

	assert_eq(engine.hero().life, 25, "5 instead of 1, not as well as.")


func test_with_the_condition_false_the_usual_effect_happens() -> void:
	var engine: MmEngine = _hero_main()
	Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_player(engine.hero().id)])

	assert_eq(Scenario.cast_and_resolve(engine, "Comeback"), "")

	assert_eq(engine.hero().life, 19, "18, then 1 life.")


func test_the_condition_is_checked_as_it_resolves_not_as_it_triggers() -> void:
	var engine: MmEngine = _hero_main()
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Greeter"))
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(Scenario.stacked_abilities(engine).size(), 1, "The Greeter's trigger is waiting, at 20 life.")

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Shock"), [MmReference.to_player(engine.hero().id)])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 19, "CR 608.2c: at 18 as it resolved, so 1 life, and it still resolved.")


func test_its_targets_are_its_effects_targets() -> void:
	var to_target: InsteadEffect = Scenario.instead(LifeAtLeastStartingCondition.new(),
		Scenario.gain_life(1, Scenario.you()), Scenario.deal_damage(1, Scenario.targeted(0)))
	var to_you: InsteadEffect = Scenario.instead(LifeAtLeastStartingCondition.new(),
		Scenario.gain_life(1, Scenario.you()), Scenario.gain_life(5, Scenario.you()))

	assert_true(to_target.has_targets(), "Either effect's target counts.")
	assert_false(to_you.has_targets())


## The Hero in their first main phase holding free instants: Comeback ("You gain 1 life.
## If your life total is greater than or equal to your starting life total, you gain 5
## life instead."), Shock, and a Greeter whose enters trigger is a Comeback.
func _hero_main() -> MmEngine:
	var comeback: InsteadEffect = Scenario.instead(LifeAtLeastStartingCondition.new(),
		Scenario.gain_life(1, Scenario.you()), Scenario.gain_life(5, Scenario.you()))
	var greeter: MmCardDefinition = Scenario.creature("Greeter", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [comeback])])
	var cards: Array[MmCardDefinition] = Scenario.cycled([Scenario.instant("Comeback", Scenario.mana_cost(0), [], [comeback]),
		Scenario.free_shock("Shock", 2), greeter])
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.cycled([])), func(running: MmEngine) -> bool:
		if not Scenario.ready_in_main(running, 1, 0, "Comeback"):
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		return held.has("Shock") and held.has("Greeter"))
	assert_not_null(engine)
	return engine
