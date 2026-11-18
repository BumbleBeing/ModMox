class_name DecisionInputs
extends RefCounted
## Which kinds of Pending Decision the Encounter Screen has an input for (ADR 0022). Every
## kind the engine can ask is listed here beside what answers it, and a test fails when the
## engine gains a kind that is not: the Hero would be asked something with nothing to click.

## Each kind, and where it is answered.
static func kinds() -> Dictionary[Script, String]:
	return {
		PriorityDecision: "the hand, permanents and the pass button (DecisionClicks)",
		PayManaDecision: "mana sources and the pool (DecisionClicks), unless Auto-tap pays (ADR 0031)",
		ChooseTargetDecision: "what can be targeted (DecisionClicks)",
		ChooseObjectDecision: "what can be chosen, clicked as a target is (DecisionClicks)",
		DeclareAttackersDecision: "the Hero's creatures (CombatSelection)",
		DeclareBlockersDecision: "the Hero's creatures and the attackers (CombatSelection)",
		DivideCombatDamageDecision: "steppers on the recipients (CombatSelection)",
		OrderTriggersDecision: "the Stack Window (TriggerOrder)",
		ChooseReplacementEffectDecision: "the choice window",
		ChooseModeDecision: "the choice window, an entry for each mode",
		ChoosePlayOrDrawDecision: "the opening-hand overlay (OpeningHand)",
		KeepOrMulliganDecision: "the opening-hand overlay (OpeningHand)",
		ChooseCardsToBottomDecision: "the opening-hand overlay (CardPicks)",
		ChooseCardsToDiscardDecision: "the hand's strip (CardPicks)",
		ChoosePermanentsDecision: "the permanents on the battlefield and the pass button (CardPicks)",
		ChooseLegendToKeepDecision: "the legends on the battlefield, clicked as a target is (DecisionClicks)",
		ChooseCreatureTypeDecision: "the Creature Type Window, a search box and a row for each type (CreatureTypeChoice)",
		ChooseCardsInLibraryDecision: "the Hero's Library window, opened by itself, and the pass button (CardPicks)",
	}


## Whether the screen has an input that answers [param decision].
static func covers(decision: MmPendingDecision) -> bool:
	if decision == null:
		return false
	for kind: Script in kinds():
		if is_instance_of(decision, kind):
			return true
	return false
