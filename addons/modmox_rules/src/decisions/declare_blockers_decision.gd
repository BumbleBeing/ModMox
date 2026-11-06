class_name DeclareBlockersDecision
extends MmPendingDecision
## The defending player chooses which of their creatures block, and which attacker each
## blocks (CR 509.1a). Answer: an Array of [blocker ID, attacker ID] pairs, with blockers
## from [member candidate_blocker_ids] and attackers from [member attacker_ids]. Several
## blockers may block one attacker. Each blocker blocks only attackers it legally can (such
## as flyers only with flying or reach), each at most once, and at most as many as it may
## (one, plus any from BlockAdditionalAbility). An empty Array declares no blockers
## (ADR 0016).

## The creatures that may block, in ID order.
var candidate_blocker_ids: Array[int]
## The attacking creatures, in ID order.
var attacker_ids: Array[int]
## For each candidate blocker, the attackers it can block, in ID order.
var blockable_by_blocker: Dictionary[int, Array]
## For each candidate blocker, how many attackers it may block.
var most_blocks_by_blocker: Dictionary[int, int]


func _init(deciding_player_id: int, blocker_candidate_ids: Array[int], attacking_ids: Array[int],
		blockable: Dictionary[int, Array], most_blocks: Dictionary[int, int]) -> void:
	super(deciding_player_id)
	candidate_blocker_ids = blocker_candidate_ids.duplicate()
	attacker_ids = attacking_ids.duplicate()
	blockable_by_blocker = blockable.duplicate(true)
	most_blocks_by_blocker = most_blocks.duplicate()


func validate(answer: Variant) -> String:
	if typeof(answer) != TYPE_ARRAY:
		return "Expected a list of [blocker, attacker] pairs, got %s." % type_string(typeof(answer))
	var blocking: Dictionary[int, Array] = {}
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
		if not blockable_by_blocker[blocker].has(attacker):
			return "Object %d cannot block object %d." % [blocker, attacker]
		var already: Array = blocking.get(blocker, [])
		if already.has(attacker):
			return "Object %d already blocks object %d." % [blocker, attacker]
		if already.size() >= most_blocks_by_blocker[blocker]:
			return "Object %d cannot block more than %d attackers." % [blocker, most_blocks_by_blocker[blocker]]
		already.append(attacker)
		blocking[blocker] = already
	return ""


func describe() -> String:
	return "player %d: declare blockers from %s against %s" % [player_id, candidate_blocker_ids, attacker_ids]
