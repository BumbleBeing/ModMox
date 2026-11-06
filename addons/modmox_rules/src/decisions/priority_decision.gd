class_name PriorityDecision
extends MmPendingDecision
## A player holding priority chooses one of their legal actions (CR 117). Answer: the index
## of the chosen action in [member actions]. The list's order is deterministic (Pass first,
## then other actions by object ID), so an index replays exactly.

var actions: Array[MmAction]


func _init(deciding_player_id: int, legal_actions: Array[MmAction]) -> void:
	super(deciding_player_id)
	actions = legal_actions.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, actions.size())


func describe() -> String:
	return "player %d: priority (%d actions)" % [player_id, actions.size()]
