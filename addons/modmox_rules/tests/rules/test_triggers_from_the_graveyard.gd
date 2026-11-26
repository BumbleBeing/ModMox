extends GutTest
## Phoenix Chick's pieces (engine ADR 0094's addendum): "This creature can't block."
## (CantBlockAbility, CR 509.1a), and "Whenever you attack with three or more creatures, you
## may pay {R}{R}. If you do, return this card from your graveyard to the battlefield tapped
## and attacking with a +1/+1 counter on it.": a triggered ability that works only from its
## card's graveyard (TriggeredAbility.is_triggered_from_graveyard), an
## AttackersDeclaredTrigger with at_least, and a ReturnToBattlefieldEffect that is attacking
## (CR 508.4).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const PLUS_ONE := MmCounter.Kind.PLUS_ONE_PLUS_ONE
const Choice := ChooseYesOrNoDecision.Choice


func test_attacking_with_three_it_may_pay_and_return_tapped_attacking_with_a_counter() -> void:
	var engine: MmEngine = _chick_in_graveyard()
	var attackers: Array[int] = _bears(engine, 3)

	assert_eq(Scenario.declare_attackers(engine, attackers), "")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(Choice.YES), "")
	assert_eq(Scenario.auto_pay(engine), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	var chick: int = Scenario.permanent_named(engine, engine.hero().id, "Chick")
	assert_ne(chick, -1, "It returned.")
	assert_true(engine.game_state().object(chick).is_tapped)
	assert_true(engine.game_state().combat.is_attacking(chick), "It is attacking, never declared (CR 508.4).")
	assert_eq(Scenario.counters_on(engine, chick, PLUS_ONE), 1)
	assert_eq(Scenario.pt(engine, chick), [1, 1])


func test_declining_leaves_it_in_the_graveyard() -> void:
	var engine: MmEngine = _chick_in_graveyard()

	assert_eq(Scenario.declare_attackers(engine, _bears(engine, 3)), "")
	assert_eq(Scenario.pass_to_pay_or_not(engine), "")
	assert_eq(engine.submit(Choice.NO), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Chick"), -1)
	assert_eq(Scenario.permanent_named(engine, engine.hero().id, "Chick"), -1)


func test_attacking_with_two_triggers_nothing() -> void:
	var engine: MmEngine = _chick_in_graveyard()

	assert_eq(Scenario.declare_attackers(engine, _bears(engine, 2)), "")

	assert_eq(_chick_triggers(engine), 0)


func test_on_the_battlefield_it_triggers_nothing() -> void:
	# CR 113.6k: it works only from the graveyard.
	var engine: MmEngine = _hero_main([_chick(1), _bear("Ann"), _bear("Ben"), _bear("Cy"), Scenario.mana_bird()], [])
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS), "")
	var attackers: Array[int] = _bears(engine, 3)
	attackers.append(Scenario.permanent_named(engine, engine.hero().id, "Chick"))

	assert_eq(Scenario.declare_attackers(engine, attackers), "")

	assert_eq(_chick_triggers(engine), 0)


func test_a_creature_that_cant_block_is_never_a_blocker() -> void:
	var engine: MmEngine = Scenario.combat_ready([_bear("Ann")], [_chick(1), _bear("Wall")])
	assert_not_null(engine, "No seed gave the needed hands.")
	var chick: int = Scenario.permanent_named(engine, engine.villain().id, "Chick")
	var wall: int = Scenario.permanent_named(engine, engine.villain().id, "Wall")

	assert_eq(Scenario.declare_attackers(engine, [Scenario.permanent_named(engine, engine.hero().id, "Ann")]), "")
	Scenario.autoplay(engine, func(running: MmEngine) -> bool: return running.pending_decision() is DeclareBlockersDecision)

	var blocking: DeclareBlockersDecision = engine.pending_decision() as DeclareBlockersDecision
	assert_not_null(blocking)
	if blocking != null:
		assert_eq(blocking.candidate_blocker_ids, [wall] as Array[int])
		assert_false(blocking.candidate_blocker_ids.has(chick))


func test_three_or_more_counts_only_matching_attackers() -> void:
	var trigger: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	trigger.at_least = 3
	var engine: MmEngine = _chick_in_graveyard()
	var attackers: Array[int] = _bears(engine, 3)
	var context: MmEffectContext = MmEffectContext.new(engine.hero().id, 0)

	assert_false(trigger.matches(engine.game_state(), AttackersDeclaredEvent.new(engine.hero().id, attackers.slice(0, 2), engine.villain().id),
		context))
	assert_true(trigger.matches(engine.game_state(), AttackersDeclaredEvent.new(engine.hero().id, attackers, engine.villain().id), context))


func test_it_is_saved_with_its_card() -> void:
	var path: String = "user://test_triggers_from_the_graveyard.tres"
	assert_eq(ResourceSaver.save(_chick(), path), OK)

	var loaded: MmCardDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MmCardDefinition

	var rising: TriggeredAbility = loaded.abilities[1] as TriggeredAbility
	assert_true(loaded.abilities[0] is CantBlockAbility)
	assert_true(rising.is_triggered_from_graveyard)
	assert_eq((rising.trigger as AttackersDeclaredTrigger).at_least, 3)
	assert_true(((rising.effects[0] as MayPayEffect).effect as ReturnToBattlefieldEffect).attacking)
	DirAccess.remove_absolute(path)


# --- Helpers ---------------------------------------------------------------------------


## A creature costing {0} of [param toughness] toughness and no power with Phoenix Chick's
## "can't block" and its return, for {2} rather than {R}{R}. At 0 toughness it dies as it
## enters, and so goes to its owner's graveyard.
func _chick(toughness: int = 0) -> MmCardDefinition:
	var back: ReturnToBattlefieldEffect = Scenario.return_to_battlefield(SourceSelection.new())
	back.tapped = true
	back.attacking = true
	back.counters = Scenario.constant(1)
	var attack_with_three: AttackersDeclaredTrigger = AttackersDeclaredTrigger.new()
	attack_with_three.at_least = 3
	var rising: TriggeredAbility = Scenario.triggered(attack_with_three, [Scenario.may_pay_mana(Scenario.mana_cost(2), back)])
	rising.is_triggered_from_graveyard = true
	return Scenario.creature("Chick", 0, toughness, [CantBlockAbility.new(), rising])


func _bear(card_name: String) -> MmCardDefinition:
	return Scenario.creature(card_name, 2, 2)


## The first [param count] of the Hero's Ann, Ben and Cy.
func _bears(engine: MmEngine, count: int) -> Array[int]:
	var ids: Array[int] = []
	for card_name: String in ["Ann", "Ben", "Cy"].slice(0, count):
		ids.append(Scenario.permanent_named(engine, engine.hero().id, card_name))
	return ids


func _chick_triggers(engine: MmEngine) -> int:
	var count: int = 0
	for triggered: AbilityTriggeredEvent in Scenario.events_of(engine, AbilityTriggeredEvent):
		if triggered.pending.source_name == "Chick":
			count += 1
	return count


## The Hero at their attackers decision on Game Turn 3, with Ann, Ben, Cy and a Mana Bird
## out, having cast a 0/0 Chick that died as it entered.
func _chick_in_graveyard() -> MmEngine:
	var engine: MmEngine = _hero_main([_bear("Ann"), _bear("Ben"), _bear("Cy"), Scenario.mana_bird()], [_chick()])
	assert_eq(Scenario.cast_and_resolve(engine, "Chick"), "")
	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Chick"), -1, "The 0/0 Chick died as it entered.")
	assert_eq(Scenario.pass_until_step(engine, Step.DECLARE_ATTACKERS), "")
	return engine


func _hero_main(hero_permanents: Array[MmCardDefinition], hand: Array[MmCardDefinition]) -> MmEngine:
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, no_cards, hand)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, no_cards, hand, no_cards, 3,
		Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
