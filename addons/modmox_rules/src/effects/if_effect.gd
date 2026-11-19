class_name IfEffect
extends MmEffect
## "If [condition], [effect]." (CR 608.2c): [member effect] happens only if the condition
## holds, checked once, as this effect begins on resolution, after the effects before it,
## as in Lion Sash's "Exile target card from a graveyard. If it was a permanent card, put a
## +1/+1 counter on this permanent." Otherwise nothing happens. Unlike a triggered
## ability's intervening "if" (CR 603.4), it never stops anything from triggering or
## resolving.
# Later: a choice made on resolution (a ChosenSelection) or a decision of its own inside
# [member effect], once a card has one.

@export var condition: MmCondition
@export var effect: MmEffect


## 1 when the condition holds, then [member effect]'s own numbers (CR 608.2h); 0 alone
## when it does not.
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	if not condition.is_true(state, context):
		return [0] as Array[int]
	var worked_out: Array[int] = [1]
	worked_out.append_array(effect.numbers(state, context))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if worked_out.is_empty() or worked_out[0] != 1:
		return [] as Array[MmEvent]
	return effect.next_batch(state, context, step, worked_out.slice(1))


func selections() -> Array[MmSelection]:
	return effect.selections()


func adds_mana() -> bool:
	return effect.adds_mana()
