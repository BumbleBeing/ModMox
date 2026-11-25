class_name MmEffectContext
extends RefCounted
## Who and what an effect is resolving for: the controller of the spell or ability, its
## source, its targets, for a triggered ability what triggered it, what was chosen and
## paid as it resolves, and for a mana ability the color chosen as it was activated.

## [member paid_x] when no X has been paid (ADR 0061).
const NONE_PAID: int = -1

var controller_id: int
## "This": a spell itself, or the permanent, Emblem or Potion an ability came from.
var source_object_id: int
## The spell or ability's own object on the stack, which can't be its own target (CR 115.5);
## 0 while it is not on the stack.
var own_object_id: int = 0
## The chosen targets of the target requirements, in order, a place for each target one may
## choose (ADR 0014). An entry is null when that target was illegal on resolution
## (CR 608.2b), or was never chosen by an "up to" requirement.
var targets: Array[MmReference] = []
## How many places of [member targets] each requirement takes, in order. Empty means one
## each, as in a context made by hand.
var target_counts: Array[int] = []
## What each target requirement an overload changed to "each" found as the spell began to
## resolve (CR 702.96b, ADR 0014), one after another in the requirements' order, fixed then
## so that every effect finds the same.
var overloaded: Array[MmReference] = []
## How many of [member overloaded] each overloaded requirement found, in order.
var overloaded_counts: Array[int] = []
## For a triggered ability: what its event was about ("that player", "that creature").
var triggering_player_id: int = -1
var triggering_object_id: int = 0
## What was chosen as the spell or ability resolved, by choice index (CR 608.2d). A choice
## with nothing to choose from is there as null.
var choices: Dictionary[int, MmReference] = {}
## The X paid for a "you may pay {X}" as the spell or ability resolved (ADR 0061), or
## NONE_PAID. Every effect after the payment reads it through PaidXValue.
var paid_x: int = NONE_PAID
## The color an "Add one mana of any color" adds: an MmMana.Type, chosen as its mana ability
## was activated (CR 605.3a, ADR 0072), or MmMana.NO_TYPE.
var chosen_mana_type: int = MmMana.NO_TYPE
## The new objects of the cards an earlier effect of this spell or ability moved and
## remembers, such as the cards milled: "them" (MovedCardsSelection, engine ADR 0080).
var moved_ids: Array[int] = []


func _init(controlling_player_id: int, source_id: int, chosen_targets: Array[MmReference] = [],
		trigger_player_id: int = -1, trigger_object_id: int = 0) -> void:
	controller_id = controlling_player_id
	source_object_id = source_id
	targets = chosen_targets.duplicate()
	triggering_player_id = trigger_player_id
	triggering_object_id = trigger_object_id


## The context of [param stack_object], a spell or ability on the stack, as its targets are
## chosen and as it resolves: the same "this" both times, so a target chosen as "another"
## is still legal on resolution.
## [param counts] is how many places each requirement takes, as in [member target_counts].
static func of_stack_object(stack_object: MmGameObject, chosen_targets: Array[MmReference] = [],
		counts: Array[int] = []) -> MmEffectContext:
	var source_id: int = stack_object.id if stack_object.is_card_or_copy() else stack_object.source_object_id
	var context: MmEffectContext = MmEffectContext.new(stack_object.controller_id, source_id, chosen_targets,
		stack_object.triggering_player_id, stack_object.triggering_object_id)
	context.own_object_id = stack_object.id
	context.target_counts = counts.duplicate()
	return context


## Every target of requirement [param requirement_index] that was chosen and is still legal,
## in the order chosen.
func targets_of(requirement_index: int) -> Array[MmReference]:
	var first: int = requirement_index
	var count: int = 1
	if not target_counts.is_empty():
		if requirement_index >= target_counts.size():
			return []
		first = 0
		for earlier: int in requirement_index:
			first += target_counts[earlier]
		count = target_counts[requirement_index]
	var found: Array[MmReference] = []
	for place: int in range(first, mini(first + count, targets.size())):
		if targets[place] != null:
			found.append(targets[place])
	return found


## What overloaded requirement [param overloaded_index] found as the spell began to resolve,
## in order, whether or not each is still where it was.
func overloaded_of(overloaded_index: int) -> Array[MmReference]:
	if overloaded_index >= overloaded_counts.size():
		return []
	var first: int = 0
	for earlier: int in overloaded_index:
		first += overloaded_counts[earlier]
	return overloaded.slice(first, first + overloaded_counts[overloaded_index])


## This context with [param found] as what its overloaded requirements found, [param counts]
## of them each, a new context as with_choice() makes.
func with_overloaded(found: Array[MmReference], counts: Array[int]) -> MmEffectContext:
	var copy: MmEffectContext = _copy()
	copy.overloaded = found.duplicate()
	copy.overloaded_counts = counts.duplicate()
	return copy


## This context with [param chosen] as choice [param index]. A context is never changed
## once made, so a resolving spell or ability takes a new one for each choice.
func with_choice(index: int, chosen: MmReference) -> MmEffectContext:
	var copy: MmEffectContext = _copy()
	copy.choices[index] = chosen
	return copy


## This context remembering [param ids] as "them" too, a new context as with_choice() makes.
func with_moved(ids: Array[int]) -> MmEffectContext:
	var copy: MmEffectContext = _copy()
	copy.moved_ids.append_array(ids)
	return copy


## This context with [param x] as the X paid (ADR 0061), a new context as with_choice()
## makes.
func with_paid_x(x: int) -> MmEffectContext:
	var copy: MmEffectContext = _copy()
	copy.paid_x = x
	return copy


## This context with [param type], an MmMana.Type or MmMana.NO_TYPE, as the color chosen
## for mana of any color (ADR 0072), a new context as with_choice() makes.
func with_chosen_mana_type(type: int) -> MmEffectContext:
	var copy: MmEffectContext = _copy()
	copy.chosen_mana_type = type
	return copy


## A new context holding everything this one does.
func _copy() -> MmEffectContext:
	var copy: MmEffectContext = MmEffectContext.new(controller_id, source_object_id, targets,
		triggering_player_id, triggering_object_id)
	copy.own_object_id = own_object_id
	copy.target_counts = target_counts.duplicate()
	copy.choices = choices.duplicate()
	copy.paid_x = paid_x
	copy.chosen_mana_type = chosen_mana_type
	copy.moved_ids = moved_ids.duplicate()
	copy.overloaded = overloaded.duplicate()
	copy.overloaded_counts = overloaded_counts.duplicate()
	return copy
