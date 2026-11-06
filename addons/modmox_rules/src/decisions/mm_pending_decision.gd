class_name MmPendingDecision
extends RefCounted
## A point where the engine has stopped because a player must choose, with the legal
## options (ADR 0003). Answers are plain data (ints and arrays of ints) so the decision
## log can be saved and replayed (ADR 0010).

## The player who must answer.
var player_id: int


func _init(deciding_player_id: int) -> void:
	player_id = deciding_player_id


## Returns why [param answer] is illegal, or "" if it is legal. Never changes anything.
## The answer is a Variant because each kind of decision takes a different shape of answer.
func validate(_answer: Variant) -> String:
	assert(false, "%s must override validate()." % get_script().resource_path)
	return "This decision cannot be answered."


## A short human-readable description for logs and debugging.
func describe() -> String:
	return "decision for player %d" % player_id


## Checks that [param answer] is one of the [param choice_count] values of a Choice enum.
func _check_choice(answer: Variant, choice_count: int) -> String:
	if typeof(answer) != TYPE_INT:
		return "Expected a choice number, got %s." % type_string(typeof(answer))
	var choice: int = answer
	if choice < 0 or choice >= choice_count:
		return "Choice %d is not one of the options." % choice
	return ""


## Checks that [param answer] is an Array of exactly [param count] distinct object IDs, all
## taken from [param candidate_ids].
func _check_distinct_ids(answer: Variant, count: int, candidate_ids: Array[int]) -> String:
	if typeof(answer) != TYPE_ARRAY:
		return "Expected a list of object IDs, got %s." % type_string(typeof(answer))
	var chosen: Array = answer
	if chosen.size() != count:
		return "Choose exactly %d, not %d." % [count, chosen.size()]
	var seen: Dictionary[int, bool] = {}
	for entry: Variant in chosen:
		if typeof(entry) != TYPE_INT:
			return "%s is not an object ID." % [entry]
		var id: int = entry
		if not candidate_ids.has(id):
			return "Object %d is not one of the options." % id
		if seen.has(id):
			return "Object %d was chosen twice." % id
		seen[id] = true
	return ""
