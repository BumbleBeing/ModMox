extends GutTest
## "Whenever one or more [kind] counters are put on [filter]" (CR 122.6, 603.2), as Dusk Legion
## Duelist's "Whenever one or more +1/+1 counters are put on this creature, draw a card. This
## ability triggers only once each turn." An effect puts its counters on each permanent at once,
## so it triggers once for each permanent an effect reaches, however many counters go there. A
## permanent that enters with counters had them put on it too (CR 122.6). "Whenever you put
## one or more +1/+1 counters on this creature", as Exemplar of Light says, counts only the
## counters its controller puts (CR 122.6, 122.6a).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const CardType := MmCardTypes.CardType
const Whose := MmTrigger.Whose
const PLUS := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const MINUS := MmCounter.Kind.MINUS_ONE_MINUS_ONE


func test_a_counter_put_on_it_triggers_it_and_that_creature_is_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.counter_watcher()], [Scenario.free_counters("Grow", PLUS, 1)])
	var watcher: int = _watcher(engine)
	var life: int = engine.hero().life
	assert_eq(_triggers_of(engine, "Counter Watcher"), 0, "It entered with no counters.")

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(watcher)]), "")

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 1)
	var trigger: MmGameObject = engine.game_state().object(stack[0])
	assert_eq(trigger.triggering_object_id, watcher, "\"That creature\" is the permanent the counters went on.")
	assert_eq(trigger.triggering_player_id, engine.hero().id, "\"That player\" is its controller.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 1)


func test_two_counters_put_at_once_trigger_it_once() -> void:
	var engine: MmEngine = _hero_main([Scenario.counter_watcher()], [Scenario.free_counters("Grow", PLUS, 2)])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(_watcher(engine))]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Counter Watcher"), 1, "One or more.")
	assert_eq(engine.hero().life, life + 1)


func test_counters_put_on_another_creature_do_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.counter_watcher(), _bear()], [Scenario.free_counters("Grow", PLUS, 1)])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Counter Watcher"), 0, "This creature only.")


func test_a_counter_of_another_kind_does_not_trigger_it() -> void:
	var engine: MmEngine = _hero_main([Scenario.counter_watcher()], [Scenario.free_counters("Wither", MINUS, 1)])

	assert_eq(Scenario.cast_and_resolve(engine, "Wither", [MmReference.to_object(_watcher(engine))]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, _watcher(engine), MINUS), 1)
	assert_eq(_triggers_of(engine, "Counter Watcher"), 0, "+1/+1 counters only.")


func test_entering_with_counters_triggers_it() -> void:
	# CR 122.6: counters an object enters with are put on it.
	var hydra: MmCardDefinition = Scenario.hydra("Hydra", [Scenario.triggered(Scenario.counters_put(), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], [hydra])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_with_x(engine, Scenario.card_in_hand(engine, engine.hero(), "Hydra"), 2), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, Scenario.permanent_named(engine, engine.hero().id, "Hydra"), PLUS), 2)
	assert_eq(_triggers_of(engine, "Hydra"), 1)
	assert_eq(engine.hero().life, life + 1)


func test_once_each_turn_a_second_put_that_turn_does_nothing_and_the_next_turn_triggers_it() -> void:
	var once: Array[MmAbility] = [Scenario.once_each_turn(Scenario.triggered(Scenario.counters_put(), [Scenario.draw_cards(1, Scenario.you())]))]
	var duelist: MmCardDefinition = Scenario.creature("Duelist", 2, 2, once)
	var hand: Array[MmCardDefinition] = [Scenario.free_counters("Grow", PLUS, 1), Scenario.free_counters("Swell", PLUS, 1),
		Scenario.free_counters("Bloom", PLUS, 1)]
	var engine: MmEngine = _hero_main([duelist], hand)
	var duelist_id: int = Scenario.permanent_named(engine, engine.hero().id, "Duelist")
	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(duelist_id)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Swell", [MmReference.to_object(duelist_id)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Duelist"), 1, "Only once this turn.")

	Scenario.play_until_step(engine, 4, Step.UPKEEP)
	Scenario.pass_priority(engine)  # CR 117.3b: the Villain, as the active player, has it first.
	assert_eq(Scenario.cast_and_resolve(engine, "Bloom", [MmReference.to_object(duelist_id)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Duelist"), 2, "Again in the next turn.")
	assert_eq(Scenario.counters_on(engine, duelist_id, PLUS), 3)


func test_two_that_put_counters_on_each_other_trigger_once_each() -> void:
	# Generous Pup's: "Whenever one or more +1/+1 counters are put on this creature, put a +1/+1
	# counter on each other creature you control. This ability triggers only once each turn."
	var engine: MmEngine = _hero_main([_pup("Pup"), _pup("Other Pup")], [Scenario.free_counters("Grow", PLUS, 1)])
	var pup: int = Scenario.permanent_named(engine, engine.hero().id, "Pup")
	var other: int = Scenario.permanent_named(engine, engine.hero().id, "Other Pup")

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(pup)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Pup"), 1)
	assert_eq(_triggers_of(engine, "Other Pup"), 1)
	assert_eq(Scenario.counters_on(engine, pup, PLUS), 2, "Grow's, then the Other Pup's.")
	assert_eq(Scenario.counters_on(engine, other, PLUS), 1, "The Pup's; it does not trigger the Pup again.")


func test_whose_compares_with_the_controller_of_the_permanent() -> void:
	# "Whenever one or more +1/+1 counters are put on a creature you control, you gain 1 life."
	var trigger: CountersPutTrigger = Scenario.counters_put(Scenario.of_type(CardType.CREATURE), Whose.YOU)
	var watcher: MmCardDefinition = Scenario.enchantment("Keeper", [Scenario.triggered(trigger, [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([watcher, _bear()], [Scenario.free_counters("Grow", PLUS, 1), Scenario.free_counters("Swell", PLUS, 1)],
		[Scenario.creature("Ogre", 3, 3)])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(ogre)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(_triggers_of(engine, "Keeper"), 0, "The Villain's Ogre is not the Hero's.")
	assert_eq(Scenario.cast_and_resolve(engine, "Swell", [MmReference.to_object(bear)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Keeper"), 1)


func test_you_put_triggers_on_counters_its_controller_puts_on_it() -> void:
	var engine: MmEngine = _hero_main([_exemplar()], [Scenario.free_counters("Grow", PLUS, 1)])
	var exemplar: int = Scenario.permanent_named(engine, engine.hero().id, "Exemplar")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(exemplar)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Exemplar"), 1)
	assert_eq(engine.hero().life, life + 1)


func test_you_put_does_not_trigger_on_counters_an_opponent_puts_on_it() -> void:
	# CR 122.6: the player who puts them is the controller of the effect that puts them.
	var hand: Array[MmCardDefinition] = [Scenario.free_counters("Grow", PLUS, 1), Scenario.free_counters("Swell", PLUS, 1)]
	var engine: MmEngine = _hero_main([], hand, [_exemplar(), Scenario.counter_watcher()])
	var exemplar: int = Scenario.permanent_named(engine, engine.villain().id, "Exemplar")
	var watcher: int = Scenario.permanent_named(engine, engine.villain().id, "Counter Watcher")

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(exemplar)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Swell", [MmReference.to_object(watcher)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, exemplar, PLUS), 1)
	assert_eq(_triggers_of(engine, "Exemplar"), 0, "The Hero put it there, not its controller.")
	assert_eq(_triggers_of(engine, "Counter Watcher"), 1, "\"Are put on\" says nothing of who puts them.")


func test_an_opponent_puts_triggers_only_on_counters_its_controller_did_not_put() -> void:
	var hand: Array[MmCardDefinition] = [Scenario.free_counters("Grow", PLUS, 1), Scenario.free_counters("Swell", PLUS, 1)]
	var engine: MmEngine = _hero_main([_envious("Hero Envious")], hand, [_envious("Villain Envious")])
	var mine: int = Scenario.permanent_named(engine, engine.hero().id, "Hero Envious")
	var theirs: int = Scenario.permanent_named(engine, engine.villain().id, "Villain Envious")

	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(theirs)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Swell", [MmReference.to_object(mine)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Villain Envious"), 1, "The Hero is its controller's opponent.")
	assert_eq(_triggers_of(engine, "Hero Envious"), 0, "Its own controller put the counter on it.")


func test_entering_with_counters_its_controller_puts_them_on_it() -> void:
	# CR 122.6a: no player is named, so the entering object's controller puts them.
	var hydra: MmCardDefinition = Scenario.hydra("Hydra", [Scenario.triggered(_you_put(), [Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _hero_main([Scenario.mana_bird()], [hydra])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_with_x(engine, Scenario.card_in_hand(engine, engine.hero(), "Hydra"), 2), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_triggers_of(engine, "Hydra"), 1)
	assert_eq(engine.hero().life, life + 1)


func test_doubling_the_counters_on_it_puts_counters_on_it() -> void:
	# CR 701.10e, 122.6: the player doubling them puts the new ones on it.
	var double: MmCardDefinition = Scenario.instant("Double", Scenario.mana_cost(0), [Scenario.target(Scenario.of_type(CardType.CREATURE))],
		[Scenario.double_counters(PLUS, Scenario.targeted(0))])
	var engine: MmEngine = _hero_main([_exemplar()], [Scenario.free_counters("Grow", PLUS, 1), double])
	var exemplar: int = Scenario.permanent_named(engine, engine.hero().id, "Exemplar")
	assert_eq(Scenario.cast_and_resolve(engine, "Grow", [MmReference.to_object(exemplar)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Double", [MmReference.to_object(exemplar)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, exemplar, PLUS), 2)
	assert_eq(_triggers_of(engine, "Exemplar"), 2, "Grow's, then Double's.")


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_counter_triggers.tres"
	var minus: CountersPutTrigger = Scenario.counters_put(null, Whose.OPPONENT, MINUS, Whose.YOU)
	var card: MmCardDefinition = Scenario.creature("Watcher", 2, 2, [Scenario.triggered(minus, [Scenario.gain_life(1, Scenario.you())])])
	assert_eq(ResourceSaver.save(card, path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var trigger: CountersPutTrigger = (loaded.abilities[0] as TriggeredAbility).trigger as CountersPutTrigger
	assert_not_null(trigger)
	assert_eq(trigger.kind, MINUS)
	assert_eq(trigger.whose, Whose.OPPONENT)
	assert_eq(trigger.by_whose, Whose.YOU)
	assert_true(trigger.filter is IsSourceFilter)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A 2/2 creature costing {0}.
func _bear(card_name: String = "Bear") -> MmCardDefinition:
	return Scenario.typed_creature(card_name, 2, 2, ["Bear"])


## Generous Pup's second ability on a 2/2 costing {0}.
func _pup(card_name: String) -> MmCardDefinition:
	var others: EachSelection = Scenario.each_creature(Scenario.all_of([Scenario.creature_you_control(), Scenario.is_not(IsSourceFilter.new())]))
	var ability: TriggeredAbility = Scenario.triggered(Scenario.counters_put(), [Scenario.put_counters(PLUS, 1, others)])
	return Scenario.creature(card_name, 2, 2, [Scenario.once_each_turn(ability)])


## "Whenever you put one or more +1/+1 counters on this creature" (CR 122.6).
func _you_put() -> CountersPutTrigger:
	return Scenario.counters_put(null, Whose.ANY, PLUS, Whose.YOU)


## A 2/2 costing {0}: "Whenever you put one or more +1/+1 counters on this creature, you gain
## 1 life."
func _exemplar() -> MmCardDefinition:
	return Scenario.creature("Exemplar", 2, 2, [Scenario.triggered(_you_put(), [Scenario.gain_life(1, Scenario.you())])])


## A 2/2 costing {0}: "Whenever an opponent puts one or more +1/+1 counters on this
## creature, you gain 1 life."
func _envious(card_name: String) -> MmCardDefinition:
	var trigger: CountersPutTrigger = Scenario.counters_put(null, Whose.ANY, PLUS, Whose.OPPONENT)
	return Scenario.creature(card_name, 2, 2, [Scenario.triggered(trigger, [Scenario.gain_life(1, Scenario.you())])])


func _watcher(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Counter Watcher")


## How many times an ability of a permanent named [param card_name] has triggered.
func _triggers_of(engine: MmEngine, card_name: String) -> int:
	var count: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if (event as AbilityTriggeredEvent).pending.source_name == card_name:
			count += 1
	return count


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
