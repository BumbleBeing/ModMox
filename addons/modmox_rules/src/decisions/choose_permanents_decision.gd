class_name ChoosePermanentsDecision
extends MmPendingDecision
## A player picks exactly [member count] of [member candidate_ids] to pay part of a cost,
## such as "Tap three untapped creatures you control" or "return a permanent you control to
## its owner's hand" (CR 601.2h), or for an effect as it resolves, as "each opponent
## sacrifices a creature" asks (CR 701.21a). Answer: an Array of [member count] distinct object IDs from
## [member candidate_ids] (ADR 0016).

## What paying does to the permanents picked, so that what is asked can be put in words.
enum Purpose { TAP = 0, RETURN_TO_HAND = 1, SACRIFICE = 2 }

## The spell or ability, on the stack, whose cost or effect this is; for a mana ability's
## cost, which uses no stack, the ability's source ([member is_for_mana_ability]).
var stack_object_id: int
var count: int
## The permanents that may be picked, in ID order.
var candidate_ids: Array[int]
## What may be picked, so that what is asked can be put in words. Card data, never changed.
var filter: MmFilter
var purpose: Purpose = Purpose.TAP
## Whether an effect asks it as it resolves (SacrificeEffect), rather than a cost being
## paid, so it can never be taken back.
var is_for_effect: bool = false
## Whether a mana ability's cost asks it as the ability is activated (CR 605.3a, engine ADR
## 0105), as Jaspera Sentinel's "Tap an untapped creature you control": nothing is on the
## stack, and [member stack_object_id] is the ability's source.
var is_for_mana_ability: bool = false


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
