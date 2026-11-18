class_name ChooseModeDecision
extends MmPendingDecision
## The caster chooses the mode of the modal spell being cast (CR 601.2b), before its
## targets. Only modes whose targets could all be chosen are offered (CR 700.2a), and it is
## asked only when there are two or more; one is chosen without asking. Answer: the index
## of the chosen entry in [member modes].

var stack_object_id: int
## The modes that may be chosen, as indexes into the spell's modes, in order.
var modes: Array[int]
## For each entry of [member modes]: everything its targets could be, so a player can see
## what each mode would reach. Each entry is an Array of MmReference.
var mode_targets: Array[Array]


func _init(deciding_player_id: int, object_id: int, choosable: Array[int], targets_of_each: Array[Array]) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	modes = choosable.duplicate()
	mode_targets = targets_of_each.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, modes.size())


func describe() -> String:
	return "player %d: choose the mode of object %d (%d modes)" % [player_id, stack_object_id, modes.size()]
