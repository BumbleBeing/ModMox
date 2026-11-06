class_name PayWithManaAction
extends MmAction
## While paying a cost, spend the mana at [member unit_index] of your pool. It pays a
## matching symbol if one is still owed, otherwise generic mana.

var unit_index: int


func _init(pool_index: int) -> void:
	unit_index = pool_index


func describe() -> String:
	return "pay with mana %d" % unit_index
