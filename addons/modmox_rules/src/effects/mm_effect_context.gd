class_name MmEffectContext
extends RefCounted
## Who and what an effect is resolving for: the controller of the spell or ability, its
## source, its targets, and for a triggered ability what triggered it.

var controller_id: int
## "This": a spell itself, or the permanent, Emblem or Potion an ability came from.
var source_object_id: int
## The spell or ability's own object on the stack, which can't be its own target (CR 115.5);
## 0 while it is not on the stack.
var own_object_id: int = 0
## The chosen target of each target requirement, in order. An entry is null when that
## target was illegal on resolution (CR 608.2b).
var targets: Array[MmReference] = []
## For a triggered ability: what its event was about ("that player", "that creature").
var triggering_player_id: int = -1
var triggering_object_id: int = 0
## What was chosen as the spell or ability resolved, by choice index (CR 608.2d). A choice
## with nothing to choose from is there as null.
var choices: Dictionary[int, MmReference] = {}


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
static func of_stack_object(stack_object: MmGameObject, chosen_targets: Array[MmReference] = []) -> MmEffectContext:
	var source_id: int = stack_object.id if stack_object.is_card() else stack_object.source_object_id
	var context: MmEffectContext = MmEffectContext.new(stack_object.controller_id, source_id, chosen_targets,
		stack_object.triggering_player_id, stack_object.triggering_object_id)
	context.own_object_id = stack_object.id
	return context


## This context with [param chosen] as choice [param index]. A context is never changed
## once made, so a resolving spell or ability takes a new one for each choice.
func with_choice(index: int, chosen: MmReference) -> MmEffectContext:
	var copy: MmEffectContext = MmEffectContext.new(controller_id, source_object_id, targets,
		triggering_player_id, triggering_object_id)
	copy.own_object_id = own_object_id
	copy.choices = choices.duplicate()
	copy.choices[index] = chosen
	return copy
