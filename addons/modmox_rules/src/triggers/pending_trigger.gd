class_name PendingTrigger
extends RefCounted
## A triggered ability that has triggered but is not on the stack yet (CR 603.2-603.3). It
## records what triggered it, so "that player" and "that creature" still mean the right
## thing, and the card it came from, so the GUI can point at the card. Never changes once
## made, so copies of the state share it.

var ability: TriggeredAbility
var controller_id: int
var source_object_id: int
## The ability's place among its source's abilities as it triggered (ADR 0056).
var ability_index: int
## The source's Card Identity, or MmGameObject.NO_CARD for an Emblem.
var source_card_id: int
var source_name: String
var triggering_player_id: int
## The object the event was about, as it was then; 0 if none.
var triggering_object_id: int
## For a delayed triggered ability: what the ability that created it remembered, its "it"
## (MovedCardsSelection, engine ADR 0103). Empty for any other.
var moved_ids: Array[int] = []


## [param source] is null only for of_delayed(), which sets what it would have given.
func _init(triggered: TriggeredAbility, index: int, source: MmGameObject, source_characteristics: MmCharacteristics,
		player_id: int, object_id: int) -> void:
	ability = triggered
	ability_index = index
	if source != null:
		controller_id = source.controller_id
		source_object_id = source.id
		source_card_id = source.card_id
		source_name = source_characteristics.name
	triggering_player_id = player_id
	triggering_object_id = object_id


## A delayed triggered ability as it triggers (CR 603.7, engine ADR 0103): its source may
## have gone since it was created, so what it records of its source is given, not read.
static func of_delayed(triggered: TriggeredAbility, index: int, controlling_player_id: int, source_id: int,
		card_id: int, card_name: String, player_id: int, object_id: int) -> PendingTrigger:
	var pending: PendingTrigger = PendingTrigger.new(triggered, index, null, null, player_id, object_id)
	pending.controller_id = controlling_player_id
	pending.source_object_id = source_id
	pending.source_card_id = card_id
	pending.source_name = card_name
	return pending


## The context its condition, targets and effects are worked out in.
func context() -> MmEffectContext:
	var made: MmEffectContext = MmEffectContext.new(controller_id, source_object_id, [], triggering_player_id,
		triggering_object_id)
	return made.with_moved(moved_ids) if not moved_ids.is_empty() else made


func describe() -> String:
	return "trigger of %s (object %d, ability %d) for player %d, object %d" % [source_name, source_object_id, ability_index,
		triggering_player_id, triggering_object_id]
