extends MmEffect
## A stand-in for "exile [recipients]", so tests can remove a creature from combat before
## any real removal effect exists in the game (ADR 0001).

@export var recipients: MmSelection


func resolve(state: MmGameState, context: MmEffectContext) -> void:
	for recipient: MmReference in recipients.select(state, context):
		var leaving: MmGameObject = state.object(recipient.id) if recipient.is_object() else null
		if leaving != null:
			# No zone-change reason exists for an effect yet; RESOLVED stands in for one.
			state.perform(ZoneChangeEvent.new(leaving, state.exile, MmZone.BOTTOM, ZoneChangeEvent.Reason.RESOLVED))


func selections() -> Array[MmSelection]:
	return [recipients]
