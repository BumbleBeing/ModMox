class_name InfoPrompt
extends RefCounted
## What the Info Panel (game glossary) says for one Pending Decision: one line asking the
## Hero for what is wanted, what is still owed while paying, and whether the decision is a
## step of a cast that can be canceled. While Auto-tap pays for the Hero it says what is being
## paid for instead, with what is still owed, and the cast can still be canceled. Paying a
## ward cost reads "Pay ward for Leonin Lightbringer: {2}" from its yes or no to its last
## payment, and has no Cancel: nothing is being cast (ADR 0062). Choosing X for a "you may
## pay {X}" reads "Pay {X} for Taj-Nar Swordsmith?", with a stepper and No in the panel, and
## paying it reads "Pay for Taj-Nar Swordsmith:" with what is owed after it (game ADR 0063).

## What a surveil asks (game ADR 0069), of one card and of more.
const SURVEIL_ONE: String = "Surveil: graveyard any of these."
const SURVEIL_SEVERAL: String = "Surveil: graveyard any of these, and order the rest. The leftmost will be on top."
## What a scry asks (game ADR 0069's addendum), of one card and of more: the user's words.
const SCRY_ONE: String = "Scry: put any of these on the bottom."
const SCRY_SEVERAL: String = "Scry: put any of these on the bottom, and order the rest. The leftmost will be on top."
## What an explore asks of the nonland card it revealed (engine ADR 0090), the words shown to the user.
const EXPLORE: String = "Explore: graveyard this card, or keep it on top."

var text: String = ""
## While paying: what is still owed. Null otherwise.
var owed: MmManaCost = null
## Whether what is owed follows the text on its line, as a ward cost does, rather than
## under it.
var is_owed_inline: bool = false
var can_cancel: bool = false
## While declaring attackers: the panel offers "Declare All" (A311).
var offers_all_attack: bool = false
## While a question with two answers is asked, a "you may", a ward cost or an X: the
## panel's Answer Row holds them, the affirmative and "No": a click gives one, or the Pass
## Button gives the one selected (game ADRs 0060 and 0066).
var offers_no: bool = false
## While how much X to pay is asked: the panel shows a stepper from 0 to [member most_x],
## and the Pass Button pays the X it shows (game ADR 0063).
var chooses_x: bool = false
var most_x: int = 0
## The affirmative answer's words when they are neither "Yes" nor paying what is owed:
## "Pay 2 life", for a land that may be paid for to enter untapped (game ADR 0067).
var affirmative: String = ""


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
	var resolving: MmObjectView = _trigger_resolving(view)
	if resolving != null and (decision is PayManaDecision or (decision == null and paying != null)):
		# ADR 0062, game ADR 0063: paying a ward cost or an X, by hand or by Auto-tap, says
		# what it is for, and a payment on resolution cannot be canceled.
		prompt.text = ward_words(view, resolving) if resolving.ability is WardAbility \
			else "Pay for %s:" % source_name(view, resolving)
		prompt.owed = _owed(decision as PayManaDecision if decision != null else paying)
		prompt.is_owed_inline = true
		return prompt
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
	elif decision is ChooseModeDecision:
		var choosing: int = (decision as ChooseModeDecision).stack_object_id
		prompt.text = "Choose one for %s" % stack_name(view, choosing)
		prompt.can_cancel = not _is_trigger(view, choosing)
	elif decision is ChooseTargetDecision:
		var targeting: int = (decision as ChooseTargetDecision).stack_object_id
		prompt.text = "Choose a target for %s" % stack_name(view, targeting)
		prompt.can_cancel = not _is_trigger(view, targeting)
	elif decision is ChooseTargetsDecision:
		# "Choose up to two targets for Gird for Battle"; the screen adds how many are picked.
		var several: ChooseTargetsDecision = decision as ChooseTargetsDecision
		prompt.text = "Choose %s for %s" % [AbilityText.up_to_targets_words(several.most), stack_name(view, several.stack_object_id)]
		prompt.can_cancel = not _is_trigger(view, several.stack_object_id)
	elif decision is ChooseObjectDecision and (decision as ChooseObjectDecision).purpose \
			== ChooseObjectDecision.Purpose.EXILE_FROM_GRAVEYARD:
		# Engine ADR 0088, the user's words: "Exile a creature card from your graveyard for
		# Kishla Trawlers", as a cost's choice reads, though it can't be canceled.
		var exiling: ChooseObjectDecision = decision as ChooseObjectDecision
		var paying_for: MmObjectView = _stack_item(view, exiling.stack_object_id)
		prompt.text = "Exile %s from your graveyard for %s" % [AbilityText.chosen_card_words(exiling.filter),
			source_name(view, paying_for) if paying_for != null else "this"]
	elif decision is ChooseObjectDecision:
		var choice: ChooseObjectDecision = decision as ChooseObjectDecision
		# Engine ADR 0080: a card among the cards just milled is "an instant or sorcery card".
		var words: String = AbilityText.chosen_words(choice.filter) if _is_on_battlefield(view, choice.candidates) \
			else AbilityText.chosen_card_words(choice.filter)
		prompt.text = "Choose %s for %s" % [words, stack_name(view, choice.stack_object_id)]
	elif decision is ChoosePermanentsDecision:
		var pick: ChoosePermanentsDecision = decision as ChoosePermanentsDecision
		var picked: String = AbilityText.how_many_words(pick.count, pick.filter)
		if pick.purpose == ChoosePermanentsDecision.Purpose.RETURN_TO_HAND:
			# The user's words: "Return a permanent you control to its owner's hand for Fear of
			# Isolation".
			prompt.text = "Return %s to %s owner's hand for %s" % [picked, "its" if pick.count == 1 else "their",
				stack_name(view, pick.stack_object_id)]
		else:
			prompt.text = "Tap %s for %s" % [picked, stack_name(view, pick.stack_object_id)]
		prompt.can_cancel = true
	elif decision is ChooseCardsInLibraryDecision:
		# Game ADR 0058: "Bushwhack: search your library for a basic land card".
		var search: ChooseCardsInLibraryDecision = decision as ChooseCardsInLibraryDecision
		prompt.text = "%s: search your library for %s" % [stack_name(view, search.stack_object_id),
			AbilityText.searched_words(search.most, search.is_up_to, search.filter)]
	elif decision is ExploreDecision:
		prompt.text = EXPLORE  # Engine ADR 0090, the Surveil window holding the card.
	elif decision is ScryDecision:
		# Game ADR 0069's addendum: the user's words, the Surveil window holding the cards.
		prompt.text = SCRY_ONE if (decision as ScryDecision).card_ids.size() == 1 else SCRY_SEVERAL
	elif decision is SurveilDecision:
		# Game ADR 0069: the user's words, the Surveil window holding the cards.
		prompt.text = SURVEIL_ONE if (decision as SurveilDecision).card_ids.size() == 1 else SURVEIL_SEVERAL
	elif decision is ChooseLookedAtCardsDecision:
		# Game ADR 0085, the user's words: "Militia Bugler: you may put a creature card with
		# power 2 or less into your hand. The rest go to the bottom."
		var look: ChooseLookedAtCardsDecision = decision as ChooseLookedAtCardsDecision
		var looking: String = "this"
		for item: MmObjectView in view.stack:
			if item.id == look.stack_object_id:
				looking = source_name(view, item)
		prompt.text = "%s: you may put %s into your hand. The rest go to the bottom." % [
			looking, AbilityText.searched_words(look.most, look.most != 1, look.filter)]
	elif decision is ChooseYesOrNoDecision:
		# Game ADR 0060: "Leonin Snarecaster's ability: tap target creature?"
		var asked: ChooseYesOrNoDecision = decision as ChooseYesOrNoDecision
		prompt.offers_no = true
		if asked.entry_cost != null:
			# Game ADR 0067: "Have Temple Garden enter untapped?", "Pay 2 life" on the left.
			prompt.text = "Have %s enter untapped?" % EncounterSnapshot.name_in(view, asked.entering_object_id)
			prompt.affirmative = AbilityText.cost_words(asked.entry_cost, "this land")
			return prompt
		if asked.cost != null:
			# ADR 0062: "Pay ward for Leonin Lightbringer: {2}", Pay on the Pass Button.
			var asking: MmObjectView = _stack_item(view, asked.stack_object_id)
			prompt.text = ward_words(view, asking) if asking != null and asking.ability is WardAbility \
				else "Pay for %s:" % stack_name(view, asked.stack_object_id)
			prompt.owed = asked.cost
			prompt.is_owed_inline = true
			return prompt
		if asked.resolution_cost != null:
			# Engine ADR 0076: "Guiding Hydra's ability: remove a +1/+1 counter from this
			# creature?", as a "you may" reads (game ADR 0060).
			prompt.text = "%s: %s?" % [stack_name(view, asked.stack_object_id), paid_words(view, asked)]
			return prompt
		prompt.text = "%s: %s?" % [stack_name(view, asked.stack_object_id), offered_words(view, asked)]
	elif decision is ChooseXToPayDecision:
		# Game ADR 0063: "Pay {X} for Taj-Nar Swordsmith?"
		var choosing: ChooseXToPayDecision = decision as ChooseXToPayDecision
		var asking_x: MmObjectView = _stack_item(view, choosing.stack_object_id)
		prompt.text = "Pay {X} for %s?" % (source_name(view, asking_x) if asking_x != null else "this")
		prompt.chooses_x = true
		prompt.most_x = choosing.most
		prompt.offers_no = true
	elif decision is ChooseXDecision:
		# Engine ADR 0076: "Choose {X} for Guiding Hydra", the stepper and Cancel below it.
		var casting: ChooseXDecision = decision as ChooseXDecision
		prompt.text = "Choose {X} for %s" % stack_name(view, casting.stack_object_id)
		prompt.chooses_x = true
		prompt.most_x = casting.most
		prompt.can_cancel = true
	elif decision is ChooseCreatureTypeDecision:
		prompt.text = "Choose a creature type for %s" % stack_name(view, (decision as ChooseCreatureTypeDecision).stack_object_id)
	elif decision is ChooseLegendToKeepDecision:
		prompt.text = "Choose which %s to keep" % (decision as ChooseLegendToKeepDecision).legend_name
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


## What a "you may" offers, in the words of the spell or ability asking it: "tap target
## creature".
static func offered_words(view: MmPlayerView, asked: ChooseYesOrNoDecision) -> String:
	for item: MmObjectView in view.stack:
		if item.id != asked.stack_object_id:
			continue
		var ability: MmAbility = item.ability if item.ability != null else StackItem.spell_of(item)
		if ability != null:
			return AbilityText.offered_words(ability, asked.effect, StackItem.noun_of(item, view), item.chosen_mode)
	return AbilityText.offered_words(SpellAbility.new(), asked.effect, "this")


## What yes pays for a "you may [cost]" (engine ADR 0076), in the words of the spell or
## ability asking it: "remove a +1/+1 counter from this creature".
static func paid_words(view: MmPlayerView, asked: ChooseYesOrNoDecision) -> String:
	var noun: String = "this"
	for item: MmObjectView in view.stack:
		if item.id == asked.stack_object_id:
			noun = StackItem.noun_of(item, view)
	var words: String = AbilityText.cost_words(asked.resolution_cost, noun)
	return words.left(1).to_lower() + words.substr(1)


## "Pay ward for Leonin Lightbringer:", after the warded permanent of [param ward], a ward
## trigger on the stack (ADR 0062). What is owed follows it.
static func ward_words(view: MmPlayerView, ward: MmObjectView) -> String:
	var warded: String = EncounterSnapshot.name_in(view, ward.source_object_id)
	return "Pay ward for %s:" % (ward.name if warded.begins_with("object ") else warded)


## The name of what [param item] on the stack comes from: an ability's source, or its own
## name when the source is out of sight, or a spell's name.
static func source_name(view: MmPlayerView, item: MmObjectView) -> String:
	if item.card_id != MmGameObject.NO_CARD:
		return item.name
	var source: String = EncounterSnapshot.name_in(view, item.source_object_id)
	return item.name if source.begins_with("object ") else source


## The triggered ability resolving on top of the stack, such as ward's, or null: a payment
## made while it is there is made as it resolves, since putting a trigger on the stack costs
## nothing and a spell being cast is always on top of what it was cast over.
static func _trigger_resolving(view: MmPlayerView) -> MmObjectView:
	if view.stack.is_empty() or not view.stack.back().ability is TriggeredAbility:
		return null
	return view.stack.back()


static func _stack_item(view: MmPlayerView, stack_object_id: int) -> MmObjectView:
	for item: MmObjectView in view.stack:
		if item.id == stack_object_id:
			return item
	return null


## Whether [param stack_object_id] is a triggered ability. Putting one on the stack can't be
## taken back (CR 603.3), so its mode and targets have no Cancel (game ADR 0047).
static func _is_trigger(view: MmPlayerView, stack_object_id: int) -> bool:
	for item: MmObjectView in view.stack:
		if item.id == stack_object_id:
			return item.ability is TriggeredAbility
	return false


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


## Whether the first of [param candidates] is a permanent [param view] shows.
static func _is_on_battlefield(view: MmPlayerView, candidates: Array[MmReference]) -> bool:
	if candidates.is_empty() or not candidates[0].is_object():
		return true
	for permanent: MmObjectView in view.battlefield:
		if permanent.id == candidates[0].id:
			return true
	return false
