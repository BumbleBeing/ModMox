class_name SpellCopiedEvent
extends MmEvent
## A copy of a spell is put onto the stack (CR 707.10): a new Game Object that is not a card,
## made from the spell's copiable values (MmGameState.copiable_values_of()), on top of the
## stack, owned and controlled by the player who copied it. It has the spell's mode, X and
## targets. It is not cast, so no "whenever a player casts" trigger sees it.

var spell_id: int
var player_id: int
## The copy's ID, set when the event is applied.
var new_object_id: int = 0


func _init(copied_spell_id: int, copying_player_id: int) -> void:
	spell_id = copied_spell_id
	player_id = copying_player_id


func apply(state: MmGameState) -> void:
	var original: MmGameObject = state.object(spell_id)
	assert(original != null and original.zone() == state.stack, "Object %d is not on the stack." % spell_id)
	var copy: MmGameObject = state.create_object(MmGameObject.NO_CARD, player_id, state.copiable_values_of(original))
	copy.become_copy()
	copy.record_copied_choices(original)
	state.stack.insert(copy, MmZone.BOTTOM)
	new_object_id = copy.id


func describe() -> String:
	return "SPELL COPIED: object %d for player %d as object %d" % [spell_id, player_id, new_object_id]
