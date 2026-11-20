extends GutTest
## "Whenever [filter] blocks a creature" (CR 509.3b): triggers as blockers are declared, once
## for each attacking creature a creature that matches is declared blocking, with "that
## creature" the attacker it blocks. One event may so trigger one ability several times
## (ADR 0017's addendum). The Sentry is a 2/2 costing {0} with "Whenever this creature
## blocks a creature, you gain 1 life", and the Hero's Bears attack the Villain's creatures.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_blocking_an_attacker_triggers_it_once_with_that_attacker_as_that_creature() -> void:
	var engine: MmEngine = _blockers_ready([_bear()], [Scenario.sentry()])
	var bear: int = _bears(engine)[0]
	var sentry: int = Scenario.permanent_named(engine, engine.villain().id, "Sentry")
	var life: int = engine.villain().life

	assert_eq(Scenario.declare_blockers(engine, [[sentry, bear]]), "")

	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].triggering_object_id, bear, "CR 509.3b: that creature is the attacker it blocks.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.villain().life, life + 1)


func test_blocking_two_attackers_triggers_it_once_for_each() -> void:
	var engine: MmEngine = _blockers_ready(Scenario.copies(_bear(), 2), [Scenario.sentry("Sentry", [_one_more_block()])])
	var bears: Array[int] = _bears(engine)
	var sentry: int = Scenario.permanent_named(engine, engine.villain().id, "Sentry")
	var life: int = engine.villain().life

	assert_eq(Scenario.declare_blockers(engine, [[sentry, bears[1]], [sentry, bears[0]]]), "")

	assert_eq(_that_creatures(engine), [bears[0], bears[1]], "CR 509.3b: once for each attacker, in ID order.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.villain().life, life + 2)


func test_declaring_no_blockers_triggers_nothing() -> void:
	var engine: MmEngine = _blockers_ready([_bear()], [Scenario.sentry()])

	assert_eq(Scenario.declare_blockers(engine, []), "")

	assert_eq(_that_creatures(engine), [])


func test_another_creature_blocking_while_this_one_stays_back_triggers_nothing() -> void:
	var engine: MmEngine = _blockers_ready([_bear()], [Scenario.sentry(), _bear("Wolf")])
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")

	assert_eq(Scenario.declare_blockers(engine, [[wolf, _bears(engine)[0]]]), "")

	assert_eq(_that_creatures(engine), [])


func test_once_each_turn_two_blocks_trigger_it_once_for_the_first_attacker() -> void:
	var limited: TriggeredAbility = Scenario.once_each_turn(
		Scenario.triggered(Scenario.blocks_a_creature(), [Scenario.gain_life(1, Scenario.you())]))
	var engine: MmEngine = _blockers_ready(Scenario.copies(_bear(), 2), [Scenario.creature("Sentry", 2, 2, [limited, _one_more_block()])])
	var bears: Array[int] = _bears(engine)
	var sentry: int = Scenario.permanent_named(engine, engine.villain().id, "Sentry")
	var life: int = engine.villain().life

	assert_eq(Scenario.declare_blockers(engine, [[sentry, bears[1]], [sentry, bears[0]]]), "")

	assert_eq(_that_creatures(engine), [bears[0]], "ADR 0054's addendum: only the first of the event's triggers.")
	assert_true(engine.game_state().object(sentry).has_triggered_in(0, engine.game_state().game_turn), "It is Spent.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.villain().life, life + 1)


func test_it_resolves_after_this_creature_has_left_the_battlefield() -> void:
	var engine: MmEngine = _blockers_ready([_bear()], [Scenario.sentry()], [Scenario.free_shock("Shock", 2)])
	var sentry: int = Scenario.permanent_named(engine, engine.villain().id, "Sentry")
	var life: int = engine.villain().life
	Scenario.declare_blockers(engine, [[sentry, _bears(engine)[0]]])

	assert_eq(Scenario.cast_and_resolve(engine, "Shock", [MmReference.to_object(sentry)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_null(engine.game_state().object(sentry), "The Sentry died.")
	assert_eq(engine.villain().life, life + 1, "CR 113.7a: the ability exists apart from its source, with no intervening if.")


func test_a_creature_you_control_blocking_triggers_it_once_for_each_of_your_blocks() -> void:
	var engine: MmEngine = _blockers_ready([_bear(), _watchtower("Lookout")], [_watchtower(), _bear("Wolf"), _bear("Hound")])
	var bear: int = _bears(engine)[0]
	var wolf: int = Scenario.permanent_named(engine, engine.villain().id, "Wolf")
	var hound: int = Scenario.permanent_named(engine, engine.villain().id, "Hound")

	assert_eq(Scenario.declare_blockers(engine, [[wolf, bear], [hound, bear]]), "")

	assert_eq(_that_creatures(engine, "Watchtower"), [bear, bear], "CR 509.3b: once for each creature blocking it.")
	assert_eq(_that_creatures(engine, "Lookout"), [], "The Hero controls neither blocker.")


func _bear(card_name: String = "Bear") -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


## "This creature can block an additional creature each combat."
func _one_more_block() -> BlockAdditionalAbility:
	var more: BlockAdditionalAbility = BlockAdditionalAbility.new()
	more.count = 1
	return more


## An artifact costing {0}: "Whenever a creature you control blocks a creature, you gain 1
## life."
func _watchtower(card_name: String = "Watchtower") -> MmCardDefinition:
	var gain: Array[MmEffect] = [Scenario.gain_life(1, Scenario.you())]
	return Scenario.artifact(card_name, [Scenario.triggered(Scenario.blocks_a_creature(Scenario.creature_you_control()), gain)])


## [param hero_permanents] and [param villain_permanents] on the battlefield, every Bear of
## the Hero's attacking, and the Villain's blockers decision pending.
func _blockers_ready(hero_permanents: Array[MmCardDefinition], villain_permanents: Array[MmCardDefinition],
		hero_extras: Array[MmCardDefinition] = []) -> MmEngine:
	var engine: MmEngine = Scenario.combat_ready(hero_permanents, villain_permanents, hero_extras)
	assert_not_null(engine, "No seed gave the needed hands.")
	assert_eq(Scenario.declare_attackers(engine, _bears(engine)), "")
	assert_eq(Scenario.pass_to_blockers(engine), "")
	return engine


func _bears(engine: MmEngine) -> Array[int]:
	return Scenario.permanents_named(engine, engine.hero().id, "Bear")


## "That creature" of each trigger of [param source_name]'s abilities, in the order they
## triggered.
func _that_creatures(engine: MmEngine, source_name: String = "Sentry") -> Array[int]:
	var found: Array[int] = []
	for event: MmEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		var pending: PendingTrigger = (event as AbilityTriggeredEvent).pending
		if pending.source_name == source_name:
			found.append(pending.triggering_object_id)
	return found
