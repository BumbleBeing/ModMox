class_name ChooseLookedAtCardsDecision
extends MmPendingDecision
## The controller of a resolving look at the top cards of their library chooses up to
## [member most] of the cards that match its Filter from among those cards (CR 701.20e), as
## Militia Bugler's "You may reveal a creature card with power 2 or less from among them and
## put it into your hand." Asked even when none matches: they still look. While it is
## pending, that player's Player View shows the cards looked at. Answer: an Array of distinct
## object IDs from [member candidate_ids], from none up to [member most] of them.

var stack_object_id: int
## The object IDs of the cards looked at, top of the library first.
var card_ids: Array[int]
## The object IDs among them that may be taken, top first.
var candidate_ids: Array[int]
## The most cards that may be taken.
var most: int
## What may be taken, so that what is asked can be put in words. Card data, never changed.
var filter: MmFilter


func _init(deciding_player_id: int, object_id: int, looked_at_ids: Array[int], matching_ids: Array[int], at_most: int,
		taken_from: MmFilter) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	card_ids = looked_at_ids.duplicate()
	candidate_ids = matching_ids.duplicate()
	most = at_most
	filter = taken_from


func validate(answer: Variant) -> String:
	var error: String = _check_distinct_ids(answer, ANY_COUNT, candidate_ids)
	if error != "":
		return error
	if (answer as Array).size() > most:
		return "Take at most %d, not %d." % [most, (answer as Array).size()]
	return ""


func describe() -> String:
	return "player %d: take up to %d of %s for object %d (%d candidates)" % [player_id, most, card_ids,
		stack_object_id, candidate_ids.size()]
