class_name LibraryBottomRandomizedEvent
extends MmEvent
## Cards of a library are put on the bottom of it in a random order, as Militia Bugler puts
## the rest of the cards it looked at (CR 401.4). The order comes from the Game RNG (ADR 0006)
## as the event is applied, and is recorded, so a replay puts them in the same order. They
## never leave the library, so they stay the same objects (ADR 0008 is about zone changes).
## Later: their owner knows which cards are at the bottom, if not their order, once
## something can use that.

var owner_id: int
## The object IDs put on the bottom, in the order they were named.
var card_ids: Array[int] = []
## The object IDs as they lie once applied, the lowest last.
var ordered_ids: Array[int] = []


func _init(library_owner_id: int, bottom_ids: Array[int]) -> void:
	owner_id = library_owner_id
	card_ids = bottom_ids.duplicate()


func apply(state: MmGameState) -> void:
	var library: MmZone = state.player(owner_id).library
	var to_bottom: Array[MmGameObject] = []
	for id: int in card_ids:
		var card: MmGameObject = state.object(id)
		if card != null and card.zone() == library:
			to_bottom.append(card)
	state.game_rng.shuffle_in_place(to_bottom)
	var order: Array[MmGameObject] = []
	for card: MmGameObject in library.objects():
		if not to_bottom.has(card):
			order.append(card)
	order.append_array(to_bottom)
	library.reorder(order)
	ordered_ids.clear()
	for card: MmGameObject in to_bottom:
		ordered_ids.append(card.id)


func describe() -> String:
	return "BOTTOM OF LIBRARY RANDOMIZED: %s %s" % [MmZone.describe_zone(MmZone.Kind.LIBRARY, owner_id), ordered_ids]
