class_name SpellCastTrigger
extends MmTrigger
## "Whenever [whose] casts a [filter] spell" (CR 601.2i). "That player" is the caster and
## "that spell" the spell on the stack.

## Null matches any spell.
@export var filter: MmFilter = null
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var cast: SpellCastEvent = event as SpellCastEvent
	if cast == null or not is_whose(whose, cast.player_id, context):
		return false
	return filter == null or filter.matches(state, MmReference.to_object(cast.spell_id), context)


func triggering_player_id(_state: MmGameState, event: MmEvent) -> int:
	return (event as SpellCastEvent).player_id


func triggering_object_id(event: MmEvent) -> int:
	var cast: SpellCastEvent = event as SpellCastEvent
	return 0 if cast == null else cast.spell_id
