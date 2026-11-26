class_name OnceEachTurnDoneEvent
extends MmEvent
## A triggered ability's "you may" that is done only once each turn has been done, as
## Irreverent Gremlin's "Do this only once each turn" says, so its source marks the ability
## Spent for the Game Turn (engine ADR 0054's second addendum): it triggers no more that
## turn, and asks nothing from the stack.

var object_id: int
var ability_index: int


func _init(source_object_id: int, index: int) -> void:
	object_id = source_object_id
	ability_index = index


func apply(state: MmGameState) -> void:
	state.object(object_id).record_triggered(ability_index, state.game_turn)


func describe() -> String:
	return "DONE ONCE THIS TURN: ability %d of object %d" % [ability_index, object_id]
