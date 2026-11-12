extends GutTest
## Auto-pass asks the Hero only on a step with a stop where there is something to cast,
## play or activate, or when the other player's spell or ability is on top of the stack.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const HERO: int = MmEncounterSetup.HERO_PLAYER_ID
const VILLAIN: int = MmEncounterSetup.VILLAIN_PLAYER_ID
const LAND_ID: int = 5
const SPELL_ID: int = 9


func test_it_passes_when_passing_is_all_there_is() -> void:
	assert_true(AutoPass.passes(_priority([]), _view(MmTurn.Step.PRECOMBAT_MAIN), StepStops.new()))


func test_it_passes_when_the_only_other_actions_are_mana_abilities() -> void:
	var decision: PriorityDecision = _priority([ActivateAbilityAction.new(LAND_ID, 0)])

	assert_true(AutoPass.passes(decision, _view(MmTurn.Step.PRECOMBAT_MAIN), StepStops.new()))


func test_it_stops_for_a_castable_spell_on_a_step_with_a_stop() -> void:
	var decision: PriorityDecision = _priority([ActivateAbilityAction.new(LAND_ID, 0), CastSpellAction.new(SPELL_ID)])

	assert_false(AutoPass.passes(decision, _view(MmTurn.Step.PRECOMBAT_MAIN), StepStops.new()))


func test_it_stops_for_a_land_to_play_on_a_step_with_a_stop() -> void:
	assert_false(AutoPass.passes(_priority([PlayLandAction.new(SPELL_ID)]), _view(MmTurn.Step.PRECOMBAT_MAIN), StepStops.new()))


func test_it_passes_a_castable_spell_on_a_step_with_no_stop() -> void:
	var decision: PriorityDecision = _priority([CastSpellAction.new(SPELL_ID)])

	assert_true(AutoPass.passes(decision, _view(MmTurn.Step.UPKEEP), StepStops.new()))


func test_the_villains_turn_uses_the_villains_row_of_stops() -> void:
	var decision: PriorityDecision = _priority([CastSpellAction.new(SPELL_ID)])
	var view: MmPlayerView = _view(MmTurn.Step.END)
	view.active_player_id = VILLAIN

	assert_false(AutoPass.passes(decision, view, StepStops.new()), "The Villain's row has a stop at the end step.")
	view.step = MmTurn.Step.PRECOMBAT_MAIN
	assert_true(AutoPass.passes(decision, view, StepStops.new()), "And none in the Villain's main phase.")


func test_it_stops_on_any_step_when_the_villains_object_is_on_top_of_the_stack() -> void:
	var view: MmPlayerView = _view(MmTurn.Step.UPKEEP)
	view.stack = [_stack_object(HERO), _stack_object(VILLAIN)]

	assert_false(AutoPass.passes(_priority([]), view, StepStops.new()))


func test_the_heros_own_object_on_top_does_not_stop_it() -> void:
	var view: MmPlayerView = _view(MmTurn.Step.UPKEEP)
	view.stack = [_stack_object(VILLAIN), _stack_object(HERO)]

	assert_true(AutoPass.passes(_priority([]), view, StepStops.new()))
	assert_true(AutoPass.is_own_object_on_top(view))


func test_a_yield_passes_priority_whatever_is_on_the_stack_or_stopped_at() -> void:
	var view: MmPlayerView = _view(MmTurn.Step.PRECOMBAT_MAIN)
	view.stack = [_stack_object(VILLAIN)]
	var decision: PriorityDecision = _priority([CastSpellAction.new(SPELL_ID)])

	assert_false(AutoPass.passes(decision, view, StepStops.new()), "Auto-pass stops for the Villain's spell.")
	assert_true(AutoPass.yields(decision))


func test_a_yield_never_chooses_attackers_or_blockers() -> void:
	assert_false(AutoPass.yields(DeclareAttackersDecision.new(HERO, [])))
	assert_false(AutoPass.yields(DeclareBlockersDecision.new(HERO, [], [], {}, {})))


func test_it_never_answers_a_decision_that_is_not_priority() -> void:
	assert_false(AutoPass.passes(DeclareAttackersDecision.new(HERO, []), _view(MmTurn.Step.UPKEEP), StepStops.new()))


func test_an_ability_that_is_not_a_mana_ability_counts_as_a_play() -> void:
	var view: MmPlayerView = _view(MmTurn.Step.PRECOMBAT_MAIN)
	var pinger: ActivatedAbility = ActivatedAbility.new()
	pinger.effects = [Scenario.deal_damage(1, Scenario.targeted(0))]
	pinger.targets = [Scenario.any_target()]
	view.battlefield[0].abilities.append(pinger)
	var decision: PriorityDecision = _priority([ActivateAbilityAction.new(LAND_ID, 1)])

	assert_false(AutoPass.is_mana_ability(decision.actions[1], view))
	assert_true(AutoPass.has_plays(decision, view))


func test_passing_is_found_wherever_it_is_in_the_list() -> void:
	var decision: PriorityDecision = PriorityDecision.new(HERO, [CastSpellAction.new(SPELL_ID), PassAction.new()] as Array[MmAction])

	assert_eq(AutoPass.pass_index(decision), 1)


func _priority(others: Array) -> PriorityDecision:
	var actions: Array[MmAction] = [PassAction.new()]
	for action: MmAction in others:
		actions.append(action)
	return PriorityDecision.new(HERO, actions)


## The Hero's view of their own turn at [param step], with one land that taps for mana.
func _view(step: MmTurn.Step) -> MmPlayerView:
	var view: MmPlayerView = MmPlayerView.new()
	view.viewer_id = HERO
	view.active_player_id = HERO
	view.step = step
	var land: MmObjectView = MmObjectView.new()
	land.id = LAND_ID
	land.controller_id = HERO
	land.abilities = [Scenario.tap_for_mana(MmMana.Type.GREEN, 1)]
	view.battlefield = [land]
	return view


func _stack_object(controller_id: int) -> MmObjectView:
	var item: MmObjectView = MmObjectView.new()
	item.controller_id = controller_id
	return item
