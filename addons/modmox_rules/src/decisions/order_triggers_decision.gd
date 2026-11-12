class_name OrderTriggersDecision
extends MmPendingDecision
## A player chooses the order in which their simultaneous triggers go on the stack (CR
## 603.3b). Answer: a permutation of 0 to n-1 listing the triggers in the order they are put
## on the stack, so the first one listed resolves last (ADR 0016).

## Each trigger's source and its source's Card Identity, in the order they triggered.
var source_object_ids: Array[int]
var source_card_ids: Array[int]
## A short description of each trigger, for logs and debugging.
var descriptions: Array[String]
## Each trigger's ability, so the GUI can say what it does, and what its event was about
## ("that player", "that creature"): MmGameState.NO_PLAYER and 0 when nothing.
var abilities: Array[TriggeredAbility]
var triggering_player_ids: Array[int]
var triggering_object_ids: Array[int]


func _init(deciding_player_id: int, triggers: Array[PendingTrigger]) -> void:
	super(deciding_player_id)
	source_object_ids = []
	source_card_ids = []
	descriptions = []
	abilities = []
	triggering_player_ids = []
	triggering_object_ids = []
	for pending: PendingTrigger in triggers:
		source_object_ids.append(pending.source_object_id)
		source_card_ids.append(pending.source_card_id)
		descriptions.append(pending.describe())
		abilities.append(pending.ability)
		triggering_player_ids.append(pending.triggering_player_id)
		triggering_object_ids.append(pending.triggering_object_id)


func validate(answer: Variant) -> String:
	if typeof(answer) != TYPE_ARRAY:
		return "Expected a list of trigger numbers, got %s." % type_string(typeof(answer))
	var order: Array = answer
	if order.size() != source_object_ids.size():
		return "Order all %d triggers." % source_object_ids.size()
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in order:
		if typeof(entry) != TYPE_INT or (entry as int) < 0 or (entry as int) >= source_object_ids.size():
			return "%s is not one of the triggers." % [entry]
		if seen.has(entry as int):
			return "Trigger %d was listed twice." % (entry as int)
		seen[entry as int] = true
	return ""


func describe() -> String:
	return "player %d: order %d triggers" % [player_id, source_object_ids.size()]
