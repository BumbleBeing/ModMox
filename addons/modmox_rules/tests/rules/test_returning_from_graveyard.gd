extends GutTest
## "Return target creature card from your graveyard to the battlefield [tapped]" (Helping
## Hand). The card enters as a new object (ADR 0008) under its owner's control (CR 110.2),
## with summoning sickness, and its own "enters" abilities and others' trigger. Tapped, it
## is tapped as it arrives (CR 110.5b), so what triggers on its arrival sees it tapped. A
## mana value filter narrows the target (CR 202.3).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Reason := ZoneChangeEvent.Reason
const Comparison := ManaValueFilter.Comparison
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_the_card_returns_as_a_new_untapped_permanent_with_summoning_sickness() -> void:
	var engine: MmEngine = _engine(["Reanimate"])
	var hero: MmPlayer = engine.hero()
	_kill_both(engine)
	var dead: int = Scenario.card_in_graveyard(engine, hero, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Reanimate", [MmReference.to_object(dead)]), "")

	var returned: int = Scenario.permanent_named(engine, hero.id, "Bear")
	assert_ne(returned, -1, "On the battlefield.")
	assert_ne(returned, dead, "ADR 0008: a new object.")
	assert_eq(Scenario.card_in_graveyard(engine, hero, "Bear"), -1)
	var state: MmGameState = engine.game_state()
	assert_eq(state.object(returned).controller_id, hero.id, "CR 110.2: under its owner's control.")
	assert_false(state.object(returned).is_tapped, "CR 110.5b: untapped unless the effect says otherwise.")
	assert_true(state.is_summoning_sick(state.object(returned)))
	var moves: Array[ZoneChangeEvent] = _moves_with(engine, Reason.RETURN_TO_BATTLEFIELD)
	assert_eq(moves.size(), 1)
	assert_eq(moves[0].from_zone_kind, MmZone.Kind.GRAVEYARD)
	assert_false(moves[0].tapped_on_arrival)


func test_tapped_it_enters_tapped() -> void:
	var engine: MmEngine = _engine(["Tapped Reanimate"])
	var hero: MmPlayer = engine.hero()
	_kill_both(engine)

	assert_eq(Scenario.cast_and_resolve(engine, "Tapped Reanimate",
		[MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))]), "")

	var returned: int = Scenario.permanent_named(engine, hero.id, "Bear")
	assert_true(engine.game_state().object(returned).is_tapped, "CR 110.5b")
	assert_true(_moves_with(engine, Reason.RETURN_TO_BATTLEFIELD)[0].tapped_on_arrival)
	assert_eq(Scenario.events_of(engine, TapEvent).filter(func(event: MmEvent) -> bool:
		return (event as TapEvent).object_id == returned).size(), 0, "Tapped as it arrives, never tapped afterward.")


func test_its_enters_ability_sees_it_tapped_and_another_permanents_enters_ability_triggers() -> void:
	var proud: MmCardDefinition = Scenario.creature("Bear", 2, 2, [Scenario.triggered(Scenario.enters(IsSourceFilter.new()),
		[Scenario.gain_life(3, Scenario.you())], [], Scenario.condition(SourceSelection.new(), IsTappedFilter.new()))])
	var watcher: MmCardDefinition = Scenario.artifact("Watcher", [Scenario.triggered(
		Scenario.enters(Scenario.of_type(MmCardTypes.CardType.CREATURE), MmTrigger.Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _engine(["Tapped Reanimate"], proud, watcher)
	var hero: MmPlayer = engine.hero()
	_kill_both(engine)
	Scenario.resolve_stack(engine)
	var life: int = hero.life

	Scenario.cast_and_resolve(engine, "Tapped Reanimate", [MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))])
	Scenario.resolve_stack(engine)

	assert_eq(hero.life, life + 3 + 1, "CR 603.4: tapped as it entered; and the Watcher saw a creature enter.")


func test_returning_tapped_with_counters_does_both() -> void:
	var back: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(Scenario.targeted(0))
	back.tapped = true
	back.counters = Scenario.constant(2)
	var spell: MmCardDefinition = Scenario.instant("Reanimate", Scenario.mana_cost(0), [Scenario.your_dead_creature()], [back])
	var engine: MmEngine = _engine(["Reanimate"], null, null, spell)
	var hero: MmPlayer = engine.hero()
	_kill_both(engine)

	Scenario.cast_and_resolve(engine, "Reanimate", [MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))])

	var returned: int = Scenario.permanent_named(engine, hero.id, "Bear")
	assert_true(engine.game_state().object(returned).is_tapped)
	assert_eq(Scenario.counters_on(engine, returned, PLUS), 2)


func test_it_does_not_resolve_if_its_target_left_the_graveyard_first() -> void:
	var engine: MmEngine = _engine(["Reanimate", "Raise"])
	var hero: MmPlayer = engine.hero()
	_kill_both(engine)
	var bear: MmReference = MmReference.to_object(Scenario.card_in_graveyard(engine, hero, "Bear"))
	Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Reanimate"), [bear])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, hero, "Raise"), [bear]), "")
	Scenario.resolve_stack(engine)

	assert_eq(_moves_with(engine, Reason.RETURN_TO_BATTLEFIELD).size(), 0)
	assert_eq(Scenario.permanent_named(engine, hero.id, "Bear"), -1, "CR 608.2b: the Bear in hand is a new object.")


func test_a_mana_value_filter_narrows_the_graveyard_cards_that_can_be_targeted() -> void:
	var engine: MmEngine = _engine([])
	var hero: MmPlayer = engine.hero()
	_kill_both(engine)
	var bear: int = Scenario.card_in_graveyard(engine, hero, "Bear")
	var ogre: int = Scenario.card_in_graveyard(engine, hero, "Ogre")
	# Yours, as the Villain may have discarded a Wolf.
	var creature: MmFilter = Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), Scenario.owned_by(MmTrigger.Whose.YOU)])

	var at_most_zero: Array[int] = _graveyard_targets(engine, Scenario.all_of([creature, Scenario.mana_value(0)]))
	var at_most_one: Array[int] = _graveyard_targets(engine, Scenario.all_of([creature, Scenario.mana_value(1)]))
	var at_least_one: Array[int] = _graveyard_targets(engine, Scenario.all_of([creature, Scenario.mana_value(1, Comparison.OR_GREATER)]))

	assert_eq(at_most_zero, [bear] as Array[int], "The Ogre's mana value is 1.")
	assert_eq(at_most_one, [bear, ogre] as Array[int], "Each is 1 or less.")
	assert_eq(at_least_one, [ogre] as Array[int])


## Destroys every creature, putting the Hero's Bear and Ogre into the Hero's graveyard.
func _kill_both(engine: MmEngine) -> void:
	assert_eq(Scenario.cast_and_resolve(engine, "Wrath"), "")


func _graveyard_targets(engine: MmEngine, filter: MmFilter) -> Array[int]:
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)
	var found: Array[int] = []
	for target: MmReference in Scenario.target_graveyard_card(filter).legal_targets(engine.game_state(), context):
		found.append(target.id)
	return found


func _moves_with(engine: MmEngine, reason: ZoneChangeEvent.Reason) -> Array[ZoneChangeEvent]:
	var found: Array[ZoneChangeEvent] = []
	for event: MmEvent in engine.event_log():
		var moved: ZoneChangeEvent = event as ZoneChangeEvent
		if moved != null and moved.reason == reason:
			found.append(moved)
	return found


## The Hero's main phase on Game Turn 3, with a Bear ({0}) and an Ogre ({1}) cast on Game
## Turn 1 from a Forest, and [param watcher] too when given, the Hero holding a Wrath
## ("destroy each creature") and each card named in [param needs]: a free Reanimate
## ([param reanimate], or "return target creature card from your graveyard to the
## battlefield"), a Tapped Reanimate (the same, "tapped") and a free Raise.
func _engine(needs: Array[String], bear: MmCardDefinition = null, watcher: MmCardDefinition = null,
		reanimate: MmCardDefinition = null) -> MmEngine:
	var bear_card: MmCardDefinition = Scenario.creature("Bear", 2, 2) if bear == null else bear
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 2, 2, [], Scenario.mana_cost(1))
	var wrath: MmCardDefinition = Scenario.instant("Wrath", Scenario.mana_cost(0), [], [Scenario.destroy(Scenario.each_creature())])
	var spells: Dictionary[String, MmCardDefinition] = {
		"Reanimate": Scenario.free_reanimate("Reanimate") if reanimate == null else reanimate,
		"Tapped Reanimate": Scenario.free_reanimate("Tapped Reanimate", true),
		"Raise": Scenario.free_raise("Raise"),
	}
	var hero_cards: Array[MmCardDefinition] = [Scenario.basic_land("Forest"), bear_card, ogre, wrath]
	for spell_name: String in needs:
		hero_cards.append(spells[spell_name])
	var first_turn: Array[MmCardDefinition] = [bear_card, ogre]
	if watcher != null:
		hero_cards.append(watcher)
		first_turn.push_front(watcher)
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(hero_cards), Scenario.cycled([Scenario.creature("Wolf", 2, 2)]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 1, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		if Scenario.play_first_land(running) == -1:
			return false
		for definition: MmCardDefinition in first_turn:
			if Scenario.cast_and_resolve(running, definition.name) != "" or Scenario.resolve_stack(running) != "":
				return false
		if Scenario.play_until_step(running, 3, MmTurn.Step.PRECOMBAT_MAIN) != "":
			return false
		var held: Array[String] = Scenario.names(running, running.hero().hand)
		for spell_name: String in needs + ["Wrath"]:
			if not held.has(spell_name):
				return false
		return true, 1000)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
