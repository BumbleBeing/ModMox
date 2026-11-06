class_name DeclareAttackersDecision
extends MmPendingDecision
## The active player chooses which of their creatures attack (CR 508.1a). Every attacker
## attacks the one opponent (ADR 0001). Answer: an Array of distinct object IDs from
## [member candidate_ids], of any length; an empty Array declares no attackers (ADR 0016).

## The creatures that may attack, in ID order.
var candidate_ids: Array[int]


func _init(deciding_player_id: int, attacker_candidate_ids: Array[int]) -> void:
	super(deciding_player_id)
	candidate_ids = attacker_candidate_ids.duplicate()


func validate(answer: Variant) -> String:
	# Later: attack requirements and restrictions (CR 508.1c-d).
	return _check_distinct_ids(answer, ANY_COUNT, candidate_ids)


func describe() -> String:
	return "player %d: declare attackers from %s" % [player_id, candidate_ids]
