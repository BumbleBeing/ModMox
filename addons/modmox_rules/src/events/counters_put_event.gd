class_name CountersPutEvent
extends MmEvent
## Counters of one kind are put on a permanent (CR 122.6).

var object_id: int
var kind: MmCounter.Kind
var amount: int


func _init(permanent_id: int, counter_kind: MmCounter.Kind, counter_amount: int) -> void:
	object_id = permanent_id
	kind = counter_kind
	amount = counter_amount


func apply(state: MmGameState) -> void:
	state.object(object_id).put_counters(kind, amount)


func describe() -> String:
	return "COUNTERS PUT: %d %s on object %d" % [amount, MmCounter.label(kind), object_id]
