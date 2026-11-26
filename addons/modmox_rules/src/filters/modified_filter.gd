class_name ModifiedFilter
extends MmFilter
## Matches a modified permanent (CR 700.9): one with one or more counters on it, of any kind,
## one that is equipped, or one enchanted by an Aura its controller controls, as Akki
## Ember-Keeper's "Whenever a nontoken modified creature you control dies" says (engine ADR
## 0102). The permanent keeps no list of its attachments (ADR 0041), so this looks for an
## Equipment or Aura pointing at it. One that has left the battlefield is seen as it last
## existed (CR 603.10a): its counters then, the attachments still on the battlefield, which
## state-based actions have not yet moved, and those that left in the same batch as it did,
## as an Aura destroyed with its creature has. A card in any other zone is never modified.


func matches(state: MmGameState, candidate: MmReference, _context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	var game_object: MmGameObject = state.object_or_last_known(candidate.id)
	if game_object == null:
		return false
	var is_departed: bool = state.object(candidate.id) == null
	if not is_departed and game_object.zone() != state.battlefield:
		return false
	for kind: MmCounter.Kind in MmCounter.KINDS:
		if game_object.counters_of(kind) > 0:
			return true
	var attachments: Array[MmGameObject] = state.battlefield.objects()
	if is_departed:
		attachments.append_array(state.departed_with(game_object))
	for attachment: MmGameObject in attachments:
		if attachment.attached_to_object_id == candidate.id and _modifies(state, attachment, game_object):
			return true
	return false


## Whether [param attachment] makes [param permanent] modified: any Equipment, or an Aura its
## controller controls (CR 700.9).
func _modifies(state: MmGameState, attachment: MmGameObject, permanent: MmGameObject) -> bool:
	var subtypes: Array[String] = state.characteristics_of(attachment).subtypes
	if subtypes.has(AttachmentRules.EQUIPMENT):
		return true
	return subtypes.has(AttachmentRules.AURA) and attachment.controller_id == permanent.controller_id
