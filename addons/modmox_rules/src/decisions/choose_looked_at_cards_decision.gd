class_name ChooseLookedAtCardsDecision
extends MmPendingDecision
## The controller of a resolving look at the top cards of their library chooses up to
## [member most] of the cards that match its Filter from among those cards (CR 701.20e), as
## Militia Bugler's "You may reveal a creature card with power 2 or less from among them and
## put it into your hand." Asked even when none matches: they still look. While it is
## pending, that player's Player View shows the cards looked at. Answer: an Array of distinct
## object IDs from [member candidate_ids], from none up to [member most] of them. With
## [member orders_rest], as Faerie Mechanist's "Put the rest on the bottom of your library in
## any order", it is [taken, rest]: those cards taken, then every other card looked at, each
## once, in the order they go to the bottom, the last the deepest. answer_taking() makes one.

var stack_object_id: int
## The object IDs of the cards looked at, top of the library first.
var card_ids: Array[int]
## The object IDs among them that may be taken, top first.
var candidate_ids: Array[int]
## The most cards that may be taken.
var most: int
## What may be taken, so that what is asked can be put in words. Card data, never changed.
var filter: MmFilter
## Whether the answer orders the rest on the bottom too, rather than leaving it to the Game RNG.
var orders_rest: bool = false


func _init(deciding_player_id: int, object_id: int, looked_at_ids: Array[int], matching_ids: Array[int], at_most: int,
		taken_from: MmFilter) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	card_ids = looked_at_ids.duplicate()
	candidate_ids = matching_ids.duplicate()
	most = at_most
	filter = taken_from


func validate(answer: Variant) -> String:
	var taken: Variant = answer
	if orders_rest:
		if not answer is Array or (answer as Array).size() != 2 or not (answer as Array)[0] is Array \
				or not (answer as Array)[1] is Array:
			return "Answer the cards taken and the rest in order: [taken, rest]."
		taken = (answer as Array)[0]
	var error: String = _check_distinct_ids(taken, ANY_COUNT, candidate_ids)
	if error != "":
		return error
	if (taken as Array).size() > most:
		return "Take at most %d, not %d." % [most, (taken as Array).size()]
	if not orders_rest:
		return ""
	var rest: Array[int] = []
	for id: int in card_ids:
		if not (taken as Array).has(id):
			rest.append(id)
	return _check_distinct_ids((answer as Array)[1], rest.size(), rest)


## The answer that takes [param taken] and, when the rest are ordered, puts them on the bottom
## in the order they were looked at.
func answer_taking(taken: Array[int]) -> Array:
	if not orders_rest:
		return taken.duplicate()
	var rest: Array[int] = []
	for id: int in card_ids:
		if not taken.has(id):
			rest.append(id)
	return [taken.duplicate(), rest]


func describe() -> String:
	return "player %d: take up to %d of %s for object %d (%d candidates)" % [player_id, most, card_ids,
		stack_object_id, candidate_ids.size()]
