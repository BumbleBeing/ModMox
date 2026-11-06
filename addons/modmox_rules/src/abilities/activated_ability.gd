class_name ActivatedAbility
extends MmAbility
## "[Cost]: [Effect]" (CR 602). Whether it is a mana ability is worked out from its
## content (CR 605.1a), never set by hand, so a Modification that adds a target turns a
## mana ability into one that uses the stack.

## The mana part of its cost, such as {B} in "{B}: Regenerate this creature", paid like a
## spell's mana cost (CR 602.2b). Null when it costs no mana.
@export var mana_cost: MmManaCost = null
## Every other part of its cost, such as {T}, paid once the mana is (CR 601.2h).
@export var costs: Array[MmCost] = []
@export var targets: Array[TargetSpec] = []
@export var effects: Array[MmEffect] = []


## CR 605.1a: it could add mana and it has no target. There are no loyalty abilities in
## this game (ADR 0001), so that part of the rule never applies.
func is_mana_ability() -> bool:
	if not targets.is_empty():
		return false
	var adds_mana: bool = false
	for effect: MmEffect in effects:
		if effect.has_targets():
			return false
		if effect.adds_mana():
			adds_mana = true
	return adds_mana


## Whether every cost can be paid right now with [param source] as the ability's source.
func can_pay_costs(state: MmGameState, source: MmGameObject) -> bool:
	for cost: MmCost in costs:
		if not cost.can_pay(state, source):
			return false
	return true


## Pays every cost, in order (CR 602.2b).
func pay_costs(state: MmGameState, source: MmGameObject) -> void:
	for cost: MmCost in costs:
		cost.pay(state, source)


## Carries out every effect at once, in order, for a mana ability, which resolves
## immediately without using the stack (CR 605.3a).
func resolve_effects(state: MmGameState, context: MmEffectContext) -> void:
	for effect: MmEffect in effects:
		effect.perform_now(state, context)


func describe() -> String:
	return "activated ability (%d costs, %d targets, %d effects)" % [costs.size(), targets.size(), effects.size()]
