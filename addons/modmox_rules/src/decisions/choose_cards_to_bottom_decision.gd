class_name ChooseCardsToBottomDecision
extends MmPendingDecision
## After keeping, a player puts [member count] cards from their hand on the bottom of their
## library in any order (CR 103.5). Answer: an Array of [member count] distinct object IDs
## from [member candidate_ids]. They go to the bottom one at a time in answer order, so the
## last ID in the answer ends up lowest.

var count: int
## The object IDs of the cards in the player's hand.
var candidate_ids: Array[int]


func _init(deciding_player_id: int, cards_to_bottom: int, hand_ids: Array[int]) -> void:
	super(deciding_player_id)
	count = cards_to_bottom
	candidate_ids = hand_ids.duplicate()


func validate(answer: Variant) -> String:
	return _check_distinct_ids(answer, count, candidate_ids)


func describe() -> String:
	return "player %d: choose %d cards to put on the bottom" % [player_id, count]
