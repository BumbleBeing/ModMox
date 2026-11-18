class_name ChoosePermanentsDecision
extends MmPendingDecision
## A player picks exactly [member count] of [member candidate_ids] to pay part of a cost,
## such as "Tap three untapped creatures you control" (CR 601.2h). Answer: an Array of
## [member count] distinct object IDs from [member candidate_ids] (ADR 0016).

## The spell or ability, on the stack, whose cost this is.
var stack_object_id: int
var count: int
## The permanents that may be picked, in ID order.
var candidate_ids: Array[int]
## What may be picked, so that what is asked can be put in words. Card data, never changed.
var filter: MmFilter


func _init(deciding_player_id: int, object_id: int, pick_count: int, candidates: Array[int], picked_from: MmFilter) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	count = pick_count
	candidate_ids = candidates.duplicate()
	filter = picked_from


func validate(answer: Variant) -> String:
	return _check_distinct_ids(answer, count, candidate_ids)


func describe() -> String:
	return "player %d: choose %d of %d permanents for object %d" % [player_id, count, candidate_ids.size(), stack_object_id]
