class_name LibraryBottomOrderedEvent
extends MmEvent
## Cards of a library are put on the bottom of it, one after another, as a scry puts the
## cards it sends there (CR 701.22a, ADR 0087): each goes under everything, so the last is
## the deepest. They never leave the library, so they stay the same objects (ADR 0008 is
## about zone changes). Their owner saw them, so each becomes a Known Card to that player
## until the library is shuffled.

var owner_id: int
## The object IDs put on the bottom, in the order they go, the last the deepest.
var ordered_ids: Array[int] = []


func _init(library_owner_id: int, in_order_ids: Array[int]) -> void:
	owner_id = library_owner_id
	ordered_ids = in_order_ids.duplicate()


func apply(state: MmGameState) -> void:
	var library: MmZone = state.player(owner_id).library
	var on_bottom: Array[MmGameObject] = []
	for id: int in ordered_ids:
		var card: MmGameObject = state.object(id)
		if card != null and card.zone() == library:
			on_bottom.append(card)
	var order: Array[MmGameObject] = []
	for card: MmGameObject in library.objects():
		if not on_bottom.has(card):
			order.append(card)
	order.append_array(on_bottom)
	library.reorder(order)
	for card: MmGameObject in on_bottom:
		card.make_known_to(owner_id)


func describe() -> String:
	return "BOTTOM OF LIBRARY ORDERED: %s %s" % [MmZone.describe_zone(MmZone.Kind.LIBRARY, owner_id), ordered_ids]
