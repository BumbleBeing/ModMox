class_name LibraryTopOrderedEvent
extends MmEvent
## Cards of a library are put on top of it in a chosen order, as a surveil puts back the
## cards it keeps (CR 701.25a, ADR 0068). They never leave the library, so they stay the
## same objects (ADR 0008 is about zone changes). Their owner saw them, so each becomes a
## Known Card to that player until the library is shuffled.

var owner_id: int
## The object IDs put on top, top first.
var ordered_ids: Array[int] = []


func _init(library_owner_id: int, top_first_ids: Array[int]) -> void:
	owner_id = library_owner_id
	ordered_ids = top_first_ids.duplicate()


func apply(state: MmGameState) -> void:
	var library: MmZone = state.player(owner_id).library
	var on_top: Array[MmGameObject] = []
	for id: int in ordered_ids:
		var card: MmGameObject = state.object(id)
		if card != null and card.zone() == library:
			on_top.append(card)
	var order: Array[MmGameObject] = on_top.duplicate()
	for card: MmGameObject in library.objects():
		if not on_top.has(card):
			order.append(card)
	library.reorder(order)
	for card: MmGameObject in on_top:
		card.make_known_to(owner_id)


func describe() -> String:
	return "TOP OF LIBRARY ORDERED: %s %s" % [MmZone.describe_zone(MmZone.Kind.LIBRARY, owner_id), ordered_ids]
