class_name CastSpellAction
extends MmAction
## Cast the card [member object_id] (CR 601), as its Adventure when [member as_adventure]
## (CR 715.3, engine ADR 0078).

var object_id: int
var as_adventure: bool = false


func _init(card_object_id: int, is_adventure: bool = false) -> void:
	object_id = card_object_id
	as_adventure = is_adventure


func describe() -> String:
	return "cast %d%s" % [object_id, " as an Adventure" if as_adventure else ""]
