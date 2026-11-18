class_name PayLifeCost
extends MmCost
## "Pay [amount] life" (CR 119.4): the payer loses that much life. It can be paid only while
## their life total is at least [member amount], so paying all of it is possible and loses
## the encounter once state-based actions are checked (CR 704.5a).

@export var amount: int = 1


func can_pay(state: MmGameState, _source: MmGameObject, payer_id: int) -> bool:
	return state.player(payer_id).life >= amount


## Paying life is losing it: not damage, so nothing that prevents damage applies.
func pay(state: MmGameState, _source: MmGameObject, payer_id: int, _chosen: Array[int]) -> void:
	if amount > 0:
		state.perform(LifeLostEvent.new(payer_id, amount))
