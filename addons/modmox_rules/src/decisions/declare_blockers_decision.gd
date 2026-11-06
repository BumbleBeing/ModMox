class_name DeclareBlockersDecision
extends MmPendingDecision
## The defending player chooses which of their creatures block, and which attacker each
## blocks (CR 509.1a). Answer: an Array of [blocker ID, attacker ID] pairs, with blockers
## from [member candidate_blocker_ids] and attackers from [member attacker_ids]. Several
## blockers may block one attacker; each blocker blocks one attacker. An empty Array
## declares no blockers (ADR 0016).

## The creatures that may block, in ID order.
var candidate_blocker_ids: Array[int]
## The attacking creatures, in ID order.
var attacker_ids: Array[int]


func _init(deciding_player_id: int, blocker_candidate_ids: Array[int], attacking_ids: Array[int]) -> void:
	super(deciding_player_id)
	candidate_blocker_ids = blocker_candidate_ids.duplicate()
	attacker_ids = attacking_ids.duplicate()


func validate(answer: Variant) -> String:
	if typeof(answer) != TYPE_ARRAY:
		return "Expected a list of [blocker, attacker] pairs, got %s." % type_string(typeof(answer))
	var blocking: Dictionary[int, bool] = {}
	for entry: Variant in answer as Array:
		if typeof(entry) != TYPE_ARRAY or (entry as Array).size() != 2:
			return "%s is not a [blocker, attacker] pair." % [entry]
		var pair: Array = entry
		if typeof(pair[0]) != TYPE_INT or typeof(pair[1]) != TYPE_INT:
			return "%s is not a pair of object IDs." % [pair]
		var blocker: int = pair[0]
		var attacker: int = pair[1]
		if not candidate_blocker_ids.has(blocker):
			return "Object %d cannot block." % blocker
		if not attacker_ids.has(attacker):
			return "Object %d is not attacking." % attacker
		# Later: abilities that let a creature block additional attackers (CR 509.1a).
		if blocking.has(blocker):
			return "Object %d cannot block more than one attacker." % blocker
		blocking[blocker] = true
	return ""


func describe() -> String:
	return "player %d: declare blockers from %s against %s" % [player_id, candidate_blocker_ids, attacker_ids]
