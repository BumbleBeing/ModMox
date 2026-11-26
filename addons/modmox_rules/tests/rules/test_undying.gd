extends GutTest
## The keyword undying (CR 702.93a): "When this creature dies, if it had no +1/+1 counters on
## it, return it to the battlefield under its owner's control with a +1/+1 counter on it."
## "It" is the card the creature became in the graveyard (engine ADR 0096). Ghoul is a 1/1
## costing {0} with undying; Shock, an instant costing {0}, deals 2 damage to any target.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS_ONE := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const NO_CARDS: Array[MmCardDefinition] = []


func test_with_no_counters_it_returns_with_a_counter() -> void:
	var engine: MmEngine = _hero_main([Scenario.ghoul()], _held(1))
	var ghoul: int = Scenario.permanent_named(engine, engine.hero().id, "Ghoul")

	_shock(engine, ghoul)

	var returned: int = Scenario.permanent_named(engine, engine.hero().id, "Ghoul")
	assert_ne(returned, -1, "Back on the battlefield.")
	assert_ne(returned, ghoul, "ADR 0008: a new object.")
	assert_eq(Scenario.counters_on(engine, returned, PLUS_ONE), 1)
	assert_eq(engine.game_state().object(returned).controlled_since_game_turn, engine.game_state().game_turn,
		"CR 302.6: it has summoning sickness again.")
	assert_eq(Scenario.card_in_graveyard(engine, engine.hero(), "Ghoul"), -1)


func test_returned_with_a_counter_it_stays_dead_the_second_time() -> void:
	var engine: MmEngine = _hero_main([Scenario.ghoul()], _held(2))
	_shock(engine, Scenario.permanent_named(engine, engine.hero().id, "Ghoul"))
	var triggered_before: int = Scenario.events_of(engine, AbilityTriggeredEvent).size()

	_shock(engine, Scenario.permanent_named(engine, engine.hero().id, "Ghoul"))

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Ghoul"), -1)
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Ghoul"), -1)
	assert_eq(Scenario.events_of(engine, AbilityTriggeredEvent).size(), triggered_before,
		"CR 603.4: it had a +1/+1 counter as it died, so it never triggers.")


func test_a_counter_put_on_it_keeps_it_from_returning() -> void:
	var held: Array[MmCardDefinition] = _held(1)
	held.append(Scenario.free_counters("Grow", PLUS_ONE, 1))
	var engine: MmEngine = _hero_main([Scenario.ghoul()], held)
	var first: int = Scenario.permanent_named(engine, engine.hero().id, "Ghoul")
	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(first)]), "")

	_shock(engine, first)
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Ghoul"), -1,
		"A 2/2 with a counter, dealt 2, stays in the graveyard.")


func test_exiled_from_the_graveyard_before_it_resolves_nothing_returns() -> void:
	var held: Array[MmCardDefinition] = _held(1)
	held.append(Scenario.free_bury())
	var engine: MmEngine = _hero_main([Scenario.ghoul()], held)
	var ghoul: int = Scenario.permanent_named(engine, engine.hero().id, "Ghoul")
	assert_eq(Scenario.cast(engine, _a_shock(engine), [MmReference.to_object(ghoul)]), "")
	assert_eq(Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var stack: Array[MmGameObject] = running.game_state().stack.objects()
		return stack.size() == 1 and stack[0].ability != null and running.pending_decision() is PriorityDecision \
			and running.pending_decision().player_id == running.hero().id), "")

	var dead: int = Scenario.card_in_graveyard(engine, engine.hero(), "Ghoul")
	assert_eq(Scenario.cast_and_resolve(engine, "Bury", [MmReference.to_object(dead)]), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Ghoul"), -1)
	assert_ne(Scenario.card_in_exile(engine, engine.hero(), "Ghoul"), -1, "It stays in exile: it is a new object there.")


func test_a_token_with_undying_never_returns() -> void:
	var held: Array[MmCardDefinition] = _held(1)
	var undying_cat: MmCardDefinition = Scenario.cat()
	undying_cat.abilities = [UndyingAbility.new()]
	held.append(Scenario.free_tokens("Kittens", undying_cat))
	var engine: MmEngine = _hero_main(NO_CARDS, held)
	assert_eq(Scenario.cast_and_resolve(engine, "Kittens"), "")

	_shock(engine, Scenario.tokens_on_battlefield(engine)[0])

	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0, "CR 111.8: a token that left never comes back.")


func test_copies_and_replays_return_it_the_same_way() -> void:
	var setup: MmEncounterSetup = Scenario.combat_setup([Scenario.ghoul()], [], _held(1))
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [Scenario.ghoul()], [], _held(1), NO_CARDS,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine)
	_shock(engine, Scenario.permanent_named(engine, engine.hero().id, "Ghoul"))

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


## The Hero in their main phase of Game Turn 3, having cast [param hero_permanents] on Game
## Turn 1 and holding [param hero_extras].
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, NO_CARDS, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, NO_CARDS, hero_extras, NO_CARDS,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## [param count] Shocks, each its own card so that the Hero holds that many.
func _held(count: int) -> Array[MmCardDefinition]:
	var shocks: Array[MmCardDefinition] = []
	for index: int in count:
		shocks.append(Scenario.free_shock("Shock %d" % (index + 1), 2))
	return shocks


## One of the Hero's Shocks in hand, or -1.
func _a_shock(engine: MmEngine) -> int:
	for card: MmGameObject in engine.hero().hand.objects():
		if engine.game_state().characteristics_of(card).name.begins_with("Shock"):
			return card.id
	return -1


## Casts one of the Hero's Shocks at [param object_id] and lets the stack resolve.
func _shock(engine: MmEngine, object_id: int) -> void:
	assert_eq(Scenario.cast(engine, _a_shock(engine), [MmReference.to_object(object_id)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
