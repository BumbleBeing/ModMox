class_name CastSpellAction
extends MmAction
## Cast the card [member object_id] from hand (CR 601).

var object_id: int


func _init(card_object_id: int) -> void:
	object_id = card_object_id


func describe() -> String:
	return "cast %d" % object_id
