class_name SurveilDecision
extends MmPendingDecision
## The controller of a resolving surveil looks at the top cards of their library and puts
## any number of them into their graveyard and the rest back on top in any order
## (CR 701.25a, ADR 0068). While it is pending, that player's Player View shows those cards.
## Answer: an Array of two Arrays of object IDs, [graveyarded, kept]: the cards put into the
## graveyard in the order they go, so the last is the newest there, then the cards kept,
## top first. Every card of [member card_ids] is in exactly one of the two (ADR 0016).

var stack_object_id: int
## The object IDs of the cards looked at, top of the library first.
var card_ids: Array[int]


func _init(deciding_player_id: int, object_id: int, looked_at_ids: Array[int]) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	card_ids = looked_at_ids.duplicate()


func validate(answer: Variant) -> String:
	if typeof(answer) != TYPE_ARRAY or (answer as Array).size() != 2:
		return "Expected two lists: the cards graveyarded and the cards kept."
	for part: Variant in answer as Array:
		if typeof(part) != TYPE_ARRAY:
			return "Expected two lists of object IDs, got %s." % type_string(typeof(part))
	var everything: Array = ((answer as Array)[0] as Array) + ((answer as Array)[1] as Array)
	var error: String = _check_distinct_ids(everything, card_ids.size(), card_ids)
	if error != "":
		return "Put every card looked at in one place. %s" % error
	return ""


## The cards graveyarded by [param answer], in the order they go.
static func graveyarded_in(answer: Variant) -> Array[int]:
	var ids: Array[int] = []
	for id: Variant in (answer as Array)[0] as Array:
		ids.append(id as int)
	return ids


## The cards kept by [param answer], top first.
static func kept_in(answer: Variant) -> Array[int]:
	var ids: Array[int] = []
	for id: Variant in (answer as Array)[1] as Array:
		ids.append(id as int)
	return ids


func describe() -> String:
	return "player %d: surveil %s for object %d" % [player_id, card_ids, stack_object_id]
