class_name DestroyEffect
extends MmEffect
## "Destroy [selection]" (CR 701.8): each selected permanent is put into its owner's
## graveyard, all at once. One with indestructible is not (CR 702.12b). A regeneration
## shield can replace the destruction unless [member can_be_regenerated] is false, as in
## Terror's "It can't be regenerated" (CR 701.19c).

@export var selection: MmSelection
@export var can_be_regenerated: bool = true


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent == null or permanent.zone() != state.battlefield:
			continue
		if state.characteristics_of(permanent).has_ability(IndestructibleAbility):
			continue
		events.append(ZoneChangeEvent.new(permanent, state.player(permanent.owner_id).graveyard, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.DESTROY, can_be_regenerated))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
