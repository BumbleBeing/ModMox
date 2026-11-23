class_name RemoveCountersCost
extends MmCost
## "Remove [amount] [kind] counters from this permanent" (CR 118.3, 122.8), as Guiding Hydra's
## "you may remove a +1/+1 counter from this creature". Payable only while the source is on
## the battlefield under the payer's control with at least that many.

@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
@export var amount: int = 1


func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return source != null and source.zone() == state.battlefield and source.controller_id == payer_id \
		and source.counters_of(kind) >= amount


func pay(state: MmGameState, source: MmGameObject, _payer_id: int, _chosen: Array[int]) -> void:
	state.perform(CountersRemovedEvent.new(source.id, kind, amount))
