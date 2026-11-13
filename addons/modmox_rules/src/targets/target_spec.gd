class_name TargetSpec
extends Resource
## One target requirement of a spell or ability: one instance of the word "target"
## (CR 115.1), with a Filter saying what may be chosen. Effects refer to the chosen target
## through a TargetSelection with this requirement's index (ADR 0014).

## Where the targets are. Saved in Content, so values are explicit and only ever added.
## SPELLS is "target spell": a spell on the stack, never an ability (CR 115.1, 112.1).
## GRAVEYARD_CARDS is "target card in a graveyard", narrowed by the Filter to "creature
## card in your graveyard". ABILITIES is "target activated or triggered ability": an
## ability on the stack, never a spell, and never a mana ability, which does not use the
## stack (CR 605.3a).
enum Among { PLAYERS_AND_PERMANENTS = 0, SPELLS = 1, GRAVEYARD_CARDS = 2, ABILITIES = 3 }

## What may be chosen. Null for anything, as in "target spell".
@export var filter: MmFilter
@export var among: Among = Among.PLAYERS_AND_PERMANENTS


## Every legal choice right now. Players and permanents: players first, each in ID order;
## "target creature" means a creature on the battlefield (CR 115.4). Spells and abilities:
## top of the stack first, leaving out the spell this requirement belongs to (CR 115.5).
## Cards in graveyards: each player's graveyard in player ID order, in the zone's order.
func legal_targets(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var result: Array[MmReference] = []
	for candidate: MmReference in _candidates(state, context):
		if _matches(state, candidate, context):
			result.append(candidate)
	return result


## Whether [param target] is still a legal choice, as rechecked on resolution (CR 608.2b).
## A target that changed zones is a new object and so no longer exists (ADR 0008).
func is_still_legal(state: MmGameState, target: MmReference, context: MmEffectContext) -> bool:
	if target == null:
		return false
	if among == Among.PLAYERS_AND_PERMANENTS:
		if target.is_object():
			var game_object: MmGameObject = state.object(target.id)
			if game_object == null or game_object.zone() != state.battlefield:
				return false
		return _matches(state, target, context)
	return target.is_object() and _is_in_place(state, target.id) and _matches(state, target, context)


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


func _candidates(state: MmGameState, context: MmEffectContext) -> Array[MmReference]:
	var result: Array[MmReference] = []
	match among:
		Among.PLAYERS_AND_PERMANENTS:
			return candidates(state)
		Among.GRAVEYARD_CARDS:
			for player: MmPlayer in state.players:
				for id: int in player.graveyard.object_ids():
					result.append(MmReference.to_object(id))
		_:
			var on_stack: Array[MmGameObject] = state.stack.objects()
			for index: int in range(on_stack.size() - 1, -1, -1):
				if _is_in_place(state, on_stack[index].id) and on_stack[index].id != context.source_object_id:
					result.append(MmReference.to_object(on_stack[index].id))
	return result


## Whether [param object_id] is where this requirement looks, when that is not the
## battlefield: a spell or an ability on the stack, or a card in a graveyard.
func _is_in_place(state: MmGameState, object_id: int) -> bool:
	var game_object: MmGameObject = state.object(object_id)
	if game_object == null or game_object.zone() == null:
		return false
	if among == Among.GRAVEYARD_CARDS:
		return game_object.zone().kind == MmZone.Kind.GRAVEYARD
	return game_object.zone() == state.stack and game_object.is_card() == (among == Among.SPELLS)


func _matches(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	if filter != null and not filter.matches(state, candidate, context):
		return false
	return not _is_protected(state, candidate, context)


## CR 702.16b: a permanent can't be the target of a spell, or an ability from a source, that
## it has protection from. The context's source is the spell or ability's own object or its
## source; ProtectionAbility follows an ability to its source either way.
func _is_protected(state: MmGameState, candidate: MmReference, context: MmEffectContext) -> bool:
	# CR 113.6: protection works only on the battlefield, so a spell, an ability on the
	# stack and a card in a graveyard are never protected.
	if not candidate.is_object() or among != Among.PLAYERS_AND_PERMANENTS:
		return false
	return ProtectionAbility.protects(state, state.object(candidate.id), context.source_object_id)
