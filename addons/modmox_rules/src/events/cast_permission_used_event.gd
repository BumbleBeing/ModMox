class_name CastPermissionUsedEvent
extends MmEvent
## A permission to cast from the top of a library (CastFromTopOfLibraryAbility) was used
## as a cast began, so it is Spent for the rest of the turn (ADR 0054).

var object_id: int
var ability_index: int
## The name of the spell cast with it, kept for presentation, since the spell itself is
## gone once it leaves the stack.
var spell_name: String
## The Game Turn it was used in, set when the event is applied.
var game_turn: int = 0


func _init(source_object_id: int, index: int, cast_spell_name: String) -> void:
	object_id = source_object_id
	ability_index = index
	spell_name = cast_spell_name


## Marks the permission used in the current Game Turn on its source.
func apply(state: MmGameState) -> void:
	game_turn = state.game_turn
	state.object(object_id).record_permission_used(ability_index, game_turn, spell_name)


## For logs and debugging.
func describe() -> String:
	return "CAST PERMISSION USED: ability %d of object %d, for %s" % [ability_index, object_id, spell_name]
