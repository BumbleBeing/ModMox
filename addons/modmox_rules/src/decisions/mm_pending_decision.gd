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
