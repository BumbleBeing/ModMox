class_name ShuffleEvent
extends MmEvent
## A zone is randomized with the Game RNG (CR 701.24). Its objects stay the same objects.

var zone_kind: MmZone.Kind
var owner_id: int
## The card identities in their new order, set when the event is applied.
var card_ids_after: Array[int] = []


func _init(shuffled_zone: MmZone) -> void:
	zone_kind = shuffled_zone.kind
	owner_id = shuffled_zone.owner_id


func apply(state: MmGameState) -> void:
	var zone: MmZone = state.zone(zone_kind, owner_id)
	var order: Array[MmGameObject] = zone.objects()
	state.game_rng.shuffle_in_place(order)
	zone.reorder(order)
	card_ids_after.clear()
	for game_object: MmGameObject in order:
		card_ids_after.append(game_object.card_id)


func describe() -> String:
	return "SHUFFLE: %s" % MmZone.describe_zone(zone_kind, owner_id)
