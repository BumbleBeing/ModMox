extends GutTest
## "If this is the [Nth] time this ability has resolved this turn" (ADR 0056): an ability
## counts each time it resolves, for its own source object and its own place among that
## object's abilities, starting again each turn. The ability resolving now is one of them.
## A permanent that leaves and returns is a new object with a new count (ADR 0008).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE


func test_the_second_resolution_this_turn_is_the_second_time_and_the_third_is_not() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker()], [])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")

	assert_eq(_activate_and_resolve(engine, ticker), 21, "The first time.")
	assert_eq(_activate_and_resolve(engine, ticker), 31, "The second time, counting this one.")
	assert_eq(_activate_and_resolve(engine, ticker), 32, "The third time.")


func test_the_count_starts_again_each_turn_the_other_players_too() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker()], [])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	_activate_and_resolve(engine, ticker)

	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)
	assert_eq((engine.pending_decision() as PriorityDecision).player_id, engine.hero().id)

	assert_eq(_activate_and_resolve(engine, ticker), 22, "The first time in the Villain's turn.")
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain, as the active player, has it first.
	assert_eq(_activate_and_resolve(engine, ticker), 32)


func test_two_permanents_with_it_count_apart() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker(), Scenario.ticker("Second Ticker")], [])
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	var second: int = Scenario.permanent_named(engine, engine.hero().id, "Second Ticker")

	assert_eq(_activate_and_resolve(engine, first), 21)
	assert_eq(_activate_and_resolve(engine, second), 22, "Its own first time.")
	assert_eq(_activate_and_resolve(engine, first), 32)


func test_each_ability_of_one_permanent_counts_apart() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker("Twin Ticker", 2)], [])
	var twin: int = Scenario.permanent_named(engine, engine.hero().id, "Twin Ticker")

	assert_eq(_activate_and_resolve(engine, twin, 0), 21)
	assert_eq(_activate_and_resolve(engine, twin, 1), 22, "The other ability's first time.")
	assert_eq(_activate_and_resolve(engine, twin, 0), 32)


func test_one_that_leaves_and_returns_is_a_new_object_that_starts_again() -> void:
	# ADR 0008: the count was on the object that left.
	var engine: MmEngine = _hero_main([Scenario.ticker()], [Scenario.free_destroy("Kill"), Scenario.free_reanimate("Reanimate")])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	_activate_and_resolve(engine, ticker)

	Scenario.cast_and_resolve(engine, "Kill", [MmReference.to_object(ticker)])
	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Ticker")
	Scenario.cast_and_resolve(engine, "Reanimate", [MmReference.to_object(dead)])
	var returned: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")

	assert_ne(returned, ticker)
	assert_eq(_activate_and_resolve(engine, returned), 22, "Its first time.")


func test_a_countered_ability_has_not_resolved() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker()], [Scenario.free_stifle("Stifle")])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	Scenario.activate(engine, ticker)

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Stifle"), [MmReference.to_object(Scenario.stack_ids(engine)[0])])
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, 20)
	assert_eq(_activate_and_resolve(engine, ticker), 21, "The first time it resolved.")
	assert_eq(_activate_and_resolve(engine, ticker), 31)


func test_its_abilities_still_count_for_it_after_it_leaves() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker()], [Scenario.free_destroy("Kill")])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	Scenario.activate(engine, ticker)
	Scenario.activate(engine, ticker)

	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Kill"), [MmReference.to_object(ticker)])
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Ticker").size(), 0)
	assert_eq(engine.hero().life, 31, "1, then 10: both came from the Ticker that died.")


func test_a_triggered_ability_counts_too_and_doubles_on_its_second_time() -> void:
	# Scythecat Cub's shape: "put a +1/+1 counter on target creature you control. If this is
	# the second time this ability has resolved this turn, double the number of +1/+1
	# counters on that creature instead."
	var spells: Array[MmCardDefinition] = [_draw_one("Study"), _draw_one("Ponder"), _draw_one("Muse")]
	var engine: MmEngine = _hero_main([Scenario.creature("Bear", 2, 2), _cub()], spells)
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	var counted: Array[int] = []

	for spell: MmCardDefinition in spells:
		Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), spell.name))
		assert_eq(Scenario.choose_target(engine, MmReference.to_object(bear)), "", spell.name)
		Scenario.resolve_stack(engine)
		counted.append(Scenario.counters_on(engine, bear, PLUS))

	assert_eq(counted, [1, 2, 3], "One counter; doubled from 1 to 2 instead; one counter again.")


func test_off_the_stack_it_is_never_true() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker()], [])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, ticker)

	assert_false(Scenario.times_resolved(1).is_true(engine.game_state(), context), "There is no ability resolving.")


func test_a_copy_of_the_state_keeps_the_count_and_goes_its_own_way() -> void:
	var engine: MmEngine = _hero_main([Scenario.ticker()], [])
	var ticker: int = Scenario.permanent_named(engine, engine.hero().id, "Ticker")
	_activate_and_resolve(engine, ticker)

	var copy: MmGameState = engine.game_state().duplicate_state()
	_activate_and_resolve(engine, ticker)

	assert_eq(copy.times_resolved_this_turn(ticker, 0), 1)
	assert_eq(engine.game_state().times_resolved_this_turn(ticker, 0), 2)


## Activates ability [param ability_index] of [param object_id], lets it resolve, and
## returns the Hero's life.
func _activate_and_resolve(engine: MmEngine, object_id: int, ability_index: int = 0) -> int:
	assert_eq(Scenario.activate_ability(engine, object_id, ability_index), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	return engine.hero().life


## A 1/1 costing {0}: "Whenever you cast a spell, put a +1/+1 counter on target creature
## you control. If this is the second time this ability has resolved this turn, double the
## number of +1/+1 counters on that creature instead."
func _cub() -> MmCardDefinition:
	var yours: ControlledByFilter = ControlledByFilter.new()
	yours.whose = MmTrigger.Whose.YOU
	var effect: InsteadEffect = Scenario.instead(Scenario.times_resolved(2),
		Scenario.put_counters(PLUS, 1, Scenario.targeted(0)), Scenario.double_counters(PLUS, Scenario.targeted(0)))
	return Scenario.creature("Cub", 1, 1, [Scenario.triggered(Scenario.casts(null, MmTrigger.Whose.YOU), [effect],
		[Scenario.target(Scenario.all_of([Scenario.of_type(CardType.CREATURE), yours]))])])


## An instant costing {0}: "Draw a card."
func _draw_one(card_name: String) -> MmCardDefinition:
	return Scenario.instant(card_name, Scenario.mana_cost(0), [], [Scenario.draw_cards(1, Scenario.you())])


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] on the
## battlefield, holding [param hero_extras].
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
