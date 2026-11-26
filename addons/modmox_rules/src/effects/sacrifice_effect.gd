class_name SacrificeEffect
extends MmEffect
## "[players] sacrifice(s) [count] [filter]" (CR 701.21a), as Agent of the Fates's "each
## opponent sacrifices a creature of their choice": the player chooses that many of the
## permanents they control that match [member filter], and they move to their owners'
## graveyards all at once. As it begins they are asked the ChoosePermanentsDecision that
## SacrificePermanentsCost asks, marked as an effect's, but only when there is a choice:
## controlling that many or fewer, they sacrifice every one, and with none nothing happens.
## It is not destruction, so indestructible and regeneration never stop it. A player can
## sacrifice only a permanent they control, so the filter is authored without "you control".
# Later: several players sacrificing, each choosing in turn order (CR 101.4), once a game
# has more than two players or a card says "each player".

## The player who sacrifices, such as each opponent.
@export var players: MmSelection
@export var count: int = 1
@export var filter: MmFilter


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	var sacrificer_id: int = _sacrificer_id(state, context)
	if sacrificer_id == MmGameState.NO_PLAYER:
		return null
	var candidates: Array[int] = _candidates(state, context, sacrificer_id)
	if count <= 0 or candidates.size() <= count:
		return null  # Nothing to choose: all of them go, or none.
	var decision: ChoosePermanentsDecision = ChoosePermanentsDecision.new(sacrificer_id, stack_object_id, count,
		candidates, filter)
	decision.purpose = ChoosePermanentsDecision.Purpose.SACRIFICE
	decision.is_for_effect = true
	return decision


## The object IDs of the permanents sacrificed, with no choice to make: every match, or none.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var sacrificer_id: int = _sacrificer_id(state, context)
	if sacrificer_id == MmGameState.NO_PLAYER or count <= 0:
		return [] as Array[int]
	return _candidates(state, context, sacrificer_id)


## The object IDs of the permanents chosen.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	var chosen: Array[int] = []
	for id: Variant in answer as Array:
		chosen.append(id as int)
	return chosen


func next_batch(state: MmGameState, context: MmEffectContext, step: int, numbers: Array[int]) -> Array[MmEvent]:
	var batch: Array[MmEvent] = []
	if step != 0:
		return batch
	var sacrificer_id: int = _sacrificer_id(state, context)
	for id: int in numbers:
		var permanent: MmGameObject = state.object(id)
		if permanent == null or permanent.zone() != state.battlefield or permanent.controller_id != sacrificer_id:
			continue  # CR 701.21a: only a permanent its player controls.
		batch.append(ZoneChangeEvent.new(permanent, state.player(permanent.owner_id).graveyard, MmZone.BOTTOM,
			ZoneChangeEvent.Reason.SACRIFICE))
	return batch


func selections() -> Array[MmSelection]:
	return [players]


## The player [member players] finds, or MmGameState.NO_PLAYER.
func _sacrificer_id(state: MmGameState, context: MmEffectContext) -> int:
	var found: Array[int] = []
	for selected: MmReference in players.select(state, context):
		if selected.is_player():
			found.append(selected.id)
	assert(found.size() <= 1, "Later: several players sacrificing, each choosing in turn order.")
	return found[0] if not found.is_empty() else MmGameState.NO_PLAYER


## The permanents [param player_id] controls that match [member filter], in ID order.
func _candidates(state: MmGameState, context: MmEffectContext, player_id: int) -> Array[int]:
	var found: Array[int] = []
	for permanent: MmGameObject in state.battlefield.objects():
		if permanent.controller_id != player_id:
			continue
		if filter == null or filter.matches(state, MmReference.to_object(permanent.id), context):
			found.append(permanent.id)
	found.sort()
	return found
