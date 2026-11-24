class_name CreateTokenCopyEffect
extends MmEffect
## "Create a token that's a copy of [selection]" (CR 707.2), as Oltec Matterweaver's "Create a
## token that's a copy of target artifact token you control": for each object [member
## selection] finds, [member amount] tokens made from its copiable values, all at once, under
## the control of the player whose spell or ability created them. The copiable values are
## what its definition gives it (MmGameState.copiable_values_of()): a token's Token
## Definition (CR 111.3), or a card as its Modifications made it (ADR 0004). Not its
## counters, damage, tapped state or any continuous effect (CR 707.2). Each token is a new
## object (ADR 0008), so it enters untapped, with summoning sickness, and its own "enters"
## abilities trigger. An object that has left the battlefield is copied as it last existed
## there (CR 608.2h); a selection that finds nothing creates nothing.

## What is copied, such as the target of "target artifact token you control".
@export var selection: MmSelection
@export var amount: int = 1


func next_batch(state: MmGameState, context: MmEffectContext, step: int, _numbers: Array[int]) -> Array[MmEvent]:
	var events: Array[MmEvent] = []
	if step > 0:
		return events
	for found: MmReference in selection.select(state, context):
		if not found.is_object():
			continue
		var copied: MmGameObject = state.object_or_last_known(found.id)
		var values: MmCardDefinition = state.copiable_values_of(copied) if copied != null else null
		if values == null:
			continue
		for index: int in amount:
			events.append(TokenCreatedEvent.new(values, context.controller_id))
	return events


func selections() -> Array[MmSelection]:
	var used: Array[MmSelection] = [selection]
	return used
