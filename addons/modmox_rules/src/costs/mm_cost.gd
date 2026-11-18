class_name MmCost
extends Resource
## One part of a cost (CR 118), such as tapping the source. Subclasses describe one kind each.
## [param payer_id] is the player paying: an ability's controller, or the caster of a spell,
## which has no controller until it is on the stack (CR 108.4).


## Whether this cost can be paid right now for [param source], by [param payer_id].
func can_pay(_state: MmGameState, _source: MmGameObject, _payer_id: int) -> bool:
	assert(false, "%s must override can_pay()." % get_script().resource_path)
	return false


## What the payer must choose to pay this cost, such as which creatures to tap, or null when
## it needs no choice. Asked once the cost can be paid.
func choice(_state: MmGameState, _source: MmGameObject, _payer_id: int) -> MmPendingDecision:
	return null


## Pays this cost through events, with [param chosen] the answer to choice() (empty when it
## asked none). Only called after can_pay() returned true.
func pay(_state: MmGameState, _source: MmGameObject, _payer_id: int, _chosen: Array[int]) -> void:
	assert(false, "%s must override pay()." % get_script().resource_path)
