class_name CountersRemovedEvent
extends MmEvent
## Counters of one kind are removed from a permanent, as when +1/+1 and -1/-1 counters
## cancel each other (CR 704.5q).

var object_id: int
var kind: MmCounter.Kind
var amount: int


func _init(permanent_id: int, counter_kind: MmCounter.Kind, counter_amount: int) -> void:
	object_id = permanent_id
	kind = counter_kind
	amount = counter_amount


func apply(state: MmGameState) -> void:
	state.object(object_id).remove_counters(kind, amount)


func describe() -> String:
	return "COUNTERS REMOVED: %d %s from object %d" % [amount, MmCounter.label(kind), object_id]
