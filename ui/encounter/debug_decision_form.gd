class_name DebugDecisionForm
extends RefCounted
## What the Debug Decision Panel (game glossary) shows for one Pending Decision, and the
## answer each way of filling it in gives. Five generic forms cover the decision kinds that
## have no input of their own yet (A243): pick one, pick some, pair up, put in order and
## split a number. Paying mana and choosing a target have their own inputs and no form
## (13c); at priority only casting and playing a land are left, until the hand takes them
## (13e).

enum Kind { PICK_ONE, PICK_SOME, PAIR_UP, ORDER, SPLIT }

## Stands for "no Game Object" in option_object_ids, and for "blocks nothing" in a pairing.
const NONE: int = -1

var kind: Kind = Kind.PICK_ONE
var title: String = ""
## One label for each thing that can be picked, paired, ordered or given a share.
var options: Array[String] = []
## The Game Object each option is about, so hovering it can mark that object; NONE for none.
var option_object_ids: Array[int] = []
## PICK_SOME: how many must be picked, or NONE for any number.
var count: int = NONE
## PAIR_UP: for each option (a blocker), the attackers it may block and a label for each.
var pair_choice_ids: Array = []
var pair_choice_labels: Array = []
## SPLIT: the number to split, and for each option how much is lethal to it (NONE if none).
var amount: int = 0
var lethal_amounts: Array[int] = []
var _decision: MmPendingDecision
## PICK_SOME: what each option contributes to the answer (a Game Object ID).
var _values: Array[int] = []
## PICK_ONE at priority: the answer each option gives, since the list leaves actions out.
var _pick_answers: Array[int] = []


## Whether [param decision] is of a kind this panel still answers.
static func covers(decision: MmPendingDecision) -> bool:
	return decision != null and not (decision is PayManaDecision) and not (decision is ChooseTargetDecision)


## The form for [param decision], labeled from the deciding player's [param view], or null
## for a kind that has its own input.
static func of(decision: MmPendingDecision, view: MmPlayerView) -> DebugDecisionForm:
	if not covers(decision):
		return null
	var form: DebugDecisionForm = DebugDecisionForm.new()
	form._decision = decision
	if decision is PriorityDecision:
		form.title = "Priority: choose an action"
		var actions: Array[MmAction] = (decision as PriorityDecision).actions
		for index: int in actions.size():
			if actions[index] is CastSpellAction or actions[index] is PlayLandAction:
				form._add(_action_label(actions[index], view), DecisionClicks.object_of(actions[index]))
				form._pick_answers.append(index)
	elif decision is ChooseReplacementEffectDecision:
		form.title = "Which effect applies first?"
		for option: ActiveReplacementEffect in (decision as ChooseReplacementEffectDecision).options:
			form._add(option.describe(), NONE)
	elif decision is KeepOrMulliganDecision:
		var keep: KeepOrMulliganDecision = decision as KeepOrMulliganDecision
		form.title = "Keep this hand, or mulligan? (%d taken)" % keep.mulligans_taken
		form._add("Keep %d" % (view.hand.size() - keep.cards_to_bottom_if_kept), NONE)
		form._add("Mulligan", NONE)
	elif decision is ChoosePlayOrDrawDecision:
		form.title = "Play first, or draw?"
		form._add("Play first", NONE)
		form._add("Draw", NONE)
	elif decision is DeclareAttackersDecision:
		form.kind = Kind.PICK_SOME
		form.title = "Declare attackers (any number)"
		form._add_cards(view, (decision as DeclareAttackersDecision).candidate_ids)
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
	elif decision is OrderTriggersDecision:
		var order: OrderTriggersDecision = decision as OrderTriggersDecision
		form.kind = Kind.ORDER
		form.title = "Order your triggers: pick the one to put on the stack first"
		for index: int in order.descriptions.size():
			form._add(order.descriptions[index], order.source_object_ids[index])
	elif decision is DeclareBlockersDecision:
		var blocks: DeclareBlockersDecision = decision as DeclareBlockersDecision
		form.kind = Kind.PAIR_UP
		form.title = "Declare blockers"
		for blocker_id: int in blocks.candidate_blocker_ids:
			form._add(name_of(view, blocker_id), blocker_id)
			var attacker_ids: Array[int] = []
			var labels: Array[String] = []
			var blockable: Array = blocks.blockable_by_blocker.get(blocker_id, [])
			for attacker_id: int in blockable:
				attacker_ids.append(attacker_id)
				labels.append("%s (#%d)" % [name_of(view, attacker_id), attacker_id])
			form.pair_choice_ids.append(attacker_ids)
			form.pair_choice_labels.append(labels)
	elif decision is DivideCombatDamageDecision:
		var divide: DivideCombatDamageDecision = decision as DivideCombatDamageDecision
		form.kind = Kind.SPLIT
		form.amount = divide.amount
		form.title = "Divide %d damage from %s" % [divide.amount, name_of(view, divide.source_id)]
		for index: int in divide.recipients.size():
			var recipient: MmReference = divide.recipients[index]
			form._add(_reference_label(view, recipient), recipient.id if recipient.is_object() else NONE)
			form.lethal_amounts.append(divide.lethal_amounts[index] if index < divide.lethal_amounts.size() else NONE)
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


## Whether the form has nothing to pick from, as at priority with no spell to cast and no
## land to play.
func is_empty() -> bool:
	return options.is_empty()


## PICK_ONE: the answer for picking option [param index].
func answer_for_pick(index: int) -> Variant:
	return _pick_answers[index] if not _pick_answers.is_empty() else index


## PICK_SOME and ORDER: the answer for picking the options at [param indexes], in that
## order. Cards go to the bottom in the order picked, and the first trigger picked goes on
## the stack first.
func answer_for_picks(indexes: Array[int]) -> Variant:
	if kind == Kind.ORDER:
		var order: Array = []
		order.append_array(indexes)
		return order
	var ids: Array[int] = []
	for index: int in indexes:
		ids.append(_values[index])
	return ids


## PAIR_UP: the answer when each option (a blocker) blocks the attackers listed for it in
## [param attackers_by_option], one Array of attacker IDs for each option.
func answer_for_pairs(attackers_by_option: Array) -> Variant:
	var pairs: Array = []
	for index: int in attackers_by_option.size():
		var attacker_ids: Array = attackers_by_option[index]
		for attacker_id: int in attacker_ids:
			pairs.append([option_object_ids[index], attacker_id])
	return pairs


## SPLIT: the answer for giving each option the share listed for it in [param shares].
func answer_for_split(shares: Array[int]) -> Variant:
	return shares.duplicate()


func _add(label: String, object_id: int) -> void:
	options.append(label)
	option_object_ids.append(object_id)


func _add_cards(view: MmPlayerView, ids: Array[int]) -> void:
	for id: int in ids:
		_add("%s (#%d)" % [name_of(view, id), id], id)
		_values.append(id)


static func _reference_label(view: MmPlayerView, reference: MmReference) -> String:
	if reference.is_player():
		return "You" if reference.id == view.viewer_id else "The other player"
	return name_of(view, reference.id)


static func _action_label(action: MmAction, view: MmPlayerView) -> String:
	if action is PlayLandAction:
		return "Play %s" % name_of(view, (action as PlayLandAction).object_id)
	if action is CastSpellAction:
		return "Cast %s" % name_of(view, (action as CastSpellAction).object_id)
	return action.describe()
