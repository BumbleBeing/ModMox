class_name AddManaEffect
extends MmEffect
## "Add [amount] mana of [type]" to the controller's mana pool (CR 106.3), "Add one mana of
## any color", or "Add {U}, {B}, or {R}", whose color is chosen as its ability is activated
## (ADR 0072).

@export var mana_type: MmMana.Type = MmMana.Type.COLORLESS
@export var amount: MmValue
## "Of any color" (CR 106.1a), as a Treasure's "Add one mana of any color": the color is the
## one chosen as the ability was activated, carried on the effect context, and
## [member mana_type] is not read. A mana ability resolves at once (CR 605.3a), so fixing
## the color as it is activated is choosing it as it resolves.
@export var is_any_color: bool = false
## "Add {U}, {B}, or {R}", as on Crumbling Necropolis: the color is one of these, in the
## order printed, chosen as the ability was activated as mana of any color's is (ADR 0072),
## and [member mana_type] is not read. Empty for every other mana.
@export var color_choices: Array[MmMana.Type] = []


func numbers(state: MmGameState, context: MmEffectContext) -> Array[int]:
	var worked_out: Array[int] = [amount.evaluate(state, context)]
	return worked_out


func next_batch(_state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if step > 0 or worked_out[0] <= 0:
		return []
	var type: int = type_added(context)
	# Later: a spell, or an ability that uses the stack, that adds mana of a chosen color
	# asks its color as it resolves, with a decision of its own (ADR 0072).
	assert(type != MmMana.NO_TYPE, "Mana of a chosen color resolved with no color chosen.")
	return [ManaAddedEvent.new(context.controller_id, type as MmMana.Type, worked_out[0], context.source_object_id)]


## The colors its color is chosen among, in WUBRG order: all five for mana of any color,
## [member color_choices] for mana of one of some colors, and none when its type is fixed.
func colors_to_choose() -> Array[MmMana.Type]:
	if is_any_color:
		return MmMana.COLORS.duplicate()
	var colors: Array[MmMana.Type] = []
	for color: MmMana.Type in MmMana.COLORS:
		if color_choices.has(color):
			colors.append(color)
	return colors


## The type of mana this effect adds in [param context]: [member mana_type], or for mana of
## a chosen color the color chosen as its ability was activated, which is MmMana.NO_TYPE
## when none was or it is not one of [method colors_to_choose].
func type_added(context: MmEffectContext) -> int:
	var colors: Array[MmMana.Type] = colors_to_choose()
	if colors.is_empty():
		return mana_type
	return context.chosen_mana_type if colors.has(context.chosen_mana_type) else MmMana.NO_TYPE


## Every type of mana this effect could add: [method colors_to_choose] for mana of a chosen
## color, otherwise its one type.
func possible_types() -> Array[MmMana.Type]:
	var colors: Array[MmMana.Type] = colors_to_choose()
	if not colors.is_empty():
		return colors
	var only: Array[MmMana.Type] = [mana_type]
	return only


func adds_mana() -> bool:
	return true
