class_name AbilitySpentEvent
extends MmEvent
## A once-each-game ability has been activated, so its source marks it Spent (CR 602.5b,
## ADR 0036).

var object_id: int
var ability_index: int


func _init(source_object_id: int, index: int) -> void:
	object_id = source_object_id
	ability_index = index


## Marks the ability Spent on its source.
func apply(state: MmGameState) -> void:
	state.object(object_id).mark_ability_spent(ability_index)


## For logs and debugging.
func describe() -> String:
	return "ABILITY SPENT: ability %d of object %d" % [ability_index, object_id]
