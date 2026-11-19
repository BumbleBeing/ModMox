extends GutTest
## "You may [effect]." (CR 603.5, 608.2d): the spell or ability goes on the stack and its
## targets are chosen whether or not its controller means to do it (CR 603.3d); as the
## effect begins they are asked a ChooseYesOrNoDecision, and the effect happens only on yes.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const YES: int = ChooseYesOrNoDecision.Choice.YES
const NO: int = ChooseYesOrNoDecision.Choice.NO


func test_a_you_may_trigger_asks_its_controller_yes_or_no_as_it_resolves() -> void:
	var engine: MmEngine = _hero_main([Scenario.snarer()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")

	assert_eq(_snarer_asked(engine, ogre), "")

	var asked: ChooseYesOrNoDecision = engine.pending_decision() as ChooseYesOrNoDecision
	assert_not_null(asked, "CR 608.2d: asked as the effect begins.")
	assert_eq(asked.player_id, engine.hero().id, "Its controller answers.")
	var trigger: MmGameObject = engine.game_state().object(asked.stack_object_id)
	assert_true(trigger.ability is TriggeredAbility, "The resolving trigger.")
	assert_eq(trigger.targets[0].id, ogre, "CR 603.3d: the target was chosen as it went on the stack.")
	assert_true(asked.effect is TapEffect, "What yes does.")
	assert_false(engine.game_state().object(ogre).is_tapped, "Nothing is done before the answer.")


func test_answering_yes_does_the_effect() -> void:
	var engine: MmEngine = _hero_main([Scenario.snarer()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(_snarer_asked(engine, ogre), "")

	assert_eq(engine.submit(YES), "")

	assert_true(engine.game_state().object(ogre).is_tapped)
	assert_true(engine.game_state().stack.is_empty())


func test_answering_no_does_nothing_and_the_ability_still_resolves() -> void:
	var engine: MmEngine = _hero_main([Scenario.snarer()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(_snarer_asked(engine, ogre), "")
	var trigger: int = (engine.pending_decision() as ChooseYesOrNoDecision).stack_object_id

	assert_eq(engine.submit(NO), "")

	assert_false(engine.game_state().object(ogre).is_tapped)
	assert_eq(Scenario.events_of(engine, TapEvent).size(), 0)
	var left: AbilityLeftStackEvent = _left_stack(engine, trigger)
	assert_not_null(left)
	assert_true(left.did_resolve, "Saying no is not failing to resolve.")


func test_with_nothing_to_target_the_trigger_is_removed_and_nothing_asked() -> void:
	# CR 603.3d: a triggered ability with no legal target is removed from the stack.
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = _hero_main([Scenario.snarer("Snarer", _opposing_creature())], no_creatures)
	var snarer: int = Scenario.card_in_hand(engine, engine.hero(), "Snarer")

	assert_eq(Scenario.cast(engine, snarer), "")

	assert_false(_asked_while_resolving(engine))
	assert_eq(Scenario.stacked_abilities(engine).size(), 0)
	assert_eq(Scenario.events_of(engine, TapEvent).size(), 0)


func test_a_trigger_whose_target_is_gone_does_not_resolve_and_asks_nothing() -> void:
	# CR 608.2b.
	var engine: MmEngine = _hero_main([Scenario.snarer(), Scenario.free_bounce("Bounce")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(_snarer_targeting(engine, ogre), "")
	var trigger: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [MmReference.to_object(ogre)]), "")

	assert_false(_asked_while_resolving(engine))
	assert_false(_left_stack(engine, trigger).did_resolve)


func test_an_effect_after_the_may_happens_whatever_the_answer() -> void:
	var snarer: MmCardDefinition = Scenario.creature("Snarer", 2, 1, [Scenario.triggered(
		Scenario.enters(IsSourceFilter.new()), [Scenario.may(Scenario.tap(Scenario.targeted(0))), Scenario.gain_life(1, Scenario.you())],
		[Scenario.target(Scenario.of_type(MmCardTypes.CardType.CREATURE))])])
	var engine: MmEngine = _hero_main([snarer])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	var life_before: int = engine.hero().life
	assert_eq(_snarer_asked(engine, ogre), "")

	assert_eq(engine.submit(NO), "")

	assert_false(engine.game_state().object(ogre).is_tapped)
	assert_eq(engine.hero().life, life_before + 1)


func test_an_answer_that_is_not_yes_or_no_is_refused() -> void:
	var engine: MmEngine = _hero_main([Scenario.snarer()])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(_snarer_asked(engine, ogre), "")
	var asked: MmPendingDecision = engine.pending_decision()

	assert_ne(engine.submit(2), "")
	assert_ne(engine.submit(true), "")

	assert_eq(engine.pending_decision(), asked, "Still asked.")
	assert_false(engine.game_state().object(ogre).is_tapped)


func test_replaying_the_decision_log_gives_the_same_answer() -> void:
	# ADR 0010: the answer is a plain int in the decision log.
	var hero_extras: Array[MmCardDefinition] = [Scenario.snarer()]
	var setup: MmEncounterSetup = _setup(hero_extras)
	var engine: MmEngine = _engine_ready(setup, hero_extras)
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	assert_eq(_snarer_asked(engine, ogre), "")
	assert_eq(engine.submit(YES), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())
	assert_true(replayed.game_state().object(ogre).is_tapped)


func test_a_may_effect_reaches_what_it_affects_through_the_effect_it_wraps() -> void:
	var tap: TapEffect = Scenario.tap(Scenario.targeted(0))
	var may: MayEffect = Scenario.may(tap)

	assert_eq(may.selections(), tap.selections())
	assert_true(may.has_targets(), "So an ability with one still targets.")
	assert_false(may.adds_mana())


## Casts the Hero's Snarer and puts its trigger on the stack targeting [param target_id].
func _snarer_targeting(engine: MmEngine, target_id: int) -> String:
	var error: String = Scenario.cast_and_resolve(engine, "Snarer")
	if error != "":
		return error
	return Scenario.choose_target(engine, MmReference.to_object(target_id))


## As _snarer_targeting(), then passes until the trigger's yes or no is asked.
func _snarer_asked(engine: MmEngine, target_id: int) -> String:
	var error: String = _snarer_targeting(engine, target_id)
	return error if error != "" else Scenario.pass_to_yes_or_no(engine)


## Lets the stack resolve, answering as autoplay() does, and says whether a yes or no was
## asked on the way.
func _asked_while_resolving(engine: MmEngine) -> bool:
	var error: String = Scenario.autoplay(engine, func(running: MmEngine) -> bool:
		return running.pending_decision() is ChooseYesOrNoDecision or (running.game_state().stack.is_empty() \
			and running.pending_decision() is PriorityDecision and running.game_state().pending_triggers.is_empty()))
	assert_eq(error, "")
	return engine.pending_decision() is ChooseYesOrNoDecision


func _left_stack(engine: MmEngine, object_id: int) -> AbilityLeftStackEvent:
	for event: MmEvent in Scenario.events_of(engine, AbilityLeftStackEvent):
		if (event as AbilityLeftStackEvent).object_id == object_id:
			return event as AbilityLeftStackEvent
	return null


func _opposing_creature() -> MmFilter:
	var theirs: ControlledByFilter = ControlledByFilter.new()
	theirs.whose = MmTrigger.Whose.OPPONENT
	return Scenario.all_of([Scenario.of_type(MmCardTypes.CardType.CREATURE), theirs])


func _bear() -> MmCardDefinition:
	return Scenario.creature("Bear", 2, 2)


func _ogre() -> MmCardDefinition:
	return Scenario.creature("Ogre", 3, 3)


## The Hero's Bear and the Villain's [param villain_permanents] (an Ogre unless given) on
## the battlefield, in the Hero's main phase of Game Turn 3 with [param hero_extras] in hand.
func _hero_main(hero_extras: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition] = [_ogre()]) -> MmEngine:
	return _engine_ready(_setup(hero_extras, villain_permanents), hero_extras, villain_permanents)


## A setup for _engine_ready(). A Villain with no permanents still has a deck: a Bounce.
func _setup(hero_extras: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition] = [_ogre()]) -> MmEncounterSetup:
	var villain_deck: Array[MmCardDefinition] = []
	if villain_permanents.is_empty():
		villain_deck.append(Scenario.free_bounce("Their Bounce"))
	return Scenario.combat_setup([_bear()], villain_permanents, hero_extras, villain_deck)


func _engine_ready(setup: MmEncounterSetup, hero_extras: Array[MmCardDefinition],
		villain_permanents: Array[MmCardDefinition] = [_ogre()]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [_bear()], villain_permanents, hero_extras, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
