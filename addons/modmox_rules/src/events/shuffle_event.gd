class_name ShuffleEvent
extends MmEvent
## A zone is randomized with the Game RNG (CR 701.24). Its objects stay the same objects.

var zone: MmZone
## The card identities in their new order, set when the event is applied.
var card_ids_after: Array[int] = []


func _init(shuffled_zone: MmZone) -> void:
	zone = shuffled_zone


func apply(state: MmGameState) -> void:
	var order: Array[MmGameObject] = zone.objects()
	state.game_rng.shuffle_in_place(order)
	zone.reorder(order)
	card_ids_after.clear()
	for game_object: MmGameObject in order:
		card_ids_after.append(game_object.card_id)


func describe() -> String:
	return "SHUFFLE: %s" % zone.describe()
