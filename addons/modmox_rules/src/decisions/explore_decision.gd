class_name ExploreDecision
extends SurveilDecision
## The controller of an exploring permanent chooses whether to put the nonland card it
## revealed into their graveyard or keep it on top of their library (CR 701.44a, engine ADR
## 0090). It is a SurveilDecision of that one card, so it is shown, made an undo barrier and
## answered as a surveil is. Answer: [graveyarded, kept], one of the two holding the card.


func _init(deciding_player_id: int, object_id: int, looked_at_ids: Array[int]) -> void:
	super(deciding_player_id, object_id, looked_at_ids)


func describe() -> String:
	return "player %d: explore %s for object %d" % [player_id, card_ids, stack_object_id]
