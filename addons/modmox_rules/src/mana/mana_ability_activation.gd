class_name ManaAbilityActivation
extends RefCounted
## A mana ability being activated (CR 605.3a), at priority or in the middle of paying a cost:
## ability number [member ability_index] of [member object_id], for the color
## [member mana_type] it was offered for (ADR 0072). One whose cost asks a choice, as
## Jaspera Sentinel's "Tap an untapped creature you control" does, waits for it (engine ADR
## 0105); then, as any other at once, it is paid and resolves without using the stack.

var object_id: int
var ability_index: int
var mana_type: int = MmMana.NO_TYPE


func _init(action: ActivateAbilityAction) -> void:
	object_id = action.object_id
	ability_index = action.ability_index
	mana_type = action.mana_type


func copy() -> ManaAbilityActivation:
	return new(ActivateAbilityAction.new(object_id, ability_index, mana_type))


## What its cost asks before it is paid, or null when it asks nothing.
func choice(state: MmGameState) -> MmPendingDecision:
	return _ability(state).cost_choice(state, state.object(object_id))


## Pays its costs, with [param chosen] the answer to [method choice] (empty when it asked
## nothing), and adds its mana (CR 605.3a).
func finish(state: MmGameState, chosen: Array[int] = []) -> void:
	var source: MmGameObject = state.object(object_id)
	var ability: ActivatedAbility = _ability(state)
	if ability.is_activated_only_once():
		state.perform(AbilitySpentEvent.of(ability, source.id, ability_index))  # CR 602.5b
	ability.pay_costs(state, source, chosen)
	var context: MmEffectContext = MmEffectContext.new(source.controller_id, source.id)
	ability.resolve_effects(state, context.with_chosen_mana_type(mana_type))  # ADR 0072


func _ability(state: MmGameState) -> ActivatedAbility:
	return state.characteristics_of(state.object(object_id)).abilities[ability_index] as ActivatedAbility
