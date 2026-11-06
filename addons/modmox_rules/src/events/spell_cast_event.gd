class_name SpellCastEvent
extends MmEvent
## A spell becomes cast, once its costs are paid (CR 601.2i). "Whenever a player casts"
## triggers look for this.

var spell_id: int
var player_id: int


func _init(spell_object_id: int, caster_id: int) -> void:
	spell_id = spell_object_id
	player_id = caster_id


func apply(_state: MmGameState) -> void:
	pass  # Nothing changes; the spell is already on the stack.


func describe() -> String:
	return "SPELL CAST: object %d by player %d" % [spell_id, player_id]
