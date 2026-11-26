class_name SacrificeSelectedEffect
extends MmEffect
## "Sacrifice [selection]" (CR 701.21a), as Harried Dronesmith's "Sacrifice it at the
## beginning of your next end step": the spell or ability's controller sacrifices each
## selected permanent they control, all at once, with nothing to choose. One that has left
## the battlefield is a new object and is not sacrificed (ADR 0008), and a player can
## sacrifice only a permanent they control. It is not destruction, so indestructible and
## regeneration never stop it. "Sacrifice [count] [filter]", which the player chooses, is
## SacrificeEffect.

## What is sacrificed, such as "it" (MovedCardsSelection).
@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var batch: Array[MmEvent] = []
	if step != 0:
		return batch
	for selected: MmReference in selection.select(state, context):
		if not selected.is_object():
			continue
		var permanent: MmGameObject = state.object(selected.id)
		if permanent == null or permanent.zone() != state.battlefield or permanent.controller_id != context.controller_id:
			continue  # CR 701.21a: only a permanent its player controls.
		batch.append(ZoneChangeEvent.new(permanent, state.player(permanent.owner_id).graveyard, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.SACRIFICE))
	return batch


func selections() -> Array[MmSelection]:
	return [selection]
