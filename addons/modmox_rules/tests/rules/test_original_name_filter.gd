extends GutTest
## HasOriginalNameFilter: "originally named [card name]", as in "each other creature you
## control originally named Charmed Stray". A card goes by the name of its Original
## (ADR 0004) whatever its Modifications have made of its name; an object with no Original
## goes by its current name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_it_matches_an_object_of_that_name_and_no_other() -> void:
	var engine: MmEngine = _hero_main([_stray(), Scenario.creature("Bear", 2, 2)], [], [])
	var state: MmGameState = engine.game_state()
	var named: HasOriginalNameFilter = Scenario.named("Stray")

	assert_true(named.matches(state, MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Stray")), null))
	assert_false(named.matches(state, MmReference.to_object(Scenario.permanent_named(engine, engine.hero().id, "Bear")), null))


func test_it_never_matches_a_player() -> void:
	var engine: MmEngine = _hero_main([_stray()], [], [])

	assert_false(Scenario.named("Stray").matches(engine.game_state(), MmReference.to_player(engine.hero().id), null))


func test_a_stray_puts_a_counter_on_each_other_stray_its_controller_has() -> void:
	var engine: MmEngine = _hero_main([_stray(), _stray(), Scenario.creature("Bear", 2, 2)], [_stray()], [_stray()])
	var hero_id: int = engine.hero().id
	var first: int = Scenario.permanents_named(engine, hero_id, "Stray")[0]
	var second: int = Scenario.permanents_named(engine, hero_id, "Stray")[1]
	assert_eq([Scenario.counters_on(engine, first, PLUS), Scenario.counters_on(engine, second, PLUS)], [1, 0],
		"The second put one on the first as it arrived.")

	Scenario.cast_and_resolve(engine, "Stray")
	Scenario.resolve_stack(engine)

	var third: int = Scenario.permanents_named(engine, hero_id, "Stray")[2]
	assert_eq(Scenario.counters_on(engine, first, PLUS), 2)
	assert_eq(Scenario.counters_on(engine, second, PLUS), 1)
	assert_eq(Scenario.counters_on(engine, third, PLUS), 0, "Each other one, and not itself.")
	assert_eq(Scenario.counters_on(engine, Scenario.permanent_named(engine, engine.hero().id, "Bear"), PLUS), 0)
	assert_eq(Scenario.counters_on(engine, Scenario.permanent_named(engine, engine.villain().id, "Stray"), PLUS), 0)


func test_a_lone_stray_puts_no_counters() -> void:
	var engine: MmEngine = _hero_main([], [], [_stray()])

	Scenario.cast_and_resolve(engine, "Stray")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.events_of(engine, CountersPutEvent).size(), 0)


func test_a_renamed_card_still_goes_by_its_originals_name() -> void:
	var engine: MmEngine = _renamed_strays_and_an_impostor()
	var hero_id: int = engine.hero().id
	var first: int = Scenario.permanent_named(engine, hero_id, "Violent Stray")

	Scenario.cast_and_resolve(engine, "Violent Stray")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, hero_id, "Violent Stray").size(), 2)
	assert_eq(Scenario.counters_on(engine, first, PLUS), 1, "Both were originally named Stray.")


func test_a_card_renamed_to_the_name_does_not_count() -> void:
	var engine: MmEngine = _renamed_strays_and_an_impostor()
	var impostor: int = Scenario.permanent_named(engine, engine.hero().id, "Stray")

	Scenario.cast_and_resolve(engine, "Violent Stray")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.counters_on(engine, impostor, PLUS), 0, "It was originally named Bear.")
	assert_false(Scenario.named("Stray").matches(engine.game_state(), MmReference.to_object(impostor), null))
	assert_true(Scenario.named("Bear").matches(engine.game_state(), MmReference.to_object(impostor), null))


func test_an_object_with_no_original_goes_by_its_exact_current_name() -> void:
	var engine: MmEngine = _hero_main(
		[Scenario.creature("Stray", 1, 1), Scenario.creature("Stray Cat", 1, 1), Scenario.creature("stray", 1, 1)], [], [])
	var state: MmGameState = engine.game_state()
	var matched: Array[String] = []
	for card_name: String in ["Stray", "Stray Cat", "stray"]:
		var permanent: MmGameObject = state.object(Scenario.permanent_named(engine, engine.hero().id, card_name))
		# As a token that is not a copy will be: a definition no Run Card was flattened into.
		permanent.definition.original = null
		if Scenario.named("Stray").matches(state, MmReference.to_object(permanent.id), null):
			matched.append(card_name)

	assert_eq(matched, ["Stray"])


## On the battlefield: a Violent Stray, which is a Stray renamed by a Modification, and a
## Bear renamed "Stray". Another Violent Stray is in hand.
func _renamed_strays_and_an_impostor() -> MmEngine:
	var cards: Array[MmCardDefinition] = [_stray(), Scenario.creature("Bear", 2, 2)]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(cards, no_cards)
	for run_card: MmRunCard in setup.hero.deck:
		var rename: ChangeNameModification = ChangeNameModification.new()
		rename.new_name = "Violent Stray" if run_card.base.name == "Stray" else "Stray"
		run_card.modifications.append(rename)
	var on_battlefield: Array[MmCardDefinition] = [Scenario.vanilla("Violent Stray"), Scenario.vanilla("Stray")]
	var in_hand: Array[MmCardDefinition] = [Scenario.vanilla("Violent Stray")]
	var engine: MmEngine = Scenario.permanents_ready_with(setup, on_battlefield, no_cards, in_hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## A 1/1: "When this creature enters, put a +1/+1 counter on each other creature you
## control originally named Stray."
func _stray() -> MmCardDefinition:
	var you_control: ControlledByFilter = ControlledByFilter.new()
	you_control.whose = MmTrigger.Whose.YOU
	var others: MmFilter = Scenario.all_of([you_control, Scenario.is_not(IsSourceFilter.new()), Scenario.named("Stray")])
	return Scenario.creature("Stray", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.put_counters(PLUS, 1, Scenario.each_creature(others))])])


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
