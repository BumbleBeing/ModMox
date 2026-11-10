extends GutTest
## The AI's pregame: playing first (roadmap milestone 11), mulligans by land count, and what
## it puts on the bottom (A161).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const DefaultAnswerAgent := preload("res://addons/modmox_rules/tests/support/default_answer_agent.gd")


func test_chooses_to_play_first_by_default() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))
	var agent: AiAgent = AiAgent.new()

	assert_eq(AiScenario.ask(engine, agent), ChoosePlayOrDrawDecision.Choice.PLAY)
	assert_eq(agent.explain(), AiAgent.Reason.PROFILE)


func test_a_profile_can_choose_to_draw() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))
	var profile: AiProfile = AiProfile.new()
	profile.prefers_to_play_first = false

	assert_eq(AiScenario.ask(engine, AiAgent.new(profile)), ChoosePlayOrDrawDecision.Choice.DRAW)


func test_keeps_a_seven_card_hand_with_three_lands() -> void:
	var engine: MmEngine = _at_heros_mulligan(func(lands: int) -> bool: return lands == 3)

	assert_eq(AiScenario.ask(engine, AiAgent.new()), KeepOrMulliganDecision.Choice.KEEP)


func test_mulligans_a_hand_with_no_lands_or_too_many() -> void:
	for wanted: int in [0, 6]:
		var engine: MmEngine = _at_heros_mulligan(func(lands: int) -> bool: return lands == wanted)
		var agent: AiAgent = AiAgent.new()

		assert_eq(AiScenario.ask(engine, agent), KeepOrMulliganDecision.Choice.MULLIGAN, "%d lands" % wanted)
		assert_eq(agent.explain(), AiAgent.Reason.LAND_COUNT)


func test_always_keeps_once_down_to_five_cards() -> void:
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(Scenario.vanilla("Bear"), 40),
		Scenario.copies(Scenario.vanilla("Bear"), 40))
	var engine: MmEngine = MmEngine.start(setup)
	var agents: Dictionary[int, MmAgent] = {}
	agents[MmEncounterSetup.HERO_PLAYER_ID] = AiAgent.new()
	agents[MmEncounterSetup.VILLAIN_PLAYER_ID] = DefaultAnswerAgent.new()
	var driver: MmEncounterDriver = MmEncounterDriver.new(engine, agents)

	driver.run_until(func(running: MmEngine) -> bool: return running.pending_decision() is PriorityDecision)

	assert_eq(engine.hero().mulligans_taken, 2, "No hand has lands, so it mulligans until keeping is forced.")
	assert_eq(engine.hero().hand.size(), 5)


func test_puts_excess_lands_on_the_bottom() -> void:
	var profile: AiProfile = AiProfile.new()
	profile.mulligan_max_lands = 0
	profile.always_keeps_at = 6
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Forest"), 30, Scenario.vanilla("Bear"), 10)
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(cards, cards.duplicate()))
	var agent: AiAgent = AiAgent.new(profile)
	AiScenario.pass_to(engine, engine.hero().id, KeepOrMulliganDecision)
	assert_eq(AiScenario.let_answer(engine, agent), "")
	AiScenario.pass_to(engine, engine.hero().id, KeepOrMulliganDecision)
	assert_eq(AiScenario.let_answer(engine, agent), "", "Keeps six.")
	AiScenario.pass_to(engine, engine.hero().id, ChooseCardsToBottomDecision)
	var hand_lands: int = _lands_in(engine, engine.hero().hand.objects())
	assert_gt(hand_lands, 3)

	var bottomed: Array = AiScenario.ask(engine, agent)

	assert_eq(bottomed.size(), 1)
	assert_eq(engine.game_state().characteristics_of(engine.game_state().object(bottomed[0])).name, "Forest")


## An engine stopped at the Hero's first keep-or-mulligan decision, with a hand whose land
## count satisfies [param wanted].
func _at_heros_mulligan(wanted: Callable) -> MmEngine:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Forest"), 20, Scenario.vanilla("Bear"), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, cards.duplicate()), func(running: MmEngine) -> bool:
		AiScenario.pass_to(running, running.hero().id, KeepOrMulliganDecision)
		return wanted.call(_lands_in(running, running.hero().hand.objects())))
	assert_not_null(engine, "No seed dealt that hand.")
	return engine


func _lands_in(engine: MmEngine, cards: Array[MmGameObject]) -> int:
	var lands: int = 0
	for card: MmGameObject in cards:
		if engine.game_state().characteristics_of(card).has_card_type(MmCardTypes.CardType.LAND):
			lands += 1
	return lands
