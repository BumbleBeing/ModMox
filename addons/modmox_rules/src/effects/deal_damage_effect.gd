class_name DealDamageEffect
extends MmEffect
## "Deal [amount] damage to [recipients]", with the spell or ability's source as the
## source of the damage (CR 120).

@export var amount: MmValue
@export var recipients: MmSelection


func resolve(state: MmGameState, context: MmEffectContext) -> void:
	var damage: int = amount.evaluate(state, context)
	if damage <= 0:
		return  # CR 120.8: 0 damage is not dealt.
	for recipient: MmReference in recipients.select(state, context):
		if recipient.is_player():
			state.perform(DamageEvent.new(context.source_object_id, recipient.id, damage))
		# Later (milestone 6): damage to creatures (CR 120.3e).


func selections() -> Array[MmSelection]:
	return [recipients]
