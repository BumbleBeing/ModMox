class_name PendingTrigger
extends RefCounted
## A triggered ability that has triggered but is not on the stack yet (CR 603.2-603.3). It
## records what triggered it, so "that player" and "that creature" still mean the right
## thing, and the card it came from, so the GUI can point at the card. Never changes once
## made, so copies of the state share it.

var ability: TriggeredAbility
var controller_id: int
var source_object_id: int
## The source's Card Identity, or MmGameObject.NO_CARD for an Emblem.
var source_card_id: int
var source_name: String
var triggering_player_id: int
## The object the event was about, as it was then; 0 if none.
var triggering_object_id: int


func _init(triggered: TriggeredAbility, source: MmGameObject, source_characteristics: MmCharacteristics,
		player_id: int, object_id: int) -> void:
	ability = triggered
	controller_id = source.controller_id
	source_object_id = source.id
	source_card_id = source.card_id
	source_name = source_characteristics.name
	triggering_player_id = player_id
	triggering_object_id = object_id


## The context its condition, targets and effects are worked out in.
func context() -> MmEffectContext:
	return MmEffectContext.new(controller_id, source_object_id, [], triggering_player_id, triggering_object_id)


func describe() -> String:
	return "trigger of %s (object %d) for player %d, object %d" % [source_name, source_object_id, triggering_player_id, triggering_object_id]
