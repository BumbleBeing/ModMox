class_name CounterCountValue
extends MmValue
## "The number of [kind] counters on [selection]" (CR 122), such as the +1/+1 counters on
## this Equipment: the counters of [member kind] on everything [member selection] finds,
## added up, from its last-known information if it has left the battlefield (CR 608.2h).
## A card in any other zone has none (CR 122.2).

@export var kind: MmCounter.Kind = MmCounter.Kind.PLUS_ONE_PLUS_ONE
@export var selection: MmSelection


func evaluate(state: MmGameState, context: MmEffectContext) -> int:
	var total: int = 0
	for found: MmReference in selection.select(state, context):
		var game_object: MmGameObject = state.object_or_last_known(found.id) if found.is_object() else null
		if game_object != null:
			total += game_object.counters_of(kind)
	return total
