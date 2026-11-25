class_name CastSpellAction
extends MmAction
## Cast the card [member object_id] (CR 601), as its Adventure when [member as_adventure]
## (CR 715.3, engine ADR 0078), or bestowed when [member is_bestowed] (CR 702.103a).

var object_id: int
var as_adventure: bool = false
## Cast for its bestow cost as an Aura spell (CR 702.103a, engine ADR 0089).
var is_bestowed: bool = false


func _init(card_object_id: int, is_adventure: bool = false, bestowed: bool = false) -> void:
	object_id = card_object_id
	as_adventure = is_adventure
	is_bestowed = bestowed


func describe() -> String:
	return "cast %d%s%s" % [object_id, " as an Adventure" if as_adventure else "", " bestowed" if is_bestowed else ""]
