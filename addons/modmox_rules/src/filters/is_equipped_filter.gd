class_name IsEquippedFilter
extends MmFilter
## Matches an equipped permanent: one on the battlefield with at least one Equipment attached
## to it (CR 301.5), as in "equipped creatures you control" and "as long as this creature is
## equipped". The permanent keeps no list of its attachments (ADR 0041), so this looks for
## an Equipment on the battlefield pointing at it. Wrap it in a NotFilter for "unequipped".


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object(candidate.id)
	if game_object == null or game_object.zone() != state.battlefield:
		return false
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.attached_to_object_id == candidate.id \
				and state.characteristics_of(permanent).subtypes.has(AttachmentRules.EQUIPMENT):
			return true
	return false
