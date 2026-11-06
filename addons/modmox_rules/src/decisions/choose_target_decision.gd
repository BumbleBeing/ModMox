class_name ChooseTargetDecision
extends MmPendingDecision
## The caster chooses the target for requirement [member target_index] of the spell or
## ability being put on the stack (CR 601.2c). Answer: the index of the chosen entry in
## [member candidates], which lists players first, then permanents, each in ID order.

var stack_object_id: int
var target_index: int
var candidates: Array[MmReference]


func _init(deciding_player_id: int, object_id: int, requirement_index: int, legal: Array[MmReference]) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	target_index = requirement_index
	candidates = legal.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, candidates.size())


func describe() -> String:
	return "player %d: choose target %d of object %d (%d candidates)" % [player_id, target_index, stack_object_id, candidates.size()]
