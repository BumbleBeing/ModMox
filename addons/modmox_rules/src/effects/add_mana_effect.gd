class_name AddManaEffect
extends MmEffect
## "Add [amount] mana of [type]" to the controller's mana pool (CR 106.3), or "Add one mana
## of any color", whose color is chosen as its ability is activated (ADR 0072).

@export var mana_type: MmMana.Type = MmMana.Type.COLORLESS
@export var amount: MmValue
## "Of any color" (CR 106.1a), as a Treasure's "Add one mana of any color": the color is the
## one chosen as the ability was activated, carried on the effect context, and
## [member mana_type] is not read. A mana ability resolves at once (CR 605.3a), so fixing
## the color as it is activated is choosing it as it resolves.
@export var is_any_color: bool = false


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(_state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if step > 0 or worked_out[0] <= 0:
		return []
	var type: int = type_added(context)
	# Later: a spell, or an ability that uses the stack, that adds mana of any color asks
	# its color as it resolves, with a decision of its own (ADR 0072).
	assert(type != MmMana.NO_TYPE, "Mana of any color resolved with no color chosen.")
	return [ManaAddedEvent.new(context.controller_id, type as MmMana.Type, worked_out[0], context.source_object_id)]


## The type of mana this effect adds in [param context]: [member mana_type], or for mana of
## any color the color chosen as its ability was activated, which is MmMana.NO_TYPE when
## none was.
func type_added(context: MmEffectContext) -> int:
	return context.chosen_mana_type if is_any_color else mana_type


## Every type of mana this effect could add: the five colors in WUBRG order for mana of any
## color, otherwise its one type.
func possible_types() -> Array[MmMana.Type]:
	if is_any_color:
		return MmMana.COLORS.duplicate()
	var only: Array[MmMana.Type] = [mana_type]
	return only


func adds_mana() -> bool:
	return true
