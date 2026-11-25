class_name CountersPutEvent
extends MmEvent
## Counters of one kind are put on a permanent by a player (CR 122.6).

var object_id: int
var kind: MmCounter.Kind
var amount: int
## The player who puts them: the controller of the spell or ability whose effect puts them
## (CR 122.6), as "Whenever you put one or more +1/+1 counters" asks.
var putting_player_id: int


func _init(permanent_id: int, counter_kind: MmCounter.Kind, counter_amount: int, putting_player: int) -> void:
	object_id = permanent_id
	kind = counter_kind
	amount = counter_amount
	putting_player_id = putting_player


func apply(state: MmGameState) -> void:
	state.object(object_id).put_counters(kind, amount)


func describe() -> String:
	return "COUNTERS PUT: %d %s on object %d by player %d" % [amount, MmCounter.label(kind), object_id, putting_player_id]
