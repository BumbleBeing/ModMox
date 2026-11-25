class_name CardRevealedEvent
extends MmEvent
## A card is revealed where it is (CR 701.20a), as explore reveals the top card of a library
## (CR 701.44a): every player knows it from then on, until it leaves the zone or its library
## is shuffled (engine ADR 0057).

var object_id: int


func _init(card_id: int) -> void:
	object_id = card_id


func apply(state: MmGameState) -> void:
	for player: MmPlayer in state.players:
		state.object(object_id).make_known_to(player.id)


func describe() -> String:
	return "REVEALED: object %d" % object_id
