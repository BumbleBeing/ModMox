class_name PaymentPlan
extends RefCounted
## What Auto-tap (game glossary) would use to pay for one spell or ability: the sources it
## would tap and the mana it would spend from the pool. The Encounter Presenter works one
## out for each thing the Hero could cast or activate, and the Tap Preview is drawn from it.

## The Game Objects tapped for mana, in the order they are tapped.
var source_ids: Array[int] = []
## The mana spent from the pool, a type for each unit.
var pool_types: Array[MmMana.Type] = []


func is_empty() -> bool:
	return source_ids.is_empty() and pool_types.is_empty()


## How many payments it is: one for each source tapped and each unit spent.
func size() -> int:
	return source_ids.size() + pool_types.size()


## Whether Game Object [param object_id] is tapped for it.
func taps(object_id: int) -> bool:
	return source_ids.has(object_id)


## Whether pool mana of [param type] is spent on it.
func spends(type: MmMana.Type) -> bool:
	return pool_types.has(type)


func add_source(object_id: int) -> void:
	source_ids.append(object_id)


func add_pool(type: MmMana.Type) -> void:
	pool_types.append(type)


## Takes one tap of [param object_id] out of the plan, once it has been made.
func take_source(object_id: int) -> void:
	source_ids.erase(object_id)


## Takes one unit of [param type] out of the plan, once it has been spent.
func take_pool(type: MmMana.Type) -> void:
	pool_types.erase(type)


func copy() -> PaymentPlan:
	var made: PaymentPlan = PaymentPlan.new()
	made.source_ids = source_ids.duplicate()
	made.pool_types = pool_types.duplicate()
	return made
