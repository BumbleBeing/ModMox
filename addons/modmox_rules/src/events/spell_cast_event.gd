class_name SpellCastEvent
extends MmEvent
## A spell becomes cast, once its costs are paid (CR 601.2i). "Whenever a player casts"
## triggers look for this.

var spell_id: int
var player_id: int


func _init(spell_object_id: int, caster_id: int) -> void:
	spell_id = spell_object_id
	player_id = caster_id


## The spell is already on the stack. One cast from the top of a library is no longer being
## cast, so its owner sees their new top card again (ADR 0054).
func apply(state: MmGameState) -> void:
	state.player(player_id).record_spell_cast()
	var spell: MmGameObject = state.object(spell_id)
	if spell != null and spell.is_being_cast_from_library:
		spell.finish_cast_from_library()


func describe() -> String:
	return "SPELL CAST: object %d by player %d" % [spell_id, player_id]
