class_name InfoPrompt
extends RefCounted
## What the Info Panel (game glossary) says for one Pending Decision: one line asking the
## Hero for what is wanted, what is still owed while paying, and whether the decision is a
## step of a cast that can be canceled. While Auto-tap pays for the Hero it says what is being
## paid for instead, with what is still owed, and the cast can still be canceled.

var text: String = ""
## While paying: what is still owed. Null otherwise.
var owed: MmManaCost = null
var can_cancel: bool = false
## While declaring attackers: the panel offers "Declare All" (A311).
var offers_all_attack: bool = false


## What the panel says while a card is held where letting go would play it, from the
## option's text: "Cast Hill Giant" becomes "Release to cast Hill Giant".
static func release_text(option_text: String) -> String:
	return "Release to %s%s" % [option_text.left(1).to_lower(), option_text.substr(1)]


## The prompt for [param decision] as the player whose [param view] this is reads it. A
## null decision (nobody is asking them anything) has no text, and nor has one answered on
## the opening-hand overlay, which says everything itself and covers the panel. With no
## decision and [param paying], the payment Auto-tap is making, it says what is being paid.
static func of(decision: MmPendingDecision, view: MmPlayerView, paying: PayManaDecision = null,
		names: PlayerNames = null) -> InfoPrompt:
	var prompt: InfoPrompt = InfoPrompt.new()
	if decision == null and paying != null:
		prompt.text = "Paying for %s" % stack_name(view, view.stack.back().id if not view.stack.is_empty() else -1)
		prompt.owed = _owed(paying)
		prompt.can_cancel = true
		return prompt
	if decision == null:
		return prompt
	if decision is PriorityDecision:
		var called: PlayerNames = names if names != null else PlayerNames.new()
		var whose: String = "your turn" if view.active_player_id == view.viewer_id \
				else called.the_possessive(view.active_player_id) + " turn"
		var step: String = PlayerPanel.STEP_NAMES[view.step] if view.step >= 0 else ""
		prompt.text = "Your priority\n%s, %s" % [step, whose] if step != "" else "Your priority"
	elif decision is PayManaDecision:
		var pay: PayManaDecision = decision as PayManaDecision
		prompt.text = "Pay for %s" % stack_name(view, view.stack.back().id if not view.stack.is_empty() else -1)
		prompt.owed = _owed(pay)
		prompt.can_cancel = true
	elif decision is ChooseTargetDecision:
		prompt.text = "Choose a target for %s" % stack_name(view, (decision as ChooseTargetDecision).stack_object_id)
		prompt.can_cancel = true
	elif decision is DeclareAttackersDecision:
		prompt.text = "Declare attackers"
		prompt.offers_all_attack = true
	elif decision is DeclareBlockersDecision:
		prompt.text = "Declare blockers"
	elif decision is DivideCombatDamageDecision:
		var divide: DivideCombatDamageDecision = decision as DivideCombatDamageDecision
		prompt.text = "Divide %d damage from %s" % [divide.amount, EncounterSnapshot.name_in(view, divide.source_id)]
	elif decision is OrderTriggersDecision:
		prompt.text = "Order your triggers"
	elif decision is ChooseReplacementEffectDecision:
		prompt.text = "Choose which applies first"
	elif CardPicks.covers(decision) and not OpeningHand.covers(decision):
		prompt.text = CardPicks.new(decision).prompt()
	elif not OpeningHand.covers(decision):
		# A kind with no input of its own (DecisionInputs): say what the engine asks, so
		# the Hero is not left looking at nothing, and say loudly that this is a bug.
		prompt.text = decision.describe()
		push_error("No input answers %s." % decision.describe())
	return prompt


static func _owed(payment: PayManaDecision) -> MmManaCost:
	var owed: MmManaCost = MmManaCost.new()
	owed.generic = payment.remaining_generic
	owed.symbols = payment.remaining_symbols.duplicate()
	return owed


## What the spell or ability [param stack_object_id] is called: a spell's name, or "X's
## ability" after an ability's source.
static func stack_name(view: MmPlayerView, stack_object_id: int) -> String:
	for item: MmObjectView in view.stack:
		if item.id != stack_object_id:
			continue
		if item.card_id != MmGameObject.NO_CARD:
			return item.name
		var source: String = EncounterSnapshot.name_in(view, item.source_object_id)
		return item.name if source.begins_with("object ") else "%s's ability" % source
	return "this"
