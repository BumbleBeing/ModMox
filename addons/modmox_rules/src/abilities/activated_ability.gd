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
@export var targets: Array[TargetRequirement] = []
@export var effects: Array[MmEffect] = []
## "Activate only once each game" (CR 602.5b, ADR 0036): its source marks it Spent when it
## is activated, and it is never offered again from that object.
@export var is_once_each_game: bool = false
## "Activate only as a sorcery" (CR 602.5d): only in its controller's main phase with an
## empty stack.
@export var is_sorcery_speed: bool = false
## Works only while its card is in its owner's hand, as cycling does (CR 113.6b, 702.29b,
## ADR 0059), and never on the battlefield or in the command zone. Every other activated
## ability works only there, never from the hand.
@export var is_activated_from_hand: bool = false


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


## Whether this ability works where [param source] is now (CR 113.6): from the hand if it
## says so, and otherwise anywhere but the hand.
func works_in(state: MmGameState, source: MmGameObject) -> bool:
	return is_activated_from_hand == (source.zone() == state.player(source.owner_id).hand)


## Whether every cost can be paid right now with [param source] as the ability's source,
## by its controller.
func can_pay_costs(state: MmGameState, source: MmGameObject) -> bool:
	for cost: MmCost in costs:
		if not cost.can_pay(state, source, source.controller_id):
			return false
	return true


## Pays every cost, in order (CR 602.2b), for an ability that never stops to ask: a mana
## ability (CR 605.3a). One that uses the stack is paid by CastProcedure, which asks.
func pay_costs(state: MmGameState, source: MmGameObject) -> void:
	var nothing_chosen: Array[int] = []
	for cost: MmCost in costs:
		assert(cost.choice(state, source, source.controller_id) == null, "A mana ability's cost cannot ask a choice yet.")
		cost.pay(state, source, source.controller_id, nothing_chosen)


## Carries out every effect at once, in order, for a mana ability, which resolves
## immediately without using the stack (CR 605.3a).
func resolve_effects(state: MmGameState, context: MmEffectContext) -> void:
	for effect: MmEffect in effects:
		effect.perform_now(state, context)


func describe() -> String:
	return "activated ability (%d costs, %d targets, %d effects)" % [costs.size(), targets.size(), effects.size()]
