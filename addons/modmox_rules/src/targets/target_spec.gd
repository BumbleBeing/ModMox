class_name TargetSpec
extends Resource
## One target requirement of a spell or ability: one instance of the word "target"
## (CR 115.1), with a Filter saying what may be chosen. Effects refer to the chosen target
## through a TargetSelection with this requirement's index (ADR 0014).

@export var filter: MmFilter


## Every player and permanent that is a legal choice right now, players first, each in ID
## order. "Target creature" means a creature on the battlefield (CR 115.4).
func legal_targets(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	# Later: spells and abilities on the stack as targets ("counter target spell").
	var result: Array[MmReference] = []
	for candidate: MmReference in candidates(state):
		if filter.matches(state, candidate, context) and not _is_protected(state, candidate, context):
			result.append(candidate)
	return result


## Whether [param target] is still a legal choice, as rechecked on resolution (CR 608.2b).
## A target that changed zones is a new object and so no longer exists (ADR 0008).
func is_still_legal(state: MmGameState, target: MmReference, context: MmEffectContext) -> bool:
	if target == null:
		return false
	if target.is_object():
		var game_object: MmGameObject = state.object(target.id)
		if game_object == null or game_object.zone() != state.battlefield:
			return false
	return filter.matches(state, target, context) and not _is_protected(state, target, context)


## Every player and permanent that could be a target, players first, each in ID order.
static func candidates(state: MmGameState) -> Array[MmReference]:
	var result: Array[MmReference] = []
	for player: MmPlayer in state.players:
		result.append(MmReference.to_player(player.id))
	var permanent_ids: Array[int] = state.battlefield.object_ids()
	permanent_ids.sort()
	for id: int in permanent_ids:
		result.append(MmReference.to_object(id))
	return result


## CR 702.16b: a permanent can't be the target of a spell, or an ability from a source, that
## it has protection from. The context's source is the spell or ability's own object or its
## source; ProtectionAbility follows an ability to its source either way.
func _is_protected(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if not candidate.is_object():
		return false
	return ProtectionAbility.protects(state, state.object(candidate.id), context.source_object_id)
