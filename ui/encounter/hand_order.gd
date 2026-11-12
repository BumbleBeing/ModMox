class_name HandOrder
extends RefCounted
## The Hand Order (game glossary): the order the Hero keeps their hand in. It is the
## screen's alone, kept outside the redrawn nodes; the engine's hand has an order of its own
## that no rule reads (A374). Cards are known by Card Identity, because a card that leaves
## the hand and comes back is a new Game Object (A379).
##
## A card new to the hand joins at the right end. A card that left keeps its place in case
## a rewind brings it back: a canceled cast or an undo puts it where it was. One that comes
## back any other way joins at the right end like a drawn card.

var _order: Array[int] = []
var _present: Dictionary[int, bool] = {}


## The hand now holds [param hand], Card Identities in any order. [param is_rewind] says the
## snapshot came from an undo or a canceled cast.
func update(hand: Array[int], is_rewind: bool) -> void:
	var now: Dictionary[int, bool] = {}
	for card_id: int in hand:
		now[card_id] = true
		if not _order.has(card_id):
			_order.append(card_id)
		elif not _present.has(card_id) and not is_rewind:
			_order.erase(card_id)
			_order.append(card_id)
	_present = now


## The cards in hand, in the Hero's order.
func cards() -> Array[int]:
	var found: Array[int] = []
	for card_id: int in _order:
		if _present.has(card_id):
			found.append(card_id)
	return found


## Where [param card_id] is among the cards in hand, or -1 if it is not there.
func place_of(card_id: int) -> int:
	return cards().find(card_id)


## Puts [param card_id] at [param index] among the other cards in hand: 0 is the left end,
## and anything past the last of them is the right end.
func place(card_id: int, index: int) -> void:
	if not _present.has(card_id):
		return
	_order.erase(card_id)
	var others: Array[int] = cards()
	if others.is_empty():
		_order.append(card_id)
	elif index >= others.size():
		_order.insert(_order.find(others.back()) + 1, card_id)
	else:
		_order.insert(_order.find(others[maxi(index, 0)]), card_id)
