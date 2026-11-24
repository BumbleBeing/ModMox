class_name DiscardEffect
extends MmEffect
## "[players] discard(s) [amount] cards" (CR 701.9a), as Splitskin Doll's "discard a card":
## the player chooses that many cards from their own hand and puts them into their graveyard,
## all at once. As it begins they are asked the ChooseCardsToDiscardDecision that discarding
## down to maximum hand size asks (CR 514.1), but only when there is a choice: holding that
## many cards or fewer, they discard every one, and with none nothing happens.
# Later: several players discarding, each asked in turn order, and discarding at random.
# Each once a card needs it.

@export var amount: MmValue
## The player who discards. "Discard a card" is you.
@export var players: MmSelection


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, _stack_object_id: int) -> MmPendingDecision:
	var discarder_id: int = _discarder_id(state, context)
	if discarder_id == MmGameState.NO_PLAYER:
		return null
	var count: int = maxi(0, amount.evaluate(state, context))
	var hand: Array[int] = _hand_ids(state, discarder_id)
	if count == 0 or hand.size() <= count:
		return null  # Nothing to choose: all of them go, or none.
	return ChooseCardsToDiscardDecision.new(discarder_id, count, hand)


## The object IDs of the cards discarded, with no choice to make: the whole hand, or none.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var discarder_id: int = _discarder_id(state, context)
	if discarder_id == MmGameState.NO_PLAYER or amount.evaluate(state, context) <= 0:
		return [] as Array[int]
	return _hand_ids(state, discarder_id)


## The object IDs of the cards chosen.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	var chosen: Array[int] = []
	for id: Variant in answer as Array:
		chosen.append(id as int)
	return chosen


func next_batch(state: MmGameState, context: MmEffectContext, step: int, numbers: Array[int]) -> Array[MmEvent]:
	if step != 0:
		return [] as Array[MmEvent]
	var discarder_id: int = _discarder_id(state, context)
	var batch: Array[MmEvent] = []
	if discarder_id == MmGameState.NO_PLAYER:
		return batch
	var discarder: MmPlayer = state.player(discarder_id)
	for id: int in numbers:
		var card: MmGameObject = state.object(id)
		if card == null or card.zone() != discarder.hand:
			continue
		batch.append(ZoneChangeEvent.new(card, discarder.graveyard, MmZone.BOTTOM, ZoneChangeEvent.Reason.DISCARD))
	return batch


func selections() -> Array[MmSelection]:
	return [players]


## The player [member players] finds, or MmGameState.NO_PLAYER.
func _discarder_id(state: MmGameState, context: MmEffectContext) -> int:
	var found: Array[int] = []
	for selected: MmReference in players.select(state, context):
		if selected.is_player():
			found.append(selected.id)
	assert(found.size() <= 1, "Later: several players discarding, each asked in turn order.")
	return found[0] if not found.is_empty() else MmGameState.NO_PLAYER


func _hand_ids(state: MmGameState, player_id: int) -> Array[int]:
	var ids: Array[int] = []
	for card: MmGameObject in state.player(player_id).hand.objects():
		ids.append(card.id)
	return ids
