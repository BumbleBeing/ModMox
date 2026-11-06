class_name DealDamageEffect
extends MmEffect
## "Deal [amount] damage to [recipients]", with the spell or ability's source as the
## source of the damage (CR 120). Damage to several recipients is dealt at once, as one
## batch (A144).

@export var amount: MmValue
@export var recipients: MmSelection


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0:
		return events  # CR 120.8: 0 damage is not dealt; CR 107.1b: nor is a negative amount.
	for recipient: MmReference in recipients.select(state, context):
		if recipient.is_player() or _is_creature_on_battlefield(state, recipient.id):
			events.append(DamageEvent.new(context.source_object_id, recipient, worked_out[0]))
	return events


func selections() -> Array[MmSelection]:
	return [recipients]


## Only players and creatures can be dealt damage here; there are no planeswalkers or
## battles (ADR 0001).
func _is_creature_on_battlefield(state: MmGameState, object_id: int) -> bool:
	var game_object: MmGameObject = state.object(object_id)
	return game_object != null and game_object.zone() == state.battlefield \
		and state.characteristics_of(game_object).has_card_type(MmCardTypes.CardType.CREATURE)
