class_name RegeneratedEvent
extends MmEvent
## A permanent that would have been destroyed regenerates instead (CR 701.19a): its shield
## is used up, and all damage is removed from it. That ends any deathtouch damage too, so
## the next state-based action check does not destroy it again (CR 704.5h). Tapping it and
## removing it from combat are events of their own in the same batch.

var object_id: int
var shield_timestamp: int


func _init(regenerating_id: int, shield: int) -> void:
	object_id = regenerating_id
	shield_timestamp = shield


func apply(state: MmGameState) -> void:
	state.use_replacement_effect(shield_timestamp, 1)
	var permanent: MmGameObject = state.object(object_id)
	permanent.remove_damage()
	permanent.clear_deathtouch_damage()


func describe() -> String:
	return "REGENERATED: object %d using shield %d" % [object_id, shield_timestamp]
