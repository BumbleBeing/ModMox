class_name SpellCastTrigger
extends MmTrigger
## "Whenever [whose] casts a [filter] spell" (CR 601.2i). "That player" is the caster and
## "that spell" the spell on the stack. With [member nth_each_turn] it is "Whenever you cast
## your second spell each turn", as Clarion Spirit says: it triggers only for the caster's
## Nth spell this turn, counting every spell they cast this turn (MmPlayer.spells_cast_this_turn),
## those cast before this ability's source was on the battlefield too.

## Null matches any spell.
@export var filter: MmFilter = null
@export var whose: MmTrigger.Whose = MmTrigger.Whose.ANY
## "Your second spell each turn": with N above 0, only the caster's Nth spell this turn.
@export var nth_each_turn: int = 0


func matches(state: MmGameState, event: MmEvent, context: MmEffectContext) -> bool:
	var cast: SpellCastEvent = event as SpellCastEvent
	if cast == null or not is_whose(whose, cast.player_id, context):
		return false
	# The count already holds this spell: it is counted as it becomes cast.
	if nth_each_turn > 0 and state.player(cast.player_id).spells_cast_this_turn != nth_each_turn:
		return false
	return filter == null or filter.matches(state, MmReference.to_object(cast.spell_id), context)


func triggering_player_id(_state: MmGameState, event: MmEvent) -> int:
	return (event as SpellCastEvent).player_id


func triggering_object_id(event: MmEvent) -> int:
	var cast: SpellCastEvent = event as SpellCastEvent
	return 0 if cast == null else cast.spell_id
