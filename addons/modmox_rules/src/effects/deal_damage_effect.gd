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
		if recipient.is_player() or _is_creature_on_battlefield(state, recipient.id):
			state.perform(DamageEvent.new(context.source_object_id, recipient, damage))


func selections() -> Array[MmSelection]:
	return [recipients]


## Only players and creatures can be dealt damage here; there are no planeswalkers or
## battles (ADR 0001).
func _is_creature_on_battlefield(state: MmGameState, object_id: int) -> bool:
	var game_object: MmGameObject = state.object(object_id)
	return game_object != null and game_object.zone() == state.battlefield \
		and state.characteristics_of(game_object).has_card_type(MmCardTypes.CardType.CREATURE)
