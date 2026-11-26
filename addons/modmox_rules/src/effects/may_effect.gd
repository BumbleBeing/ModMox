class_name MayEffect
extends MmEffect
## "You may [effect]." (CR 603.5, 608.2d): as it begins on resolution, its controller is
## asked a ChooseYesOrNoDecision, and [member effect] happens only on yes. The spell or
## ability is put on the stack and its targets chosen whatever they mean to answer
## (CR 603.3d), and saying no is not failing to resolve.
# Later: the decision [member effect] asks of its own as it begins, such as a search's
# ("you may search your library"); a choice made on resolution (a ChosenSelection) inside
# [member effect], which should be asked only after yes ("you may sacrifice a creature");
# "If you do" and "If you don't"; and not asking when every target of [member effect] has
# become illegal but the ability still resolves for another. Each once a card needs it.

## What happens on yes.
@export var effect: MmEffect


func decision_as_it_begins(_state: MmGameState, context: MmEffectContext, stack_object_id: int) -> MmPendingDecision:
	return ChooseYesOrNoDecision.new(context.controller_id, stack_object_id, effect)


## The first number is 1 on yes and 0 on no; on yes [member effect]'s own numbers follow
## (CR 608.2h).
func numbers_with_answer(state: MmGameState, context: MmEffectContext, answer: Variant) -> Array[int]:
	assert(effect.decision_as_it_begins(state, context, context.own_object_id) == null,
		"A \"you may\" cannot yet wrap an effect that asks a decision of its own.")
	if answer as int != ChooseYesOrNoDecision.Choice.YES:
		return [0]
	var worked_out: Array[int] = [1]
	worked_out.append_array(effect.numbers(state, context))
	return worked_out


## Only ever worked out with an answer: nothing that cannot stop for a decision, such as a
## mana ability (CR 605.3a), may hold a "you may".
func numbers(_state: MmGameState, _context: MmEffectContext) -> Array[int]:
	assert(false, "A \"you may\" is answered before its numbers are worked out.")
	return [0]


func next_batch(state: MmGameState, context: MmEffectContext, step: int, worked_out: Array[int]) -> Array[MmEvent]:
	if worked_out.is_empty() or worked_out[0] != 1:
		return []
	return effect.next_batch(state, context, step, worked_out.slice(1))


## The card [member effect] has cast on yes, and none on no (engine ADR 0104).
func card_to_cast(state: MmGameState, context: MmEffectContext, worked_out: Array[int]) -> MmGameObject:
	if worked_out.is_empty() or worked_out[0] != 1:
		return null
	return effect.card_to_cast(state, context, worked_out.slice(1))


func exiles_cast_instead_of_graveyard() -> bool:
	return effect.exiles_cast_instead_of_graveyard()


## [member effect]'s Selections, so what it targets is what the ability targets.
func selections() -> Array[MmSelection]:
	return effect.selections()


func adds_mana() -> bool:
	return effect.adds_mana()
