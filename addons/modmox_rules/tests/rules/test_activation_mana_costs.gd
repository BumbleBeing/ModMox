extends GutTest
## Activated abilities with mana in their costs, such as "{B}: Regenerate this creature"
## (CR 602.2b, 601.2g-h). They are paid like a spell's mana cost.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_an_ability_with_a_mana_cost_is_offered_only_when_it_can_be_paid() -> void:
	var engine: MmEngine = _skeleton_ready()
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")

	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, skeleton), -1, "No mana yet.")
	Scenario.play_first_land(engine)

	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, skeleton), -1)


func test_activating_asks_for_the_mana_and_then_puts_the_ability_on_the_stack() -> void:
	var engine: MmEngine = _skeleton_ready()
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	var swamp: int = Scenario.play_first_land(engine)

	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, skeleton))

	var payment: PayManaDecision = engine.pending_decision() as PayManaDecision
	assert_not_null(payment)
	assert_eq(payment.remaining_symbols, [MmMana.Type.BLACK])
	assert_eq(Scenario.pay_by_tapping(engine, swamp), "")
	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.game_state().stack.size(), 1)
	assert_true(engine.game_state().object(swamp).is_tapped)


func test_the_paid_ability_resolves_into_a_regeneration_shield() -> void:
	var engine: MmEngine = _skeleton_ready()
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.play_first_land(engine)

	assert_eq(Scenario.activate(engine, skeleton), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.game_state().replacement_effects.size(), 1)
	assert_false(engine.game_state().object(skeleton).is_tapped, "Its cost has no {T}.")


func test_canceling_the_activation_untaps_the_land() -> void:
	var engine: MmEngine = _skeleton_ready()
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	var swamp: int = Scenario.play_first_land(engine)
	var before: String = engine.fingerprint()
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, skeleton))

	assert_eq(engine.cancel_cast(), "")

	assert_eq(engine.fingerprint(), before)
	assert_false(engine.game_state().object(swamp).is_tapped)


func test_an_ability_costing_generic_mana_can_be_paid_with_any_mana() -> void:
	var generic: MmCardDefinition = Scenario.creature("Skeleton", 1, 1, [Scenario.regenerate_ability(Scenario.mana_cost(1))])
	var engine: MmEngine = _skeleton_ready(generic)
	var skeleton: int = Scenario.permanent_named(engine, engine.hero().id, "Skeleton")
	Scenario.play_first_land(engine)

	assert_eq(Scenario.activate(engine, skeleton), "")

	assert_eq(engine.game_state().stack.size(), 1)


## The Hero on Game Turn 3, precombat main, with a "{B}: Regenerate" creature on the
## battlefield and a Swamp in hand but no land in play.
func _skeleton_ready(skeleton: MmCardDefinition = null) -> MmEngine:
	var creature: MmCardDefinition = skeleton
	if creature == null:
		creature = Scenario.creature("Skeleton", 1, 1, [Scenario.regenerate_ability(Scenario.mana_cost(0, [MmMana.Type.BLACK]))])
	var swamp: MmCardDefinition = Scenario.basic_land("Swamp")
	var no_cards: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup([creature], no_cards, [swamp])
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [creature], no_cards, [swamp], no_cards, 3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	return engine
