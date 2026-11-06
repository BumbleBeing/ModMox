class_name ChooseCardsToDiscardDecision
extends MmPendingDecision
## A player discards [member count] cards of their choice from their hand, such as when
## discarding down to maximum hand size (CR 514.1). Answer: an Array of [member count]
## distinct object IDs from [member candidate_ids].

var count: int
## The object IDs of the cards that may be discarded.
var candidate_ids: Array[int]


func _init(deciding_player_id: int, cards_to_discard: int, hand_ids: Array[int]) -> void:
	super(deciding_player_id)
	count = cards_to_discard
	candidate_ids = hand_ids.duplicate()


func validate(answer: Variant) -> String:
	return _check_distinct_ids(answer, count, candidate_ids)


func describe() -> String:
	return "player %d: choose %d cards to discard" % [player_id, count]
