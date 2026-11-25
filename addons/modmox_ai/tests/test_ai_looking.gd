extends GutTest
## A look at the top cards of a library (CR 701.20e), as Militia Bugler's: the Agent takes a
## card from among them rather than nothing, as many as it may, ranked and simulated as a
## search's are (engine ADR 0057).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_it_takes_a_card_rather_than_nothing() -> void:
	for mode: AiAgent.Mode in [AiAgent.Mode.CHEAP, AiAgent.Mode.FULL]:
		var engine: MmEngine = _looking()
		var decision: ChooseLookedAtCardsDecision = engine.pending_decision() as ChooseLookedAtCardsDecision

		var answer: Variant = AiScenario.ask(engine, AiAgent.new(null, mode))

		assert_eq((answer as Array).size(), 1, "Mode %d takes one." % mode)
		assert_true(decision.candidate_ids.has((answer as Array)[0]))
		assert_eq(engine.submit(answer), "")


## The Hero's Bugler (Scenario.bugler()) has entered, and its look is asked, with at least one
## Pup, a 1/1 that may be taken, among the top four.
func _looking() -> MmEngine:
	var deck: Array[MmCardDefinition] = Scenario.cycled([Scenario.bugler(), Scenario.creature("Pup", 1, 1),
		Scenario.creature("Ogre", 3, 3)] as Array[MmCardDefinition])
	var setup: MmEncounterSetup = Scenario.setup_with(deck, Scenario.cycled([] as Array[MmCardDefinition]))
	var engine: MmEngine = Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		if Scenario.play_until_step(running, 3, Step.PRECOMBAT_MAIN) != "":
			return false
		var bugler: int = Scenario.card_in_hand(running, running.hero(), "Bugler")
		if bugler == -1 or Scenario.cast(running, bugler) != "":
			return false
		Scenario.autoplay(running, func(now: MmEngine) -> bool: return now.pending_decision() is ChooseLookedAtCardsDecision)
		var look: ChooseLookedAtCardsDecision = running.pending_decision() as ChooseLookedAtCardsDecision
		return look != null and not look.candidate_ids.is_empty())
	assert_not_null(engine, "No seed gave the needed hand and library.")
	return engine
