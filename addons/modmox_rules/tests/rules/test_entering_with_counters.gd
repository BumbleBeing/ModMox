extends GutTest
## "This creature enters with [N] [kind] counters on it." (CR 614.1c, ADR 0076): a replacement
## effect its own permanent generates as it enters, so the counters are on it as it arrives
## and its "enters" abilities see them (CR 614.12). "X" there is the X chosen as its spell was
## cast (CR 107.3m), and 0 when it was not cast.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_cast_with_x_of_three_it_enters_with_three_counters() -> void:
	var engine: MmEngine = _hero_main([Scenario.hydra()])

	assert_eq(Scenario.cast_with_x(engine, Scenario.card_in_hand(engine, engine.hero(), "Hydra"), 3), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var hydra: int = Scenario.permanent_named(engine, engine.hero().id, "Hydra")
	assert_ne(hydra, -1)
	assert_eq(Scenario.counters_on(engine, hydra, PLUS), 3)
	assert_eq(Scenario.pt(engine, hydra), [3, 3])
	var arrived: ZoneChangeEvent = _move_onto_battlefield(engine, hydra)
	assert_eq(arrived.counters_on_arrival.get(PLUS, 0), 3, "On it as it arrives.")


func test_its_enters_trigger_sees_the_counters() -> void:
	# "When this creature enters, you gain life equal to its power."
	var gain: GainLifeEffect = Scenario.gain_life(0, Scenario.you())
	var power: PowerValue = PowerValue.new()
	power.selection = SourceSelection.new()
	gain.amount = power
	var hydra: MmCardDefinition = Scenario.hydra("Hydra", [Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [gain])])
	var engine: MmEngine = _hero_main([hydra])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_with_x(engine, Scenario.card_in_hand(engine, engine.hero(), "Hydra"), 2), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 2)


func test_with_x_of_zero_a_zero_toughness_creature_dies() -> void:
	var engine: MmEngine = _hero_main([Scenario.hydra()])

	assert_eq(Scenario.cast_with_x(engine, Scenario.card_in_hand(engine, engine.hero(), "Hydra"), 0), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Hydra"), -1, "CR 704.5f.")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Hydra"), -1)


func test_put_onto_the_battlefield_without_being_cast_it_gets_none() -> void:
	# CR 107.3m: X is 0 when it was not cast. A fixed number still applies.
	var two: MmCardDefinition = Scenario.creature("Pair", 0, 1, [Scenario.enters_with_counters(Scenario.constant(2))])
	var none: MmCardDefinition = Scenario.creature("Naught", 0, 1, [Scenario.enters_with_counters(Scenario.chosen_x())])
	var fetch: MmCardDefinition = Scenario.free_seek("Seek", Scenario.search(Scenario.of_type(MmCardTypes.CardType.CREATURE), 2,
		MmZone.Kind.BATTLEFIELD))
	var engine: MmEngine = _hero_main([fetch], [two, none])
	assert_eq(Scenario.cast_and_resolve(engine, "Seek"), "")
	var search: ChooseCardsInLibraryDecision = engine.pending_decision() as ChooseCardsInLibraryDecision
	if search == null:
		assert_eq(Scenario.pass_to_search(engine), "")
		search = engine.pending_decision() as ChooseCardsInLibraryDecision
	var picks: Array[int] = []
	for id: int in search.candidate_ids:
		var card_name: String = engine.game_state().object(id).definition.name
		if (card_name == "Pair" or card_name == "Naught") and picks.size() < 2:
			picks.append(id)
	assert_eq(engine.submit(picks), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.counters_on(engine, Scenario.permanent_named(engine, engine.hero().id, "Pair"), PLUS), 2)
	assert_eq(Scenario.counters_on(engine, Scenario.permanent_named(engine, engine.hero().id, "Naught"), PLUS), 0)


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_enters_with_counters.tres"
	assert_eq(ResourceSaver.save(Scenario.hydra(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var entering: EntersWithCountersAbility = loaded.abilities[0] as EntersWithCountersAbility
	assert_not_null(entering)
	assert_eq(entering.kind, PLUS)
	assert_true(entering.amount is ChosenXValue)
	assert_eq(loaded.mana_cost.x_count, 1)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _move_onto_battlefield(engine: MmEngine, new_id: int) -> ZoneChangeEvent:
	for event: MmEvent in Scenario.events_of(engine, ZoneChangeEvent):
		if (event as ZoneChangeEvent).new_object_id == new_id:
			return event as ZoneChangeEvent
	return null


func _birds() -> Array[MmCardDefinition]:
	return [Scenario.mana_bird("Mana Bird"), Scenario.mana_bird("Mana Bird")]


## Two Mana Birds and [param hand] for the Hero, with [param library] among their cards, in
## the Hero's main phase of Game Turn 3.
func _hero_main(hand: Array[MmCardDefinition], library: Array[MmCardDefinition] = []) -> MmEngine:
	var deck: Array[MmCardDefinition] = _birds()
	deck.append_array(library)
	var setup: MmEncounterSetup = Scenario.combat_setup(deck, [Scenario.creature("Ogre", 3, 3)], hand)
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, _birds(), [Scenario.creature("Ogre", 3, 3)], hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
