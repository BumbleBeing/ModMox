class_name DelayedTrigger
extends RefCounted
## A delayed triggered ability (CR 603.7): made by a CreateDelayedTriggerEffect as its spell
## or ability resolves, it waits in the game state rather than on any object, so it triggers
## whatever has become of its source since, and triggers only the next time its event
## happens, then is gone (CR 603.7c, engine ADR 0103). It is bound to what the ability that
## created it remembered, so its "it" is that token. Never changes once made, so copies of
## the state share it.

var ability: TriggeredAbility
var controller_id: int
var source_object_id: int
## The place among its source's abilities of the ability that created it (ADR 0056), or -1
## for a spell's.
var ability_index: int
## The source's Card Identity, or MmGameObject.NO_CARD for an Emblem.
var source_card_id: int
var source_name: String
## What the ability that created it remembered: "it" (MovedCardsSelection, engine ADR 0080).
var moved_ids: Array[int] = []


func _init(delayed: TriggeredAbility, controlling_player_id: int, source: MmGameObject, source_characteristics: MmCharacteristics,
		index: int, remembered_ids: Array[int]) -> void:
	ability = delayed
	controller_id = controlling_player_id
	source_object_id = source.id
	source_card_id = source.card_id
	source_name = source_characteristics.name
	ability_index = index
	moved_ids = remembered_ids.duplicate()


## The context its trigger is matched in: its controller and source.
func context() -> MmEffectContext:
	return MmEffectContext.new(controller_id, source_object_id)


## The pending trigger it becomes as it triggers, its event about [param player_id] and
## [param object_id].
func triggered(player_id: int, object_id: int) -> PendingTrigger:
	var pending: PendingTrigger = PendingTrigger.of_delayed(ability, ability_index, controller_id, source_object_id,
		source_card_id, source_name, player_id, object_id)
	pending.moved_ids = moved_ids.duplicate()
	return pending


func describe() -> String:
	return "delayed trigger of %s (object %d, ability %d) for player %d, remembering %s" % [source_name, source_object_id,
		ability_index, controller_id, moved_ids]
