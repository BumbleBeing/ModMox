class_name ScryDecision
extends SurveilDecision
## The controller of a resolving scry looks at the top cards of their library and puts any
## number of them on the bottom of it in any order and the rest back on top in any order
## (CR 701.22a, ADR 0087). It is a SurveilDecision whose first list goes to the bottom
## instead of the graveyard, so it is shown, revealed, made an undo barrier and answered as
## a surveil is. Answer: [bottom, kept]: the cards put on the bottom in the order they go,
## each under everything, so the last is the deepest, then the cards kept, top first.


func _init(deciding_player_id: int, object_id: int, looked_at_ids: Array[int]) -> void:
	super(deciding_player_id, object_id, looked_at_ids)


func describe() -> String:
	return "player %d: scry %s for object %d" % [player_id, card_ids, stack_object_id]


func _sent_words() -> String:
	return "put on the bottom"
