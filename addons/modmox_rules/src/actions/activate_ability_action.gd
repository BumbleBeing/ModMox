class_name ActivateAbilityAction
extends MmAction
## Activate ability number [member ability_index] of [member object_id], counting in the
## order of its current characteristics' abilities (CR 602).

var object_id: int
var ability_index: int


func _init(source_object_id: int, index: int) -> void:
	object_id = source_object_id
	ability_index = index


func describe() -> String:
	return "activate ability %d of object %d" % [ability_index, object_id]
