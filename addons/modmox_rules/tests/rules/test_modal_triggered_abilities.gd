extends GutTest
## CR 603.3c, 700.2b: a modal triggered ability's controller chooses its mode as they put it
## on the stack, before its targets (ADR 0046). A mode that could not have every target
## chosen can't be chosen, the only mode that can be is chosen without asking, and a trigger
## with no mode that can be chosen is removed from the stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose
const CardType := MmCardTypes.CardType


func test_a_modal_trigger_asks_its_controller_for_its_mode_as_it_goes_on_the_stack() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])

	var decision: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision

	assert_not_null(decision, "CR 603.3c: the mode is chosen as the trigger is put on the stack.")
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(decision.modes, [0, 1] as Array[int])
	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(decision.stack_object_id, stacked[0].id)
	assert_eq(Scenario.choose_mode(engine, 1), "")
	var targeting: ChooseTargetDecision = engine.pending_decision() as ChooseTargetDecision
	assert_not_null(targeting, "Then the chosen mode's target.")
	assert_eq(targeting.candidates.size(), 1)
	assert_eq(targeting.candidates[0].id, _ogre(engine))


func test_the_mode_decision_lists_what_each_mode_could_target() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])

	var decision: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision

	assert_eq(decision.mode_targets[0].size(), 0, "Gaining life targets nothing.")
	assert_eq(decision.mode_targets[1].size(), 1)
	assert_eq((decision.mode_targets[1][0] as MmReference).id, _ogre(engine))


func test_the_other_players_modal_trigger_is_asked_of_them_once_the_active_players_is_on_the_stack() -> void:
	var engine: MmEngine = _upkeep([_chime("Hero Chime", Whose.ANY)],
		[Scenario.creature("Ogre", 3, 3), _chime("Villain Chime", Whose.ANY)])

	var first: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision
	assert_not_null(first)
	assert_eq(first.player_id, engine.hero().id, "CR 603.3b: the active player's trigger first.")
	assert_eq(Scenario.choose_mode(engine, 0), "")

	var second: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision
	assert_not_null(second)
	assert_eq(second.player_id, engine.villain().id, "The Villain chooses the mode of their own trigger.")
	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 2)
	assert_eq(stacked[0].controller_id, engine.hero().id)
	assert_eq(stacked[0].chosen_mode, 0, "The Hero's is on the stack with its mode.")
	assert_eq(second.stack_object_id, stacked[1].id)


func test_a_players_modal_triggers_are_ordered_first_then_each_is_asked_its_mode_in_that_order() -> void:
	var engine: MmEngine = _upkeep([_chime("First Chime", Whose.YOU), _chime("Second Chime", Whose.YOU)],
		[Scenario.creature("Ogre", 3, 3)])
	var second_chime: int = Scenario.permanent_named(engine, engine.hero().id, "Second Chime")
	var first_chime: int = Scenario.permanent_named(engine, engine.hero().id, "First Chime")
	assert_true(engine.pending_decision() is OrderTriggersDecision)

	assert_eq(engine.submit([1, 0]), "")

	var decision: ChooseModeDecision = engine.pending_decision() as ChooseModeDecision
	assert_not_null(decision)
	assert_eq(engine.game_state().object(decision.stack_object_id).source_object_id, second_chime)
	assert_eq(Scenario.choose_mode(engine, 0), "")
	decision = engine.pending_decision() as ChooseModeDecision
	assert_not_null(decision)
	assert_eq(engine.game_state().object(decision.stack_object_id).source_object_id, first_chime)


func test_only_the_chosen_modes_effects_happen() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])
	var life: int = engine.hero().life

	assert_eq(Scenario.choose_mode(engine, 0), "")
	Scenario.resolve_stack(engine)

	assert_eq(engine.hero().life, life + 1)
	assert_eq(Scenario.damage_on(engine, _ogre(engine)), 0, "The damage mode was not chosen.")


func test_the_chosen_damage_mode_deals_its_damage_to_its_target() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])
	var life: int = engine.hero().life

	Scenario.choose_mode(engine, 1)
	assert_eq(Scenario.choose_target(engine, MmReference.to_object(_ogre(engine))), "")
	Scenario.resolve_stack(engine)

	assert_eq(Scenario.damage_on(engine, _ogre(engine)), 1)
	assert_eq(engine.hero().life, life, "The life mode was not chosen.")


func test_a_mode_with_no_legal_target_is_left_out_and_the_only_other_is_chosen_without_asking() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [])

	assert_true(engine.pending_decision() is PriorityDecision, "CR 603.3c: no creature, so only the life mode.")
	var stacked: Array[MmGameObject] = Scenario.stacked_abilities(engine)
	assert_eq(stacked.size(), 1)
	assert_eq(stacked[0].chosen_mode, 0)


func test_a_modal_trigger_with_no_mode_that_can_be_chosen_is_removed() -> void:
	var picker: MmCardDefinition = Scenario.artifact("Picker", [Scenario.modal_triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU), [
		Scenario.ability_mode([Scenario.target(Scenario.of_type(CardType.CREATURE))], [Scenario.deal_damage(1, Scenario.targeted(0))]),
		Scenario.ability_mode([Scenario.target(Scenario.of_type(CardType.ENCHANTMENT))], [Scenario.destroy(Scenario.targeted(0))]),
	])])
	var engine: MmEngine = _upkeep([picker], [])

	assert_true(engine.pending_decision() is PriorityDecision)
	assert_eq(engine.game_state().stack.size(), 0, "CR 603.3c: no mode is chosen, so it is removed.")
	assert_eq(engine.game_state().pending_triggers.size(), 0)
	assert_eq(Scenario.events_of(engine, TriggerRemovedEvent).size(), 1)


func test_a_modal_trigger_whose_chosen_target_left_does_not_resolve() -> void:
	var razer: MmCardDefinition = Scenario.artifact("Razer", [Scenario.modal_triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU), [
		Scenario.ability_mode([], [Scenario.gain_life(1, Scenario.you())]),
		Scenario.ability_mode([Scenario.target(Scenario.of_type(CardType.ENCHANTMENT))], [Scenario.destroy(Scenario.targeted(0))]),
	])])
	var setup: MmEncounterSetup = Scenario.combat_setup([razer], [Scenario.enchantment("Glory", [])], [Scenario.free_disenchant("Disenchant")])
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [razer], [Scenario.enchantment("Glory", [])],
		[Scenario.free_disenchant("Disenchant")], [], 3, Step.UPKEEP)
	assert_not_null(engine, "No seed gave the needed hands.")
	var glory: MmReference = MmReference.to_object(Scenario.permanent_named(engine, engine.villain().id, "Glory"))
	Scenario.choose_mode(engine, 1)
	Scenario.choose_target(engine, glory)
	var life: int = engine.hero().life

	assert_eq(Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Disenchant"), [glory]), "")
	Scenario.resolve_stack(engine)

	var unresolved: int = 0
	for event: MmEvent in Scenario.events_of(engine, AbilityLeftStackEvent):
		if not (event as AbilityLeftStackEvent).did_resolve:
			unresolved += 1
	assert_eq(unresolved, 1, "CR 608.2b: its chosen mode's only target is gone.")
	assert_eq(engine.hero().life, life, "And the mode not chosen does nothing either.")


func test_the_chosen_mode_is_in_both_players_views() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])

	Scenario.choose_mode(engine, 0)

	assert_eq((engine.view_for(engine.hero()).stack.back() as MmObjectView).chosen_mode, 0)
	assert_eq((engine.view_for(engine.villain()).stack.back() as MmObjectView).chosen_mode, 0, "CR 700.2: the mode is announced.")


func test_a_simulation_copy_made_while_the_mode_is_asked_carries_on_from_there() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(7))

	assert_true(copy.pending_decision() is ChooseModeDecision)
	assert_eq(Scenario.choose_mode(copy, 1), "")
	assert_true(copy.pending_decision() is ChooseTargetDecision, "The copy asks for the chosen mode's target.")
	assert_true(engine.pending_decision() is ChooseModeDecision, "The original is still choosing.")


func test_a_simulation_copy_keeps_the_chosen_mode() -> void:
	var engine: MmEngine = _upkeep([_chime("Chime", Whose.YOU)], [Scenario.creature("Ogre", 3, 3)])
	Scenario.choose_mode(engine, 0)
	var life: int = engine.hero().life

	var copy: MmEngine = engine.simulation_copy(engine.hero().id, MmRng.new(7))
	Scenario.resolve_stack(copy)

	assert_eq(copy.hero().life, life + 1, "The copy resolves the mode the original chose.")
	assert_eq(Scenario.damage_on(copy, _ogre(copy)), 0)


func test_a_trigger_that_is_not_modal_has_no_chosen_mode() -> void:
	var chime: MmCardDefinition = Scenario.artifact("Plain Chime", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU),
		[Scenario.gain_life(1, Scenario.you())])])
	var engine: MmEngine = _upkeep([chime], [])

	assert_eq(Scenario.stacked_abilities(engine)[0].chosen_mode, SpellAbility.NO_MODE)


## An artifact costing {0}: "At the beginning of [param whose] upkeep, choose one —
## • You gain 1 life. • This artifact deals 1 damage to target creature."
func _chime(card_name: String, whose: Whose) -> MmCardDefinition:
	return Scenario.artifact(card_name, [Scenario.modal_triggered(Scenario.at_step(Step.UPKEEP, whose), [
		Scenario.ability_mode([], [Scenario.gain_life(1, Scenario.you())]),
		Scenario.ability_mode([Scenario.target(Scenario.of_type(CardType.CREATURE))], [Scenario.deal_damage(1, Scenario.targeted(0))]),
	])])


## The Hero's [param hero_cards] and the Villain's [param villain_cards] on the battlefield,
## stopped at the first decision of the Hero's upkeep on Game Turn 3.
func _upkeep(hero_cards: Array[MmCardDefinition], villain_cards: Array[MmCardDefinition]) -> MmEngine:
	var setup: MmEncounterSetup = Scenario.combat_setup(hero_cards, villain_cards)
	var engine: MmEngine = Scenario.permanents_ready_with(setup, hero_cards, villain_cards, [], [], 3, Step.UPKEEP)
	assert_not_null(engine, "No seed gave the needed hands.")
	return engine


func _ogre(engine: MmEngine) -> int:
	return Scenario.permanent_named(engine, engine.villain().id, "Ogre")
