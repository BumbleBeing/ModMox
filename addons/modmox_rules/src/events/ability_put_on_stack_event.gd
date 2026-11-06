class_name AbilityPutOnStackEvent
extends MmEvent
## An activated ability is put on the stack as a Game Object that is not a card
## (CR 602.2a, 113.7a).

var source_object_id: int
var ability_index: int
var controller_id: int
## The new ability object's ID, set when the event is applied.
var new_object_id: int = 0


func _init(source_id: int, index: int, activating_player_id: int) -> void:
	source_object_id = source_id
	ability_index = index
	controller_id = activating_player_id


func apply(state: MmGameState) -> void:
	var source: MmGameObject = state.object(source_object_id)
	var source_characteristics: MmCharacteristics = state.characteristics_of(source)
	var created: MmGameObject = state.create_object(MmGameObject.NO_CARD, controller_id, null)
	created.ability = source_characteristics.abilities[ability_index]
	created.source_object_id = source_object_id
	created.source_name = source_characteristics.name
	state.stack.insert(created, MmZone.BOTTOM)
	new_object_id = created.id


func describe() -> String:
	return "ABILITY ON STACK: ability %d of object %d as object %d" % [ability_index, source_object_id, new_object_id]
