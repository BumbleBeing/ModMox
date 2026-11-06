class_name TriggeredAbilityPutOnStackEvent
extends MmEvent
## A pending trigger is put on the stack as a Game Object that is not a card (CR 603.3).

var pending: PendingTrigger
## The new ability object's ID, set when the event is applied.
var new_object_id: int = 0


func _init(triggered: PendingTrigger) -> void:
	pending = triggered


func apply(state: MmGameState) -> void:
	state.remove_pending_trigger(pending)
	var created: MmGameObject = state.create_object(MmGameObject.NO_CARD, pending.controller_id, null)
	created.ability = pending.ability
	created.source_object_id = pending.source_object_id
	created.source_card_id = pending.source_card_id
	created.source_name = pending.source_name
	created.triggering_player_id = pending.triggering_player_id
	created.triggering_object_id = pending.triggering_object_id
	state.stack.insert(created, MmZone.BOTTOM)
	new_object_id = created.id


func describe() -> String:
	return "TRIGGER ON STACK: %s as object %d" % [pending.describe(), new_object_id]
