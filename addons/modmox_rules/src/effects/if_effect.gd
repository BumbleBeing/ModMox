class_name IfEffect
extends MmEffect
## "If [condition], [effect]." (CR 608.2c): [member effect] happens only if the condition
## holds, checked once, as this effect begins on resolution, after the effects before it,
## as in Lion Sash's "Exile target card from a graveyard. If it was a permanent card, put a
## +1/+1 counter on this permanent." Otherwise nothing happens. Unlike a triggered
## ability's intervening "if" (CR 603.4), it never stops anything from triggering or
## resolving. With [member is_unless] it reads "[effect] unless [condition]" instead, as
## Splitskin Doll's "Then discard a card unless you control another creature with power 2 or
## less": [member effect] happens only if the condition does not hold. A decision of
## [member effect]'s own, such as which card to discard, is asked only when it will happen.
# Later: a choice made on resolution (a ChosenSelection) inside [member effect], once a card
# has one.

@export var condition: MmCondition
@export var effect: MmEffect
## "Unless": [member effect] happens only while [member condition] does not hold.
@export var is_unless: bool = false


## [member effect]'s own decision, when it is to happen.
func decision_as_it_begins(state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	return effect.decision_as_it_begins(state, context, stack_object_id) if _happens(state, context) else null


## 1 when [member effect] is to happen, then its own numbers (CR 608.2h); 0 alone when it is
## not.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	if not _happens(state, context):
		return [0] as Array[int]
	var worked_out: Array[int] = [1]
	worked_out.append_array(effect.numbers(state, context))
	return worked_out


## As numbers(), with [member effect]'s numbers worked out from [param answer] to its own
## decision.
func numbers_with_answer(state: MmGameState, context: MmEffectContext, answer: Variant) -> Array[int]:
	if not _happens(state, context):
		return [0] as Array[int]
	var worked_out: Array[int] = [1]
	worked_out.append_array(effect.numbers_with_answer(state, context, answer))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if worked_out.is_empty() or worked_out[0] != 1:
		return [] as Array[MmEvent]
	return effect.next_batch(state, context, step, worked_out.slice(1))


func selections() -> Array[MmSelection]:
	return effect.selections()


func adds_mana() -> bool:
	return effect.adds_mana()


## Whether [member effect] is to happen: the condition holds, or for "unless" it does not.
func _happens(state: MmGameState, context: MmEffectContext) -> bool:
	return condition.is_true(state, context) != is_unless
