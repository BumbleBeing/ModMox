class_name SacrificeThisCost
extends MmCost
## "Sacrifice this permanent" (CR 701.21a), as Ominous Parcel's "Sacrifice this artifact":
## the ability's source moves from the battlefield to its owner's graveyard. Payable only
## while the payer controls it on the battlefield. It is not destruction, so indestructible
## and regeneration never stop it.


func can_pay(state: MmGameState, source: MmGameObject, payer_id: int) -> bool:
	return source != null and source.zone() == state.battlefield and source.controller_id == payer_id


## Sacrifices the source. ADR 0008: it is a new object in the graveyard, and its ability
## goes on resolving from its last-known information (CR 608.2h).
func pay(state: MmGameState, source: MmGameObject, _payer_id: int, _chosen: Array[int]) -> void:
	state.perform(ZoneChangeEvent.new(source, state.player(source.owner_id).graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.SACRIFICE))
