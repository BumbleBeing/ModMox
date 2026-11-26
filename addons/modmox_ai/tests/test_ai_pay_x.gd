extends GutTest
## How much X to pay for a "you may pay {X}" (ADR 0061). Only the Xs at which what it wraps
## offers something new are weighed: for a search, each mana value it could then find. A
## CHEAP Agent pays the largest of them and declines when there is none; a FULL Agent
## simulates declining and each of them, with that as the default. Neither knows any card's
## name.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")


func test_it_pays_the_x_that_finds_its_best_knight() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var engine: MmEngine = _x_asked([_squire(), _champion()])
		var asked: ChooseXToPayDecision = engine.pending_decision() as ChooseXToPayDecision
		assert_eq(asked.most, 3, "The Mana Bird makes three.")

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseXToPayDecision.answer_for(3), "X = 3 reaches the 5/5 Champion, not only the 1/1 Squire.")
		assert_eq(agent.explain(), AiAgent.Reason.BEST_SCORE)
		assert_eq(engine.submit(answer), "")
		assert_true(engine.pending_decision() is PayManaDecision, "X is then paid.")


func test_with_nothing_it_could_find_it_declines() -> void:
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var no_knights: Array[MmCardDefinition] = []
		var engine: MmEngine = _x_asked(no_knights)

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseXToPayDecision.DECLINE)
		assert_eq(agent.explain(), AiAgent.Reason.ONLY_CHOICE)
		assert_eq(agent.rollout_count(), 0, "Nothing worth paying for, so nothing is simulated.")


func test_it_pays_all_it_can_for_counters_a_reflexive_trigger_puts_on_its_preserver() -> void:
	# Engine ADR 0088's fifth addendum, as Wildborn Preserver's "you may pay {X}. When you do,
	# put X +1/+1 counters on this creature."
	for agent: AiAgent in [AiAgent.new(null, AiAgent.Mode.CHEAP), AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())]:
		var bird: MmCardDefinition = Scenario.mana_bird()
		var preserver: MmCardDefinition = Scenario.preserver()
		var bear: MmCardDefinition = Scenario.creature("Bear", 2, 2)
		var ogre: MmCardDefinition = Scenario.creature("Ogre", 3, 3)
		var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled([bird, preserver, bear]), Scenario.cycled([ogre]))
		var no_cards: Array[MmCardDefinition] = []
		var engine: MmEngine = Scenario.permanents_ready_with(setup, [bird, preserver], [ogre], [bear], no_cards, 3,
			MmTurn.Step.PRECOMBAT_MAIN)
		assert_not_null(engine, "No seed gave the needed hand.")
		assert_eq(Scenario.cast_and_resolve(engine, "Bear"), "")
		assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseXToPayDecision), "")
		var asked: ChooseXToPayDecision = engine.pending_decision() as ChooseXToPayDecision
		assert_eq(asked.most, 3, "The Mana Bird makes three.")

		var answer: int = AiScenario.ask(engine, agent)

		assert_eq(answer, ChooseXToPayDecision.answer_for(3), "Each mana paid is a counter that lasts.")


## The Hero, with a Mana Bird ("{T}: Add {W}{W}{W}") on the battlefield and [param knights]
## in their deck, has cast Seeker: "When this creature enters, you may pay {X}. If you do,
## search your library for a Knight card with mana value X or less, put that card onto the
## battlefield, then shuffle." How much X to pay is asked.
func _x_asked(knights: Array[MmCardDefinition]) -> MmEngine:
	var seeking: SearchLibraryEffect = Scenario.search(Scenario.all_of([Scenario.has_subtype("Knight"),
		Scenario.mana_value_from(Scenario.paid_x())]), 1, MmZone.Kind.BATTLEFIELD, false)
	var seeker: MmCardDefinition = Scenario.x_payer("Seeker", seeking)
	var bird: MmCardDefinition = Scenario.mana_bird()
	var ogre: MmCardDefinition = Scenario.creature("Ogre", 3, 3)
	var hero_cards: Array[MmCardDefinition] = [bird, seeker]
	hero_cards.append_array(knights)
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.cycled(hero_cards), Scenario.cycled([ogre]))
	var no_cards: Array[MmCardDefinition] = []
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [bird], [ogre], [seeker], no_cards, 3,
		MmTurn.Step.PRECOMBAT_MAIN)
	assert_not_null(engine, "No seed gave the needed hand.")
	assert_eq(Scenario.cast_and_resolve(engine, "Seeker"), "")
	assert_eq(AiScenario.pass_to(engine, engine.hero().id, ChooseXToPayDecision), "")
	return engine


func _squire() -> MmCardDefinition:
	var squire: MmCardDefinition = Scenario.creature("Squire", 1, 1, [], Scenario.mana_cost(1))
	squire.subtypes = ["Knight"]
	return squire


func _champion() -> MmCardDefinition:
	var champion: MmCardDefinition = Scenario.creature("Champion", 5, 5, [], Scenario.mana_cost(3))
	champion.subtypes = ["Knight"]
	return champion
