class_name InfoPrompt
extends RefCounted
## What the Info Panel (game glossary) says for one Pending Decision: one line asking the
## Hero for what is wanted, what is still owed while paying, and whether the decision is a
## step of a cast that can be canceled.

var text: String = ""
## While paying: what is still owed. Null otherwise.
var owed: MmManaCost = null
var can_cancel: bool = false


## The prompt for [param decision] as the player whose [param view] this is reads it. A
## null decision (nobody is asking them anything) has no text.
static func of(decision: MmPendingDecision, view: MmPlayerView) -> InfoPrompt:
	var prompt: InfoPrompt = InfoPrompt.new()
	if decision == null:
		return prompt
	if decision is PriorityDecision:
		var whose: String = "your turn" if view.active_player_id == view.viewer_id else "the Villain's turn"
		var step: String = PlayerPanel.STEP_NAMES[view.step] if view.step >= 0 else ""
		prompt.text = "Your priority\n%s, %s" % [step, whose] if step != "" else "Your priority"
	elif decision is PayManaDecision:
		var pay: PayManaDecision = decision as PayManaDecision
		prompt.text = "Pay for %s" % stack_name(view, view.stack.back().id if not view.stack.is_empty() else -1)
		prompt.owed = MmManaCost.new()
		prompt.owed.generic = pay.remaining_generic
		prompt.owed.symbols = pay.remaining_symbols.duplicate()
		prompt.can_cancel = true
	elif decision is ChooseTargetDecision:
		prompt.text = "Choose a target for %s" % stack_name(view, (decision as ChooseTargetDecision).stack_object_id)
		prompt.can_cancel = true
	else:
		# A kind the Debug Decision Panel still answers says what its form does.
		prompt.text = DebugDecisionForm.of(decision, view).title
	return prompt


## What the spell or ability [param stack_object_id] is called: a spell's name, or "X's
## ability" after an ability's source.
static func stack_name(view: MmPlayerView, stack_object_id: int) -> String:
	for item: MmObjectView in view.stack:
		if item.id != stack_object_id:
			continue
		if item.card_id != MmGameObject.NO_CARD:
			return item.name
		var source: String = DebugDecisionForm.name_of(view, item.source_object_id)
		return item.name if source.begins_with("object ") else "%s's ability" % source
	return "this"
