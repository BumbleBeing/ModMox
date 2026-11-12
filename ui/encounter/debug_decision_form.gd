class_name DebugDecisionForm
extends RefCounted
## What the Debug Decision Panel (game glossary) shows for one Pending Decision, and the
## answer each way of filling it in gives. Two generic forms cover the decision kinds that
## have no input of their own yet (A243): pick one and pick some. Paying mana, choosing a
## target, declaring attackers and blockers and dividing combat damage have their own
## inputs and no form (13c), and so do ordering triggers and choosing between replacement
## effects (13d). Nothing at priority is answered here since the hand took casting and
## playing a land (13e-1).

enum Kind { PICK_ONE, PICK_SOME }

## Stands for "no Game Object" in option_object_ids, and for "any number" in count.
const NONE: int = -1

var kind: Kind = Kind.PICK_ONE
var title: String = ""
## One label for each thing that can be picked.
var options: Array[String] = []
## The Game Object each option is about, so hovering it can mark that object; NONE for none.
var option_object_ids: Array[int] = []
## PICK_SOME: how many must be picked, or NONE for any number.
var count: int = NONE

var _decision: MmPendingDecision
## PICK_SOME: what each option contributes to the answer (a Game Object ID).
var _values: Array[int] = []


## Whether [param decision] is of a kind this panel still answers.
static func covers(decision: MmPendingDecision) -> bool:
	return decision != null and not (decision is PriorityDecision) \
		and not (decision is PayManaDecision) and not (decision is ChooseTargetDecision) \
		and not CombatSelection.covers(decision) and not TriggerOrder.covers(decision) \
		and not (decision is ChooseReplacementEffectDecision)


## The form for [param decision], labeled from the deciding player's [param view], or null
## for a kind that has its own input.
static func of(decision: MmPendingDecision, view: MmPlayerView) -> DebugDecisionForm:
	if not covers(decision):
		return null
	var form: DebugDecisionForm = DebugDecisionForm.new()
	form._decision = decision
	if decision is KeepOrMulliganDecision:
		var keep: KeepOrMulliganDecision = decision as KeepOrMulliganDecision
		form.title = "Keep this hand, or mulligan? (%d taken)" % keep.mulligans_taken
		form._add("Keep %d" % (view.hand.size() - keep.cards_to_bottom_if_kept), NONE)
		form._add("Mulligan", NONE)
	elif decision is ChoosePlayOrDrawDecision:
		form.title = "Play first, or draw?"
		form._add("Play first", NONE)
		form._add("Draw", NONE)
	elif decision is ChooseCardsToDiscardDecision:
		var discard: ChooseCardsToDiscardDecision = decision as ChooseCardsToDiscardDecision
		form.kind = Kind.PICK_SOME
		form.count = discard.count
		form.title = "Discard %d" % discard.count
		form._add_cards(view, discard.candidate_ids)
	elif decision is ChooseCardsToBottomDecision:
		var bottom: ChooseCardsToBottomDecision = decision as ChooseCardsToBottomDecision
		form.kind = Kind.PICK_SOME
		form.count = bottom.count
		form.title = "Put %d on the bottom, in the order picked" % bottom.count
		form._add_cards(view, bottom.candidate_ids)
	else:
		form.title = decision.describe()
	return form


## The name of Game Object [param object_id] wherever [param view] shows it.
static func name_of(view: MmPlayerView, object_id: int) -> String:
	var all: Array[MmObjectView] = []
	all.append_array(view.battlefield)
	all.append_array(view.hand)
	all.append_array(view.stack)
	all.append_array(view.command)
	for player_id: int in view.graveyards:
		all.append_array(view.graveyards[player_id])
	for player_id: int in view.exiles:
		all.append_array(view.exiles[player_id])
	for seen: MmObjectView in all:
		if seen.id == object_id:
			return seen.name
	return "object %d" % object_id


## PICK_ONE: the answer for picking option [param index].
func answer_for_pick(index: int) -> Variant:
	return index


## PICK_SOME: the answer for picking the options at [param indexes], in that order. Cards
## go to the bottom in the order picked.
func answer_for_picks(indexes: Array[int]) -> Variant:
	var ids: Array[int] = []
	for index: int in indexes:
		ids.append(_values[index])
	return ids


func _add(label: String, object_id: int) -> void:
	options.append(label)
	option_object_ids.append(object_id)


func _add_cards(view: MmPlayerView, ids: Array[int]) -> void:
	for id: int in ids:
		_add("%s (#%d)" % [name_of(view, id), id], id)
		_values.append(id)
