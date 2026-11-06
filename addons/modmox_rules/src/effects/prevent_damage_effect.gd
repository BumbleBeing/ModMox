class_name PreventDamageEffect
extends MmEffect
## "Prevent the next [amount] damage that would be dealt to [recipients] this turn" or
## "Prevent all [combat] damage that would be dealt [to recipients] [by sources] this turn"
## (CR 615): creates a prevention effect that lasts the turn (A132, A147).
##
## Recipients given by a target, the controller or the source are locked when it resolves,
## so a shield on a creature is lost if the creature changes zones (ADR 0008). Recipients
## given by "each" are matched when damage would be dealt: an effect that changes the rules
## rather than characteristics also covers objects that arrive later (CR 611.2c). No
## recipients means any.

## How it is used up. Saved card files store these as numbers: never change or reuse a
## value, only add new ones.
enum Uses {
	## Prevents [member amount] in all, across any number of events, then ends (CR 615.7).
	NEXT_AMOUNT = 0,
	## Prevents all such damage until the turn ends.
	ALL_THIS_TURN = 1,
}

@export var uses: Uses = Uses.NEXT_AMOUNT
## For NEXT_AMOUNT: how much it prevents.
@export var amount: MmValue
@export var recipients: MmSelection
## Only damage from sources this matches; null means any source.
@export var sources: MmFilter
@export var combat_only: bool = false


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = []
	if uses == Uses.NEXT_AMOUNT:
		worked_out.append(amount.evaluate(state, context))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if step > 0:
		return []
	var remaining: int = ActiveReplacementEffect.UNLIMITED
	if uses == Uses.NEXT_AMOUNT:
		remaining = worked_out[0]
		if remaining <= 0:
			return []
	var prevention: PreventDamageReplacementEffect = PreventDamageReplacementEffect.new()
	prevention.sources = sources
	prevention.combat_only = combat_only
	var locked: Array[MmReference] = []
	if recipients is EachSelection:
		prevention.recipients = (recipients as EachSelection).filter
	elif recipients != null:
		for found: MmReference in recipients.select(state, context):
			if found.is_player() or _is_on_battlefield(state, found.id):
				locked.append(found)
		if locked.is_empty():
			return []
	var source: MmGameObject = state.object_or_last_known(context.source_object_id)
	var source_card: int = MmGameObject.NO_CARD if source == null else source.card_id
	return [ReplacementEffectCreatedEvent.new(prevention, context.controller_id, context.source_object_id, source_card,
		locked, remaining, CreateContinuousEffect.Duration.UNTIL_END_OF_TURN)]


func selections() -> Array[MmSelection]:
	return [] if recipients == null else [recipients]


func _is_on_battlefield(state: MmGameState, object_id: int) -> bool:
	var game_object: MmGameObject = state.object(object_id)
	return game_object != null and game_object.zone() == state.battlefield
