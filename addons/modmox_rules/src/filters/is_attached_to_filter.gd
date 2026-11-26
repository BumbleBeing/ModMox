class_name IsAttachedToFilter
extends MmFilter
## Matches a permanent attached to one of what [member selection] finds (CR 301.5, 303.4):
## "Equipment attached to it", as Goblin Gaveleer's "gets +2/+0 for each Equipment attached
## to it" counts, with SourceSelection. The permanent keeps no list of its attachments
## (ADR 0041), so this reads the candidate's own attachment.

@export var selection: MmSelection


func matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object(candidate.id)
	if game_object == null or game_object.zone() != state.battlefield or game_object.attached_to_object_id == 0:
		return false
	for found: MmReference in selection.select(state, context):
		if found.is_object() and found.id == game_object.attached_to_object_id:
			return true
	return false
