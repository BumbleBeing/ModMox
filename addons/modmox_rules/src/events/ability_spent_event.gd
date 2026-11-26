class_name AbilitySpentEvent
extends MmEvent
## A once-each-game or once-each-turn ability has been activated, so its source marks it
## Spent (CR 602.5b, ADR 0036 and its addendum): for good, or for the Game Turn it was
## activated in.

var object_id: int
var ability_index: int
## Whether it is Spent only for this Game Turn, as "activate only once each turn" is.
var is_for_this_turn: bool


func _init(source_object_id: int, index: int, for_this_turn: bool = false) -> void:
	object_id = source_object_id
	ability_index = index
	is_for_this_turn = for_this_turn


## For the ability at [param index] of [param source_object_id], when activating it spends
## it: Spent for good when it is once each game, for this Game Turn when once each turn.
static func of(ability: ActivatedAbility, source_object_id: int, index: int) -> AbilitySpentEvent:
	return new(source_object_id, index, ability.is_once_each_turn)


## Marks the ability Spent on its source.
func apply(state: MmGameState) -> void:
	if is_for_this_turn:
		state.object(object_id).record_activated(ability_index, state.game_turn)
	else:
		state.object(object_id).mark_ability_spent(ability_index)


## For logs and debugging.
func describe() -> String:
	return "ABILITY SPENT: ability %d of object %d%s" % [ability_index, object_id,
		" this turn" if is_for_this_turn else ""]
