class_name InsteadEffect
extends MmEffect
## "[effect]. If [condition], [instead] instead." (CR 608.2c): one effect or the other,
## chosen by a condition checked once, as the effect begins on resolution. Unlike a
## triggered ability's intervening "if" (CR 603.4), it never stops anything from
## triggering or resolving.

@export var condition: MmCondition
## What happens while the condition does not hold.
@export var effect: MmEffect
## What happens instead while it does.
@export var instead: MmEffect


## Which effect happens, then that effect's own numbers (CR 608.2h). The first number is 1
## for [member instead] and 0 for [member effect].
func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var holds: bool = condition.is_true(state, context)
	var worked_out: Array[int] = [1 if holds else 0]
	worked_out.append_array((instead if holds else effect).numbers(state, context))
	return worked_out


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	var chosen: MmEffect = instead if worked_out[0] == 1 else effect
	return chosen.next_batch(state, context, step, worked_out.slice(1))


## Both effects' Selections: either may target, so both count for what the ability
## targets.
# Later: a choice made on resolution (a ChosenSelection) is asked even when its effect is
# not the one that happens, once a card has one in either effect.
func selections() -> Array[MmSelection]:
	var all: Array[MmSelection] = effect.selections()
	all.append_array(instead.selections())
	return all


func adds_mana() -> bool:
	return effect.adds_mana() or instead.adds_mana()
