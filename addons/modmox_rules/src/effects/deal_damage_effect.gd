class_name DealDamageEffect
extends MmEffect
## "[source] deals [amount] damage to [recipients]" (CR 120), with the spell or ability's
## own source as the source of the damage unless [member source] names another, such as
## "it" for the creature whose entering triggered the ability. A source that has left the
## battlefield deals it as it last existed (CR 608.2h). Damage to several recipients is
## dealt at once, as one batch (A144).

@export var amount: MmValue
@export var recipients: MmSelection
## What deals the damage, or null for the spell or ability's own source. The first object
## it selects as the effect begins deals it; none deals no damage.
@export var source: MmSelection = null


## The amount, then the ID of the object dealing it (0 for none).
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context), _source_id(state, context)]
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0 or worked_out[0] <= 0 or worked_out[1] == 0:
		return events  # CR 120.8: 0 damage is not dealt; CR 107.1b: nor is a negative amount.
	for recipient: MmReference in recipients.select(state, context):
		if recipient.is_player() or _is_creature_on_battlefield(state, recipient.id):
			events.append(DamageEvent.new(worked_out[1], recipient, worked_out[0]))
	return events


func selections() -> Array[MmSelection]:
	if source == null:
		return [recipients]
	return [recipients, source]


func _source_id(state: MmGameState, context: MmEffectContext) -> int:
	if source == null:
		return context.source_object_id
	for found: MmReference in source.select(state, context):
		if found.is_object():
			return found.id
	return 0


## Only players and creatures can be dealt damage here; there are no planeswalkers or
## battles (ADR 0001).
func _is_creature_on_battlefield(state: MmGameState, object_id: int) -> bool:
	var game_object: MmGameObject = state.object(object_id)
	return game_object != null and game_object.zone() == state.battlefield \
		and state.characteristics_of(game_object).has_card_type(MmCardTypes.CardType.CREATURE)
