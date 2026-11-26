extends GutTest
## "Sacrifice [count] [filter]" as a cost (CR 701.21a): the payer chooses which of the
## permanents they control that match, and those move to their owners' graveyards. As
## Selfcraft Mechan has it, after a "you may" whose "when you do" is a reflexive trigger
## (CR 603.12), the choice is asked once yes is said (engine ADR 0088); as an additional cost
## of a spell, it is asked once the mana is paid (engine ADR 0086). A Mechan is an artifact
## itself, so it may be sacrificed for its own ability.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const YES: int = ChooseYesOrNoDecision.Choice.YES
const NO: int = ChooseYesOrNoDecision.Choice.NO


func test_yes_asks_which_artifact_and_sacrifices_it() -> void:
	var engine: MmEngine = _hero_main([_trinket(), _bear()], [Scenario.mechan()])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	assert_eq(_cast_mechan_to_question(engine), "")
	var mechan: int = Scenario.permanent_named(engine, engine.hero().id, "Mechan")

	assert_eq(engine.submit(YES), "")

	var asked: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(asked, "Yes asks which artifact to sacrifice.")
	assert_eq(asked.purpose, ChoosePermanentsDecision.Purpose.SACRIFICE)
	assert_eq(asked.count, 1)
	var artifacts: Array[int] = [trinket, mechan]
	artifacts.sort()
	assert_eq(asked.candidate_ids, artifacts, "Artifacts the Hero controls, the Mechan too; not the Bear.")
	assert_eq(engine.submit([trinket]), "")
	assert_eq(Scenario.permanents_named(engine, engine.hero().id, "Trinket"), [] as Array[int])
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Trinket"), -1, "CR 701.21a: to its owner's graveyard.")
	var moves: Array[MmEvent] = Scenario.events_of(engine, ZoneChangeEvent)
	assert_eq((moves.back() as ZoneChangeEvent).reason, ZoneChangeEvent.Reason.SACRIFICE)


func test_when_you_do_puts_a_counter_on_the_target_and_draws() -> void:
	var engine: MmEngine = _hero_main([_trinket(), _bear()], [Scenario.mechan()])
	var trinket: int = Scenario.permanent_named(engine, engine.hero().id, "Trinket")
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(_cast_mechan_to_question(engine), "")
	assert_eq(engine.submit(YES), "")
	assert_eq(engine.submit([trinket]), "")
	var hand: int = engine.hero().hand.size()

	var target: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(target, "CR 603.12: the reflexive ability's target is chosen as it is put on the stack.")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.counters_on(engine, bear, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 1)
	assert_eq(engine.hero().hand.size(), hand + 1, "And draw a card.")


func test_no_sacrifices_nothing_and_nothing_triggers() -> void:
	var engine: MmEngine = _hero_main([_trinket(), _bear()], [Scenario.mechan()])
	var hand_before: int = -1
	assert_eq(_cast_mechan_to_question(engine), "")
	hand_before = engine.hero().hand.size()

	assert_eq(engine.submit(NO), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Trinket"), -1)
	assert_eq(engine.hero().hand.size(), hand_before)


func test_it_may_sacrifice_its_own_source() -> void:
	var engine: MmEngine = _hero_main([_bear()], [Scenario.mechan()])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")
	assert_eq(_cast_mechan_to_question(engine), "")
	var mechan: int = Scenario.permanent_named(engine, engine.hero().id, "Mechan")
	assert_eq(engine.submit(YES), "")

	assert_eq(engine.submit([mechan]), "")
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(bear)), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Mechan"), -1)
	assert_eq(Scenario.counters_on(engine, bear, MmCounter.Kind.PLUS_ONE_PLUS_ONE), 1,
		"CR 608.2h: the reflexive ability works from its source as it last existed.")


func test_with_nothing_to_sacrifice_nothing_is_asked() -> void:
	var rewards: ReflexiveTriggerEffect = Scenario.reflexive([Scenario.draw_cards(1, Scenario.you())])
	var enchantments: MmFilter = Scenario.of_type(MmCardTypes.CardType.ENCHANTMENT)
	var seeker: MmCardDefinition = Scenario.creature("Seeker", 1, 1,
		[Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.may_pay(Scenario.sacrifice_permanents(1, enchantments), rewards)])])
	var engine: MmEngine = _hero_main([_trinket()], [seeker])

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Seeker")), "")
	assert_eq(_play_to_question_or_empty_stack(engine), "")

	assert_false(engine.pending_decision() is ChooseYesOrNoDecision, "CR 118.3: no enchantment, so it can't be paid.")
	assert_ne(Scenario.permanent_named(engine, engine.hero().id, "Trinket"), -1)


func test_as_an_additional_cost_it_is_asked_once_the_mana_is_paid() -> void:
	var offering: MmCardDefinition = _offering()
	var engine: MmEngine = _hero_main([_bear()], [offering])
	var bear: int = Scenario.permanent_named(engine, engine.hero().id, "Bear")

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Offering")), "")

	var asked: ChoosePermanentsDecision = engine.pending_decision() as ChoosePermanentsDecision
	assert_not_null(asked)
	assert_eq(asked.purpose, ChoosePermanentsDecision.Purpose.SACRIFICE)
	assert_eq(asked.candidate_ids, [bear] as Array[int])
	assert_eq(engine.submit([bear]), "")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Bear"), -1)


func test_as_an_additional_cost_it_is_not_offered_with_nothing_to_sacrifice() -> void:
	var offering: MmCardDefinition = _offering()
	var engine: MmEngine = _hero_main([_trinket()], [offering], [_bear()])

	var offered: int = Scenario.card_in_hand(engine, engine.hero(), "Offering")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision, offered), -1,
		"The Villain's Bear can't be sacrificed by the Hero.")


func test_a_replay_sacrifices_the_same_artifact() -> void:
	var permanents: Array[MmCardDefinition] = [_trinket(), _trinket(), _bear()]
	var hand: Array[MmCardDefinition] = [Scenario.mechan()]
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(permanents, no_cards, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, permanents, no_cards, hand, no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(_cast_mechan_to_question(engine), "")
	assert_eq(engine.submit(YES), "")
	assert_eq(engine.submit([Scenario.permanents_named(engine, engine.hero().id, "Trinket")[1]]), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_sacrificing_permanents.tres"
	assert_eq(ResourceSaver.save(Scenario.mechan(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var paying: MayPayEffect = (loaded.abilities[0] as TriggeredAbility).effects[0] as MayPayEffect
	var sacrificing: SacrificePermanentsCost = paying.cost as SacrificePermanentsCost
	assert_not_null(sacrificing)
	assert_eq(sacrificing.count, 1)
	assert_true(sacrificing.filter is HasCardTypeFilter)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


## An instant costing {0}: "As an additional cost to cast this spell, sacrifice a creature.
## Draw two cards."
func _offering() -> MmCardDefinition:
	var costs: Array[MmCost] = [Scenario.sacrifice_permanents(1, Scenario.of_type(MmCardTypes.CardType.CREATURE))]
	var offering: MmCardDefinition = Scenario.instant("Offering", Scenario.mana_cost(0), [] as Array[TargetRequirement],
		[Scenario.draw_cards(2, Scenario.you())])
	offering.abilities.insert(0, Scenario.additional_cost(costs))
	return offering


func _trinket() -> MmCardDefinition:
	return Scenario.artifact("Trinket", [])


## The Hero in their first main phase of Game Turn 3 with [param hero_permanents] cast on
## Game Turn 1, holding [param hand]; the Villain cast [param villain_permanents] on Game Turn 2.
func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hand,
		[] as Array[MmCardDefinition], 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## Casts the Mechan and plays on to its "you may".
func _cast_mechan_to_question(engine: MmEngine) -> String:
	var error: String = Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Mechan"))
	return error if error != "" else Scenario.pass_to_yes_or_no(engine)


## Plays on until a yes or no is asked or the stack is empty.
func _play_to_question_or_empty_stack(engine: MmEngine) -> String:
	return Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is ChooseYesOrNoDecision or (running.pending_decision() is PriorityDecision
			and running.game_state().stack.is_empty() and running.game_state().pending_triggers.is_empty()))
