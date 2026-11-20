class_name ExertCost
extends MmCost
## "Exert this creature" (CR 701.43): its source won't untap during the payer's next untap
## step. It may be exerted untapped, or again while it is exerted, and then still skips only
## that one untap step (CR 701.43b).


## CR 701.43c: an object that isn't on the battlefield can't be exerted.
func can_pay(state: MmGameState, source: MmGameObject, _payer_id: int) -> bool:
	return source.zone() == state.battlefield


func pay(state: MmGameState, source: MmGameObject, payer_id: int, _chosen: Array[int]) -> void:
	state.perform(ExertEvent.new(source.id, payer_id))
