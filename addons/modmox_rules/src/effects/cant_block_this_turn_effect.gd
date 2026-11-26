class_name CantBlockThisTurnEffect
extends MmEffect
## "[selection] can't block this turn" (CR 509.1a), as Arena Athlete's Heroic says of
## "target creature an opponent controls": each selected permanent is marked, all at once,
## with the Game Turn it is in, and its controller can't declare it as a blocker in that turn
## (MmGameObject.cant_block_in_game_turn, CombatProcedure). It is a rule of the turn, not an
## ability, so losing all abilities does not lift it, unlike CantBlockAbility. A zone change
## leaves it behind with the old object (ADR 0008).

@export var selection: MmSelection


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		var permanent: MmGameObject = state.object(found.id) if found.is_object() else null
		if permanent == null or permanent.zone() != state.battlefield:
			continue
		events.append(CantBlockMarkedEvent.new(permanent.id, state.game_turn))
	return events


func selections() -> Array[MmSelection]:
	return [selection]
