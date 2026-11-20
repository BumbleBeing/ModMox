extends GutTest
## "Whenever [filter] becomes tapped" (CR 603.2): a permanent changing from untapped to
## tapped, for any reason: attacking (CR 508.1f), paying a {T} cost, or an effect. A
## permanent that enters the battlefield tapped never becomes tapped, and one already
## tapped can't become tapped again.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_attacking_taps_it_and_the_trigger_resolves_before_blockers() -> void:
	var engine: MmEngine = _hero_ready([Scenario.tap_watcher()], [], Step.DECLARE_ATTACKERS)
	var watcher: int = _watcher(engine)
	var life: int = engine.hero().life

	assert_eq(Scenario.declare_attackers(engine, [watcher]), "")

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 1, "CR 508.1f: attacking taps it.")
	var trigger: MmGameObject = engine.game_state().object(stack[0])
	assert_eq(trigger.controller_id, engine.hero().id)
	assert_eq(trigger.triggering_object_id, watcher, "\"That creature\" is the tapped permanent.")
	assert_eq(trigger.triggering_player_id, engine.hero().id, "\"That player\" is its controller.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.game_state().step, Step.DECLARE_ATTACKERS, "It resolves in the declare attackers step.")
	assert_eq(engine.hero().life, life + 1)


func test_attacking_with_vigilance_does_not_tap_it_so_nothing_triggers() -> void:
	var vigilant: Array[MmAbility] = [VigilanceAbility.new()]
	var engine: MmEngine = _hero_ready([Scenario.tap_watcher("Watcher", vigilant)], [], Step.DECLARE_ATTACKERS)

	assert_eq(Scenario.declare_attackers(engine, [_watcher(engine)]), "")

	assert_true(Scenario.stack_ids(engine).is_empty(), "CR 702.20b")


func test_an_effect_that_taps_it_triggers_it() -> void:
	var engine: MmEngine = _hero_ready([Scenario.tap_watcher()], [Scenario.free_tap("Tap")])
	var watcher: int = _watcher(engine)
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Tap", [MmReference.to_object(watcher)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1)


func test_tapping_it_again_while_it_is_tapped_triggers_nothing() -> void:
	var engine: MmEngine = _hero_ready([Scenario.tap_watcher()], [Scenario.free_tap("Tap"), Scenario.free_tap("Tap Again")])
	var watcher: int = _watcher(engine)
	var life: int = engine.hero().life
	assert_eq(Scenario.cast_and_resolve(engine, "Tap", [MmReference.to_object(watcher)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Tap Again", [MmReference.to_object(watcher)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1, "An already tapped permanent can't become tapped.")


func test_paying_a_tap_cost_with_it_triggers_it_above_the_spell_being_cast() -> void:
	var tapper: Array[MmAbility] = [Scenario.tap_for_mana(MmMana.Type.WHITE, 1)]
	var spell: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(1), [], [Scenario.gain_life(2, Scenario.you())])
	var engine: MmEngine = _hero_ready([Scenario.tap_watcher("Watcher", tapper)], [spell])
	var gift: int = Scenario.card_in_hand(engine, engine.hero(), "Gift")
	var life: int = engine.hero().life

	assert_eq(Scenario.cast(engine, gift), "")

	var stack: Array[int] = Scenario.stack_ids(engine)
	assert_eq(stack.size(), 2, "CR 603.3: it goes on the stack once the spell is cast.")
	assert_true(engine.game_state().object(stack[0]).ability is TriggeredAbility, "Above the spell.")
	assert_eq(Scenario.resolve_stack(engine), "")
	assert_eq(engine.hero().life, life + 3)


func test_cancelling_a_cast_takes_back_the_trigger_its_payment_made() -> void:
	var tapper: Array[MmAbility] = [Scenario.tap_for_mana(MmMana.Type.WHITE, 1)]
	var spell: MmCardDefinition = Scenario.instant("Gift", Scenario.mana_cost(2), [], [Scenario.gain_life(2, Scenario.you())])
	var engine: MmEngine = _hero_ready([Scenario.tap_watcher("Watcher", tapper), Scenario.mana_bird("Mana Bird", 1)], [spell])
	var watcher: int = _watcher(engine)
	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_eq(engine.submit(Scenario.cast_index(decision, Scenario.card_in_hand(engine, engine.hero(), "Gift"))), "")
	assert_eq(Scenario.pay_by_tapping(engine, watcher), "")
	assert_true(engine.is_casting())
	assert_eq(engine.game_state().pending_triggers.size(), 1)

	assert_eq(engine.cancel_cast(), "")

	assert_true(engine.game_state().pending_triggers.is_empty(), "CR 728: everything goes back as it was.")
	assert_false(engine.game_state().object(watcher).is_tapped)


func test_a_permanent_that_enters_tapped_does_not_become_tapped() -> void:
	var lookout: MmCardDefinition = Scenario.artifact("Lookout", [Scenario.triggered(
		Scenario.becomes_tapped(Scenario.of_type(MmCardTypes.CardType.LAND), Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var lands: Array[MmCardDefinition] = [Scenario.tapped_dual_land("Swamp", "Forest")]
	var engine: MmEngine = _hero_ready([lookout], [Scenario.free_land_fetch()], Step.PRECOMBAT_MAIN, lands)
	var life: int = engine.hero().life

	assert_eq(Scenario.fetch_lands(engine, ["Tapped Swamp Forest"]), "")

	assert_true(engine.game_state().object(Scenario.permanent_named(engine, engine.hero().id, "Tapped Swamp Forest")).is_tapped)
	assert_eq(engine.hero().life, life, "It enters tapped; it never becomes tapped.")


func test_each_permanent_one_effect_taps_triggers_once_and_whose_is_its_controller() -> void:
	var lookout: MmCardDefinition = Scenario.artifact("Lookout", [Scenario.triggered(
		Scenario.becomes_tapped(Scenario.of_type(MmCardTypes.CardType.CREATURE), Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var tap_all: MmCardDefinition = Scenario.instant("Tap All", Scenario.mana_cost(0), [], [Scenario.tap(Scenario.each_creature())])
	var hero_creatures: Array[MmCardDefinition] = [lookout, Scenario.creature("Bear", 2, 2), Scenario.creature("Elk", 2, 2)]
	var engine: MmEngine = _hero_ready(hero_creatures, [tap_all], Step.PRECOMBAT_MAIN, [], [Scenario.creature("Ogre", 3, 3)])
	var life: int = engine.hero().life

	assert_eq(Scenario.cast_and_resolve(engine, "Tap All"), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 2, "One trigger for each of the Hero's creatures; the Villain's Ogre is not theirs.")


func _watcher(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.hero().id, "Watcher")


## The Hero casts [param hero_permanents] on Game Turn 1 and the Villain
## [param villain_permanents] on Game Turn 2; stops at the Hero's [param step] on Game Turn
## 3 with [param hero_extras] in hand. [param library] is in the Hero's deck too.
func _hero_ready(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition],
		step: Step = Step.PRECOMBAT_MAIN, library: Array[MmCardDefinition] = [],
		villain_permanents: Array[MmCardDefinition] = []) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, villain_permanents, hero_extras + library)
	var none: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, villain_permanents, hero_extras, none, 3, step)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine
