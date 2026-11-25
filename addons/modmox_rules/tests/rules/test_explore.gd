extends GutTest
## Explore (CR 701.44a, engine ADR 0090): the exploring permanent's controller reveals the
## top card of their library. A land goes to their hand. Otherwise the permanent gets a +1/+1
## counter, and they may put the card into their graveyard: an ExploreDecision of that one
## card, a SurveilDecision, answered [graveyarded, kept]. Explorers are 1/1s costing {0}
## with "When this creature enters, it explores."; the Hero's deck cycles through a Bear, an
## Elf, a Forest, a Gift (an instant costing {0}) and an Explorer.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE

## The setup _hero_main() last started from, for a replay.
var _setup: MmEncounterSetup = null


func test_a_land_on_top_is_revealed_and_put_into_its_hand_and_no_counter_is_put() -> void:
	var engine: MmEngine = _hero_main(["Forest"])
	var forest: int = engine.hero().library.top().id

	assert_eq(Scenario.cast_and_resolve(engine, "Explorer"), "")
	assert_eq(Scenario.resolve_stack(engine), "", "A land asks nothing, so autoplay meets no explore.")

	var explorer: int = Scenario.permanent_named(engine, engine.hero().id, "Explorer")
	assert_eq(Scenario.counters_on(engine, explorer, PLUS), 0)
	assert_ne(engine.hero().library.top().id, forest, "It left the library.")
	var revealed: Array[MmGameObject] = []
	for card: MmGameObject in engine.hero().hand.objects():
		if engine.game_state().characteristics_of(card).name == "Forest" and card.is_known_to(engine.villain().id):
			revealed.append(card)
	assert_eq(revealed.size(), 1, "CR 701.44a: revealed, it is in the hand, known to the other player.")


func test_a_nonland_on_top_gives_a_counter_and_asks_whether_to_graveyard_it() -> void:
	var engine: MmEngine = _hero_main(["Gift"])
	var gift: int = engine.hero().library.top().id
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Explorer")), "")

	assert_eq(Scenario.pass_to_explore(engine), "")

	var decision: ExploreDecision = engine.pending_decision() as ExploreDecision
	assert_eq(decision.card_ids, [gift] as Array[int])
	assert_true(decision is SurveilDecision, "It is answered as a surveil of that one card is.")


func test_kept_it_stays_on_top_known_to_both_players_and_the_creature_gets_a_counter() -> void:
	var engine: MmEngine = _hero_main(["Gift"])
	var gift: int = engine.hero().library.top().id
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Explorer")), "")
	assert_eq(Scenario.pass_to_explore(engine), "")

	assert_eq(engine.submit([[], [gift]]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var explorer: int = Scenario.permanent_named(engine, engine.hero().id, "Explorer")
	assert_eq(Scenario.counters_on(engine, explorer, PLUS), 1)
	assert_eq(engine.hero().library.top().id, gift, "The same object, still on top.")
	assert_true(engine.hero().library.top().is_known_to(engine.villain().id), "CR 701.44a: it was revealed.")


func test_graveyarded_it_goes_to_its_graveyard_and_the_creature_still_gets_a_counter() -> void:
	var engine: MmEngine = _hero_main(["Gift"])
	var gift: int = engine.hero().library.top().id
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Explorer")), "")
	assert_eq(Scenario.pass_to_explore(engine), "")

	assert_eq(engine.submit([[gift], []]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Gift"), -1)
	assert_eq(Scenario.counters_on(engine, Scenario.permanent_named(engine, engine.hero().id, "Explorer"), PLUS), 1)


func test_a_creature_that_has_left_still_explores_but_gets_no_counter() -> void:
	# CR 701.44a, 608.2h: it explores as it last existed, and nothing is there to get the counter.
	var engine: MmEngine = _hero_main(["Gift"], [Scenario.free_bounce("Bounce")])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Explorer")), "")
	assert_eq(Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		var stack: Array[MmGameObject] = running.game_state().stack.objects()
		return running.pending_decision() is PriorityDecision and not stack.is_empty() and not stack.back().is_card_or_copy()), "")
	var explorer: int = Scenario.permanent_named(engine, engine.hero().id, "Explorer")
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bounce"), [MmReference.to_object(explorer)]), "")

	assert_eq(Scenario.pass_to_explore(engine), "")
	assert_eq(engine.submit([[engine.hero().library.top().id], []]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Gift"), -1, "It still revealed and graveyarded the card.")
	assert_eq(Scenario.events_of(engine, CountersPutEvent).size(), 0)


func test_a_map_has_target_creature_you_control_explore_only_as_a_sorcery() -> void:
	var engine: MmEngine = _hero_main(["Gift"], [Scenario.free_tokens("Charter", Scenario.map())], [_bear(), Scenario.elf()])
	assert_eq(Scenario.cast_and_resolve(engine, "Charter"), "")
	var map: int = Scenario.tokens_on_battlefield(engine)[0]
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.activate(engine, map, [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.pass_to_explore(engine), "")
	assert_eq(engine.submit([[], [engine.hero().library.top().id]]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, bear, PLUS), 1)
	assert_eq(Scenario.tokens_on_battlefield(engine).size(), 0, "It was sacrificed.")


func test_a_map_is_not_offered_outside_its_controllers_main_phase() -> void:
	var engine: MmEngine = _hero_main(["Gift"], [Scenario.free_tokens("Charter", Scenario.map())], [_bear(), Scenario.elf()])
	assert_eq(Scenario.cast_and_resolve(engine, "Charter"), "")
	var map: int = Scenario.tokens_on_battlefield(engine)[0]

	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain has it first in their own turn.

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, map), -1,
		"CR 602.5d: only as a sorcery.")


func test_a_copy_and_a_replay_ask_the_same_explore() -> void:
	var engine: MmEngine = _hero_main(["Gift"])
	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Explorer")), "")
	assert_eq(Scenario.pass_to_explore(engine), "")

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(1))
	var replayed: MmEngine = MmEngine.replay(_setup, engine.decision_log())

	assert_true(copy.pending_decision() is ExploreDecision)
	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_explore.tres"
	assert_eq(ResourceSaver.save(Scenario.map(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var explores: ExploreEffect = (loaded.abilities[0] as ActivatedAbility).effects[0] as ExploreEffect
	assert_true(explores.selection is TargetSelection)
	DirAccess.remove_absolute(path)


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## The Hero's first main phase of Game Turn 3 holding an Explorer and [param extras], with
## [param permanents] (a Bear unless others are given) cast on Game Turn 1 and the top of
## their library holding [param tops] in order.
func _hero_main(tops: Array[String], extras: Array[MmCardDefinition] = [], permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var cast_first: Array[MmCardDefinition] = permanents.duplicate()
	if cast_first.is_empty():
		cast_first.append(_bear())
	var gift: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	var deck: Array[MmCardDefinition] = [_bear(), Scenario.elf(), Scenario.basic_land("Forest"), gift, Scenario.explorer()]
	deck.append_array(extras)
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(deck), Scenario.cycled([]))
	_setup = setup
	var hand: Array[MmCardDefinition] = [Scenario.explorer()]
	hand.append_array(extras)
	var engine: MmEngine = Scenario.top_ready(setup, cast_first, hand, tops)
	assert_not_null(engine, "No seed gave the needed hand and library.")
	return engine
