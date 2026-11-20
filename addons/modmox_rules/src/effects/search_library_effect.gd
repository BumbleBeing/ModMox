class_name SearchLibraryEffect
extends MmEffect
## "Search your library for up to [amount] [filter] cards, reveal them, put them into
## [destination], then shuffle." (CR 701.23, ADR 0057). Its controller searches their own
## library: as it begins they are asked a ChooseCardsInLibraryDecision of the cards that
## match, and may find from none up to [member amount] of them (CR 701.23b). The cards
## found move together, then the library is shuffled, whether or not anything was found.
# Later: ask an AsEntersPayOrEntersTappedAbility's cost before a found land moves onto the
# battlefield (ADR 0052), once a card can find one there; unasked, it enters tapped.

## What may be found, such as a basic land card.
@export var filter: MmFilter
## The most cards that may be found: 1 for "a [filter] card", X for "up to X".
@export var amount: MmValue
## Whether the cards found are revealed (CR 701.20): one put into a hand is then a Known
## Card there for the other player.
@export var reveal: bool = true
## Where the cards found go: any zone but the library. A card put onto the battlefield
## enters under the searcher's control.
@export var destination: MmZone.Kind = MmZone.Kind.HAND
## For the battlefield: "onto the battlefield tapped" (CR 110.5b).
@export var tapped: bool = false


func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	assert(destination != MmZone.Kind.LIBRARY, "A search puts what it finds into another zone.")
	var matching: Array[int] = []
	for card: MmGameObject in state.player(context.controller_id).library.objects():
		if filter == null or filter.matches(state, MmReference.to_object(card.id), context):
			matching.append(card.id)
	var most: int = maxi(0, amount.evaluate(state, context)) if amount != null else 1
	var constant: ConstantValue = amount as ConstantValue
	var is_up_to: bool = constant == null or constant.value != 1
	return ChooseCardsInLibraryDecision.new(context.controller_id, stack_object_id, matching, most, filter, is_up_to)


## The object IDs of the cards found, in the order they were chosen.
func numbers_with_answer(_state: MmGameState, _context: MmEffectContext, answer: Variant) -> Array[int]:
	var found: Array[int] = []
	for id: Variant in answer as Array:
		found.append(id as int)
	return found


func next_batch(state: MmGameState, context: MmEffectContext, step: int, numbers: Array[int]) -> Array[MmEvent]:
	var library: MmZone = state.player(context.controller_id).library
	var moves_first: bool = not numbers.is_empty()
	if step == 0 and moves_first:
		var to_zone: MmZone = state.zone(destination, context.controller_id)
		var batch: Array[MmEvent] = []
		for id: int in numbers:
			var found: MmGameObject = state.object(id)
			if found == null or found.zone() != library:
				continue
			var moved: ZoneChangeEvent = ZoneChangeEvent.new(found, to_zone, MmZone.BOTTOM, ZoneChangeEvent.Reason.SEARCH)
			moved.revealed = reveal
			moved.tapped_on_arrival = tapped
			batch.append(moved)
		return batch
	if step == (1 if moves_first else 0):
		return [ShuffleEvent.new(library)]
	return []
