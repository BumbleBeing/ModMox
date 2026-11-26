class_name DamageCantBePreventedEffect
extends MmEffect
## "Damage can't be prevented this turn" (CR 615.12), as Stomp says: the Game Turn it
## resolves in is marked (MmGameState.can_damage_be_prevented()), and until that turn ends no
## prevention effect applies to any damage, protection's included (CR 702.16e), so no shield
## is used up. It is a rule of the turn, not a continuous effect on anything, so it reaches
## damage from sources and to recipients that did not exist yet as it resolved.
# Later: a prevention effect with an additional effect still applies, preventing nothing
# but doing the rest (CR 615.12), once a card has such a prevention effect.


func next_batch(state: MmGameState, _context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step == 0:
		events.append(DamagePreventionForbiddenEvent.new(state.game_turn))
	return events
