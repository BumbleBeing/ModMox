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
		ChooseTargetsDecision: "the permanents that can be targeted and the pass button (CardPicks)",
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
		ChooseYesOrNoDecision: "the Info Panel's two answers, which a click gives at once, or Left and Right selects for the pass button to give (game ADR 0066 and its addendum), also for a land that may pay to enter untapped (game ADR 0067)",
		SurveilDecision: "the Surveil window, whose cards are dragged to order, clicked to select and sent with its Graveyard button, and the pass button, which reads Done (game ADR 0069)",
		ChooseLookedAtCardsDecision: "the Look window, whose cards that may be taken are clicked to select and taken with its Hand button, and the pass button, which reads Done (game ADR 0085)",
		ChooseXDecision: "the Info Panel's X stepper and Cancel, and the pass button, which casts with the X shown (engine ADR 0076)",
		ChooseXToPayDecision: "the Info Panel's X stepper and No, which a click or Left and Right only selects, and the pass button, which pays the X shown or declines (game ADRs 0063 and 0066)",
	}


## Whether the screen has an input that answers [param decision].
static func covers(decision: MmPendingDecision) -> bool:
	if decision == null:
		return false
	for kind: Script in kinds():
		if is_instance_of(decision, kind):
			return true
	return false
