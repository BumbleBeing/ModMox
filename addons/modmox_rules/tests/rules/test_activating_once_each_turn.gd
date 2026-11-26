extends GutTest
## The Activation Restriction "Activate only once each turn" (CR 602.5b, engine ADR 0036's
## addendum), as on Cutthroat Centurion: the ability's source marks it Spent for the Game
## Turn it was activated in, whatever becomes of it on the stack, and it is offered again in
## the next turn, whoever's turn that is. Pump is a 1/1 costing {0} with "{0}: You gain 1
## life. Activate only once each turn."; Fount a 0/1 costing {0} with "{0}: Add {W}.
## Activate only once each turn."

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_once_activated_it_is_not_offered_again_that_turn() -> void:
	var engine: MmEngine = _hero_main([_pump()], NO_CARDS)
	var pump: int = Scenario.permanent_named(engine, engine.hero().id, "Pump")
	var life: int = engine.hero().life

	assert_eq(Scenario.activate(engine, pump), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life + 1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, pump), -1)


func test_the_object_view_says_it_is_spent_for_the_rest_of_the_turn() -> void:
	var engine: MmEngine = _hero_main([_pump()], NO_CARDS)
	var pump: int = Scenario.permanent_named(engine, engine.hero().id, "Pump")
	assert_eq(_view_of(engine, pump).spent_ability_indexes, [] as Array[int])

	assert_eq(Scenario.activate(engine, pump), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(_view_of(engine, pump).spent_ability_indexes, [0] as Array[int])


func test_it_is_offered_again_in_the_next_turn_even_an_opponents() -> void:
	var engine: MmEngine = _hero_main([_pump()], NO_CARDS)
	var pump: int = Scenario.permanent_named(engine, engine.hero().id, "Pump")
	assert_eq(Scenario.activate(engine, pump), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.play_until_step(engine, 4, Step.PRECOMBAT_MAIN), "")
	_pass_to_hero(engine)

	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, pump), -1,
		"Once each turn, not once each of your turns.")
	assert_eq(_view_of(engine, pump).spent_ability_indexes, [] as Array[int])


func test_a_countered_activation_still_spends_it() -> void:
	# CR 602.5b: the restriction counts activations, not resolutions.
	var engine: MmEngine = _hero_main([_pump()], [Scenario.free_stifle("Stifle")])
	var pump: int = Scenario.permanent_named(engine, engine.hero().id, "Pump")
	var life: int = engine.hero().life
	assert_eq(Scenario.activate(engine, pump), "")
	var ability_on_stack: int = Scenario.stack_ids(engine)[0]

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Stifle"),
		[MmReference.to_object(ability_on_stack)]), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(engine.hero().life, life, "Countered.")
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, pump), -1)


func test_a_mana_ability_activated_once_is_not_offered_again_that_turn() -> void:
	var engine: MmEngine = _hero_main([_fount()], NO_CARDS)
	var fount: int = Scenario.permanent_named(engine, engine.hero().id, "Fount")

	assert_eq(Scenario.activate(engine, fount), "")

	assert_eq(engine.hero().mana_pool().size(), 1)
	assert_eq(Scenario.activate_index(engine.pending_decision() as PriorityDecision, fount), -1)


func test_a_mana_ability_spent_this_turn_cannot_pay_for_a_spell() -> void:
	var cost: MmManaCost = Scenario.mana_cost(0, [MmMana.Type.WHITE])
	var gift: MmCardDefinition = Scenario.instant("Gift", cost, [], [Scenario.gain_life(1, Scenario.you())])
	var engine: MmEngine = _hero_main([_fount()], [gift])
	var fount: int = Scenario.permanent_named(engine, engine.hero().id, "Fount")
	assert_eq(Scenario.activate(engine, fount), "")
	Scenario.pass_priority(engine)
	Scenario.pass_priority(engine)
	assert_eq(engine.hero().mana_pool().size(), 0, "The {W} emptied as the step ended.")

	assert_eq(Scenario.cast_index(engine.pending_decision() as PriorityDecision,
		Scenario.card_in_hand(engine, engine.hero(), "Gift")), -1, "Fount is spent, so nothing pays {W}.")


func test_an_object_that_leaves_and_returns_may_activate_it_again() -> void:
	# ADR 0008: the card that returns is a new object, which has activated nothing.
	var engine: MmEngine = _hero_main([_pump()], [Scenario.free_bounce("Bounce")])
	var pump: int = Scenario.permanent_named(engine, engine.hero().id, "Pump")
	assert_eq(Scenario.activate(engine, pump), "")
	assert_eq(Scenario.resolve_stack(engine), "")

	assert_eq(Scenario.cast_and_resolve(engine, "Bounce", [MmReference.to_object(pump)]), "")
	assert_eq(Scenario.cast_and_resolve(engine, "Pump"), "")
	var returned: int = Scenario.permanent_named(engine, engine.hero().id, "Pump")

	assert_ne(returned, pump)
	assert_ne(Scenario.activate_index(engine.pending_decision() as PriorityDecision, returned), -1)


func _pump() -> MmCardDefinition:
	var ability: ActivatedAbility = Scenario.activated(Scenario.mana_cost(0), [], [Scenario.gain_life(1, Scenario.you())])
	ability.is_once_each_turn = true
	return Scenario.creature("Pump", 1, 1, [ability])


func _fount() -> MmCardDefinition:
	var ability: ActivatedAbility = Scenario.tap_for_mana(MmMana.Type.WHITE, 1)
	ability.costs = []
	ability.is_once_each_turn = true
	return Scenario.creature("Fount", 0, 1, [ability])


## The Hero in their main phase of Game Turn 3, with [param hero_permanents] cast on Game
## Turn 1 and [param hero_extras] in hand.
func _hero_main(hero_permanents: Array[MmCardDefinition], hero_extras: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_permanents, NO_CARDS, hero_extras)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_permanents, NO_CARDS, hero_extras, NO_CARDS,
		3, Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


## Passes for the Villain until the Hero holds priority.
func _pass_to_hero(engine: MmEngine) -> void:
	while engine.pending_decision().player_id != engine.hero().id:
		assert_eq(Scenario.pass_priority(engine), "")


func _view_of(engine: MmEngine, object_id: int) -> MmObjectView:
	for view: MmObjectView in engine.view_for(engine.hero()).battlefield:
		if view.id == object_id:
			return view
	return null
