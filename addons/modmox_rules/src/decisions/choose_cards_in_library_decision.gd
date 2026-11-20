class_name ChooseCardsInLibraryDecision
extends MmPendingDecision
## The controller of a resolving search looks through their library and finds up to
## [member most] of the cards that match its Filter (CR 701.23, ADR 0057). Asked even when
## nothing matches, though never when [member most] would be 0. While it is pending, that player's Player View shows their whole
## library. Answer: an Array of distinct object IDs from [member candidate_ids], from none
## up to [member most] of them (CR 701.23b: a search for a stated quality may find nothing).

var stack_object_id: int
## The object IDs of the cards in the library that may be found, in library order.
var candidate_ids: Array[int]
## The most cards that may be found.
var most: int
## Whether the search is for "up to" a number of cards, rather than for "a" card.
var is_up_to: bool
## What may be found, so that what is asked can be put in words. Card data, never changed.
var filter: MmFilter


func _init(deciding_player_id: int, object_id: int, matching_ids: Array[int], at_most: int, found_from: MmFilter,
		up_to: bool = false) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	candidate_ids = matching_ids.duplicate()
	most = at_most
	filter = found_from
	is_up_to = up_to


func validate(answer: Variant) -> String:
	var error: String = _check_distinct_ids(answer, ANY_COUNT, candidate_ids)
	if error != "":
		return error
	if (answer as Array).size() > most:
		return "Find at most %d, not %d." % [most, (answer as Array).size()]
	return ""


func describe() -> String:
	return "player %d: search for up to %d for object %d (%d candidates)" % [player_id, most, stack_object_id, candidate_ids.size()]
