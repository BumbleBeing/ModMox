class_name ChooseObjectDecision
extends MmPendingDecision
## The controller of a resolving spell or ability chooses the permanent for choice
## [member choice_index], "a [member filter]", as the effect that uses it begins
## (CR 608.2d). It is not a target. Answer: the index of the chosen entry in
## [member candidates], which lists permanents in ID order, or cards among those an earlier
## effect moved, such as the cards milled, in their order (engine ADR 0080).
## With the purpose EXILE_FROM_GRAVEYARD it is the card a cost said yes to exiles instead,
## "a creature card from your graveyard" (ExileFromGraveyardCost), among the cards of the
## payer's graveyard in their order, and it has no choice index.

## What the card is chosen for: a choice of a ChosenSelection, or a cost being paid.
enum Purpose { CHOOSE = 0, EXILE_FROM_GRAVEYARD = 1 }

## The choice index of a decision that is not for a ChosenSelection.
const NO_CHOICE_INDEX: int = -1

var stack_object_id: int
var choice_index: int
var purpose: Purpose = Purpose.CHOOSE
## What may be chosen, so that what is asked can be put in words. Card data, never changed.
var filter: MmFilter
var candidates: Array[MmReference]


func _init(deciding_player_id: int, object_id: int, index: int, chosen_from: MmFilter, legal: Array[MmReference]) -> void:
	super(deciding_player_id)
	stack_object_id = object_id
	choice_index = index
	filter = chosen_from
	candidates = legal.duplicate()


func validate(answer: Variant) -> String:
	return _check_choice(answer, candidates.size())


func describe() -> String:
	return "player %d: choose %d for object %d (%d candidates)" % [player_id, choice_index, stack_object_id, candidates.size()]
