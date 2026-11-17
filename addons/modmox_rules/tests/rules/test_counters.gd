extends GutTest
## CR 122: counters on permanents. A +1/+1 or -1/-1 counter changes power and toughness in
## layer 7c (CR 613.4c), and a permanent with both loses the same number of each as a
## state-based action (CR 704.5q). Counters belong to the permanent, so they are gone once
## it changes zones (CR 122.2, ADR 0008).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const MINUS := MmCounter.Kind.MINUS_ONE_MINUS_ONE


func test_a_plus_one_plus_one_counter_makes_a_two_two_a_three_three() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Grow", PLUS, 1)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [3, 3])
	assert_eq(Scenario.counters_on(engine, bear, PLUS), 1)
	assert_eq([Scenario.now(engine, bear).base_power, Scenario.now(engine, bear).base_toughness], [2, 2])
	var put: Array[MmEvent] = Scenario.events_of(engine, CountersPutEvent)
	assert_eq(put.size(), 1)
	assert_eq([(put[0] as CountersPutEvent).object_id, (put[0] as CountersPutEvent).kind, (put[0] as CountersPutEvent).amount],
		[bear, PLUS, 1])


func test_counters_of_one_kind_add_up() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Grow", PLUS, 2), Scenario.free_counters("Swell", PLUS, 1)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Swell", [_object(bear)])

	assert_eq(Scenario.counters_on(engine, bear, PLUS), 3)
	assert_eq(Scenario.pt(engine, bear), [5, 5])


func test_minus_one_minus_one_counters_that_leave_no_toughness_kill_the_creature() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Wither", MINUS, 2)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Wither", [_object(bear)])

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Bear").size(), 0)
	assert_eq(Scenario.last_reason_into(engine, MmZone.Kind.GRAVEYARD), ZoneChangeEvent.Reason.ZERO_TOUGHNESS,
		"CR 704.5f: not destruction.")


func test_a_minus_one_minus_one_counter_shrinks_a_creature_that_survives_it() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Wither", MINUS, 1)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Wither", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [1, 1])
	assert_eq(Scenario.counters_on(engine, bear, MINUS), 1)


func test_counters_add_to_set_power_and_toughness_and_outlast_a_pump() -> void:
	var shrink: MmCardDefinition = Scenario.creature_spell_until_end_of_turn("Shrink", Scenario.set_pt(0, 1, Scenario.targeted(0)))
	var engine: MmEngine = _hero_main([_bear()], [],
		[Scenario.free_counters("Grow", PLUS, 1), shrink, Scenario.pump_spell("Pump", 3, 3)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Shrink", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Pump", [_object(bear)])

	assert_eq(Scenario.pt(engine, bear), [4, 5], "Layer 7b sets 0/1; 7c adds the pump and the counter.")
	Scenario.play_until_game_turn(engine, 4)
	assert_eq(Scenario.pt(engine, bear), [3, 3], "CR 514.2: the effects ended in cleanup; the counter stays.")
	assert_eq(Scenario.counters_on(engine, bear, PLUS), 1)


func test_a_permanent_with_both_kinds_loses_the_same_number_of_each() -> void:
	var engine: MmEngine = _hero_main([Scenario.creature("Giant", 4, 4)], [],
		[Scenario.free_counters("Grow", PLUS, 2), Scenario.free_counters("Wither", MINUS, 3)])
	var giant: int = Scenario.permanent_named(engine, engine.hero().id, "Giant")
	Scenario.cast_and_resolve(engine, "Grow", [_object(giant)])

	Scenario.cast_and_resolve(engine, "Wither", [_object(giant)])

	assert_eq(Scenario.counters_on(engine, giant, PLUS), 0, "CR 704.5q.")
	assert_eq(Scenario.counters_on(engine, giant, MINUS), 1)
	assert_eq(Scenario.pt(engine, giant), [3, 3])
	var removed: Array[MmEvent] = Scenario.events_of(engine, CountersRemovedEvent)
	assert_eq(removed.size(), 2)
	var kinds: Array[MmCounter.Kind] = []
	for event: MmEvent in removed:
		var removal: CountersRemovedEvent = event as CountersRemovedEvent
		assert_eq([removal.object_id, removal.amount], [giant, 2])
		assert_eq(removal.batch, removed[0].batch, "CR 704.3: both at once.")
		kinds.append(removal.kind)
	assert_eq(kinds, [PLUS, MINUS])


func test_a_card_that_leaves_the_battlefield_comes_back_without_its_counters() -> void:
	var engine: MmEngine = _hero_main([_bear()], [],
		[Scenario.free_counters("Grow", PLUS, 2), Scenario.free_destroy("Murder"), Scenario.free_raise("Raise")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Murder", [_object(bear)])
	Scenario.cast_and_resolve(engine, "Raise", [_object(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"))])

	Scenario.cast_and_resolve(engine, "Bear")

	var returned: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_ne(returned, bear, "ADR 0008: a new object.")
	assert_eq(Scenario.counters_on(engine, returned, PLUS), 0)
	assert_eq(Scenario.pt(engine, returned), [2, 2])


func test_a_characteristic_defining_creature_gets_its_counters_on_top() -> void:
	var count: CountValue = CountValue.new()
	count.selection = Scenario.each_creature()
	var defining: CharacteristicDefiningAbility = CharacteristicDefiningAbility.new()
	defining.power = count
	defining.toughness = count
	var engine: MmEngine = _hero_main([Scenario.creature("Crowd", 0, 0, [defining]), _bear()], [],
		[Scenario.free_counters("Grow", PLUS, 1)])
	var crowd: int = Scenario.permanent_named(engine, engine.hero().id, "Crowd")

	Scenario.cast_and_resolve(engine, "Grow", [_object(crowd)])

	assert_eq(Scenario.pt(engine, crowd), [3, 3], "Layer 7a counts two creatures; 7c adds the counter.")


func test_counters_go_on_each_permanent_a_selection_finds() -> void:
	var rally: MmCardDefinition = Scenario.instant("Rally", Scenario.mana_cost(0), [],
		[Scenario.put_counters(PLUS, 1, Scenario.each_creature())])
	var engine: MmEngine = _hero_main([_bear()], [Scenario.creature("Ogre", 3, 3)], [rally])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	Scenario.cast_and_resolve(engine, "Rally")

	assert_eq(Scenario.pt(engine, bear), [3, 3])
	assert_eq(Scenario.pt(engine, ogre), [4, 4])
	var put: Array[MmEvent] = Scenario.events_of(engine, CountersPutEvent)
	assert_eq(put.size(), 2)
	assert_eq(put[0].batch, put[1].batch, "All at once.")


func test_a_creature_puts_a_counter_on_itself_when_it_enters() -> void:
	var sprout: MmCardDefinition = Scenario.creature("Sprout", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.put_counters(PLUS, 1, SourceSelection.new())])])
	var engine: MmEngine = _hero_main([], [], [sprout])

	Scenario.cast_and_resolve(engine, "Sprout")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.pt(engine, Scenario.permanent_named(engine, engine.hero().id, "Sprout")), [2, 2])


func test_a_spell_whose_target_is_gone_puts_no_counters() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Grow", PLUS, 1), Scenario.free_destroy("Murder")])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Grow"), [_object(bear)])

	Scenario.cast_and_resolve(engine, "Murder", [_object(bear)])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.events_of(engine, CountersPutEvent).size(), 0, "CR 608.2b.")


func test_an_amount_of_zero_or_less_puts_no_counters() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Nothing", PLUS, 0)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Nothing", [_object(bear)])

	assert_eq(Scenario.events_of(engine, CountersPutEvent).size(), 0, "CR 107.1b.")
	assert_eq(Scenario.pt(engine, bear), [2, 2])


func test_both_players_see_a_permanents_counters() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Grow", PLUS, 2)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var seen: MmObjectView = _seen(engine.view_for(viewer), bear)
		assert_eq(seen.counters_of(PLUS), 2)
		assert_eq(seen.counters_of(MINUS), 0)
		assert_eq([seen.power, seen.toughness, seen.base_power, seen.base_toughness], [4, 4, 2, 2])


func test_a_counter_filter_matches_a_permanent_with_at_least_that_many_of_its_kind() -> void:
	var engine: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Grow", PLUS, 2), Scenario.free_counters("Swell", PLUS, 1)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, bear)
	var three_or_more: HasCountersFilter = Scenario.has_counters(PLUS, 3)
	Scenario.cast_and_resolve(engine, "Grow", [_object(bear)])
	assert_false(three_or_more.matches(engine.game_state(), _object(bear), context), "Two is not three or more.")
	assert_true(Scenario.has_counters(PLUS, 1).matches(engine.game_state(), _object(bear), context))

	Scenario.cast_and_resolve(engine, "Swell", [_object(bear)])

	assert_true(three_or_more.matches(engine.game_state(), _object(bear), context))
	assert_false(Scenario.has_counters(MINUS, 1).matches(engine.game_state(), _object(bear), context),
		"Counters of another kind do not count.")
	assert_false(three_or_more.matches(engine.game_state(), MmReference.to_player(engine.hero().id), context))


func test_a_copy_of_the_state_keeps_the_counters_and_replays_are_exact() -> void:
	var hero_cards: Array[MmCardDefinition] = [_bear()]
	var extras: Array[MmCardDefinition] = [Scenario.free_counters("Grow", PLUS, 1)]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, no_cards, extras)
	var original: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, no_cards, extras, no_cards, 3, Step.PRECOMBAT_MAIN)
	var bear: int = Scenario.permanent_named(original, original.hero().id, "Bear")
	var before: String = original.fingerprint()
	Scenario.cast_and_resolve(original, "Grow", [_object(bear)])

	var copy: MmGameState = original.game_state().duplicate_state()

	assert_ne(original.fingerprint(), before)
	assert_eq(copy.fingerprint(), original.game_state().fingerprint())
	assert_eq(copy.object(bear).counters_of(PLUS), 1)
	assert_eq(copy.characteristics_of(copy.object(bear)).power, 3)
	Scenario.play_until_game_turn(original, 5)
	var replayed: MmEngine = MmEngine.replay(setup, original.decision_log())
	assert_eq(replayed.fingerprint(), original.fingerprint())


func test_two_states_that_differ_only_in_counters_have_different_fingerprints() -> void:
	var with_grow: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Spell", PLUS, 1)])
	var with_nothing: MmEngine = _hero_main([_bear()], [], [Scenario.free_counters("Spell", PLUS, 0)])
	for engine: MmEngine in [with_grow, with_nothing]:
		Scenario.cast_and_resolve(engine, "Spell", [_object(Scenario.permanent_named(engine, engine.hero().id, "Bear"))])

	assert_ne(with_grow.fingerprint(), with_nothing.fingerprint())


func _object(id: int) -> MmReference:
	return MmReference.to_object(id)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _seen(view: MmPlayerView, object_id: int) -> MmObjectView:
	for seen: MmObjectView in view.battlefield:
		if seen.id == object_id:
			return seen
	return null


func _hero_main(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
