class_name ChooseLegendToKeepDecision
extends MmPendingDecision
## The legend rule (CR 704.5j): the player controls two or more legendary permanents named
## [member legend_name], and chooses the one to keep; the rest are put into their owners'
## graveyards with the other state-based actions (ADR 0051). Answer: the index of the kept
## permanent in [member candidate_ids].

## The name the candidates share.
var legend_name: String
## The legendary permanents with that name the player controls, in ID order.
var candidate_ids: Array[int]


func _init(deciding_player_id: int, shared_name: String, candidates: Array[int]) -> void:
	super(deciding_player_id)
	legend_name = shared_name
	candidate_ids = candidates.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, candidate_ids.size())


func describe() -> String:
	return "player %d: keep one legend named %s of %s" % [player_id, legend_name, candidate_ids]
