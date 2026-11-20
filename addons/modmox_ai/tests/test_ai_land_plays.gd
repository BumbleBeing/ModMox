extends GutTest
## Land plays are weighed (AiDifficulty.weighs_land_plays): at Normal and Hard a land that
## scores worse than passing one step ahead is rolled out against passing, with the land
## as the default, so the AI no longer plays a land into its own Ankh's Curse at 1 life.
## Easy still plays a land whenever it can.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const AiScenario := preload("res://addons/modmox_ai/tests/support/ai_scenario.gd")
const Step := MmTurn.Step


func test_normal_keeps_its_land_rather_than_die_to_its_own_curse() -> void:
	var engine: MmEngine = _cursed(1)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	var play: MmAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent))

	assert_true(play is PassAction, "The land would deal the last point of damage.")
	assert_eq(agent.explain(), AiAgent.Reason.LAND_COSTS_TOO_MUCH)


func test_hard_keeps_its_land_at_two_life() -> void:
	var engine: MmEngine = _cursed(2)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.hard())

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PassAction)
	assert_eq(agent.explain(), AiAgent.Reason.LAND_COSTS_TOO_MUCH)


func test_normal_still_plays_its_land_into_the_curse_at_twenty_life() -> void:
	var engine: MmEngine = _cursed(20)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PlayLandAction,
		"Two life is worth a land when there is life to spare.")


func test_normal_casts_what_it_can_instead_of_playing_its_land() -> void:
	var engine: MmEngine = _cursed(1, [AiScenario.free_alpha("lightning_bolt")], [AiScenario.free_alpha("grizzly_bears")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	var play: int = AiScenario.ask(engine, agent)

	assert_eq(AiScenario.cast_name(engine, play), "Lightning Bolt")


func test_easy_plays_its_land_whatever_it_costs() -> void:
	var engine: MmEngine = _cursed(1)
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PlayLandAction)
	assert_eq(agent.explain(), AiAgent.Reason.PLAY_LAND)


func test_a_land_that_scores_well_is_played_without_rollouts() -> void:
	var no_creatures: Array[MmCardDefinition] = []
	var engine: MmEngine = AiScenario.ready_with(no_creatures, no_creatures, [AiScenario.alpha("mountain")])
	assert_not_null(engine)
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.hard())

	assert_true(AiScenario.action_at(engine, AiScenario.ask(engine, agent)) is PlayLandAction)
	assert_eq(agent.explain(), AiAgent.Reason.PLAY_LAND)
	assert_eq(agent.rollout_count(), 0)


func test_without_monte_carlo_a_land_is_kept_only_when_it_would_lose_the_game() -> void:
	var difficulty: AiDifficulty = AiDifficulty.easy()
	difficulty.weighs_land_plays = true
	for life: int in [1, 3]:
		var engine: MmEngine = _cursed(life)
		assert_not_null(engine)
		var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, difficulty)

		var play: MmAction = AiScenario.action_at(engine, AiScenario.ask(engine, agent))

		if life == 1:
			assert_true(play is PassAction, "At 1 life the land loses the game.")
		else:
			assert_true(play is PlayLandAction, "At 3 life one step cannot tell the land is a mistake.")


func test_normal_casts_explore_and_plays_the_additional_land() -> void:
	var engine: MmEngine = _exploring()
	assert_not_null(engine, "No seed gave the needed hand.")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.normal())

	for answer: int in 60:
		if engine.game_state().game_turn != 3 or engine.is_over():
			break
		var decision: MmPendingDecision = engine.pending_decision()
		var given: Variant = AiScenario.ask(engine, agent) if decision.player_id == engine.hero().id \
			else Scenario.default_answer(decision)
		assert_eq(engine.submit(given), "")

	assert_ne(Scenario.card_in_graveyard(engine, engine.hero(), "Explore"), -1, "Explore was cast.")
	assert_eq(_lands_of(engine, engine.hero().id), 3, "A land on Game Turns 1 and 3, and the additional one.")


func test_an_untapped_land_is_played_over_one_that_enters_tapped_when_its_mana_casts_a_spell() -> void:
	# The Forest in the tapped land is needed most ({3}{G}{G}), but only the Swamp's mana
	# casts something this turn.
	var engine: MmEngine = _with_lands_in_hand(Scenario.tapped_dual_land("Swamp", "Forest"),
		[Scenario.creature("Rat", 1, 1, [], Scenario.mana_cost(0, [MmMana.Type.BLACK])),
		Scenario.creature("Wurm", 6, 6, [], Scenario.mana_cost(3, [MmMana.Type.GREEN, MmMana.Type.GREEN]))])
	assert_not_null(engine, "No seed gave the needed hand.")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.FULL, AiDifficulty.easy())

	assert_eq(_land_name(engine, AiScenario.ask(engine, agent)), "Swamp")


func test_a_land_that_enters_tapped_is_played_first_when_no_mana_would_be_spent() -> void:
	# The Swamp makes the color the hand needs, but nothing could be cast with it this turn.
	var engine: MmEngine = _with_lands_in_hand(Scenario.tapped_dual_land("Plains", "Island"),
		[Scenario.creature("Horror", 4, 4, [], Scenario.mana_cost(3, [MmMana.Type.BLACK]))])
	assert_not_null(engine, "No seed gave the needed hand.")
	var agent: AiAgent = AiAgent.new(null, AiAgent.Mode.CHEAP)

	assert_eq(_land_name(engine, AiScenario.ask(engine, agent)), "Tapped Plains Island")


## The Hero in their precombat main phase on Game Turn 3 with no lands yet, holding
## [param tapped_land], a Swamp and [param spells].
func _with_lands_in_hand(tapped_land: MmCardDefinition, spells: Array[MmCardDefinition]) -> MmEngine:
	var hand: Array[MmCardDefinition] = [tapped_land, Scenario.basic_land("Swamp")]
	hand.append_array(spells)
	var no_creatures: Array[MmCardDefinition] = []
	return AiScenario.ready_with(no_creatures, no_creatures, hand)


## The name of the land a priority answer plays, or "".
func _land_name(engine: MmEngine, answer: int) -> String:
	var play: PlayLandAction = AiScenario.action_at(engine, answer) as PlayLandAction
	return "" if play == null else engine.game_state().characteristics_of(engine.game_state().object(play.object_id)).name


## The Hero in their precombat main phase on Game Turn 3 at [param life], holding a
## Mountain and [param extras], with "Sample Hex: Ankh's Curse", the sample Emblem with
## Ankh of Mishra's abilities, against a Villain with [param villain_creatures].
func _cursed(life: int, extras: Array[MmCardDefinition] = [], villain_creatures: Array[MmCardDefinition] = []) -> MmEngine:
	var hand: Array[MmCardDefinition] = [AiScenario.alpha("mountain")]
	hand.append_array(extras)
	var no_creatures: Array[MmCardDefinition] = []
	var setup: MmEncounterSetup = Scenario.combat_setup(no_creatures, villain_creatures, hand)
	setup.hero.emblems = [Scenario.emblem("Sample Hex: Ankh's Curse",
		AiScenario.alpha("ankh_of_mishra").abilities.duplicate())] as Array[MmCardDefinition]
	setup.hero.starting_life = life
	return Scenario.permanents_ready_with(setup, no_creatures, villain_creatures, hand, [], 3, Step.PRECOMBAT_MAIN)


## The Hero in their precombat main phase on Game Turn 3, having played a land on each of
## their turns, controlling two Forests and holding Explore ({1}{G} sorcery: "You may play
## an additional land this turn. Draw a card.") and another Forest. Half their deck is
## Colossus, a 6/6 costing {6}, so what Explore draws is worth more in hand than Explore
## (A179): with a deck mostly of lands, a card for a card scores worse than holding it.
func _exploring() -> MmEngine:
	var forest: MmCardDefinition = AiScenario.alpha("forest")
	var explore: MmCardDefinition = Scenario.sorcery("Explore", Scenario.mana_cost(1, [MmMana.Type.GREEN]), [],
		[Scenario.additional_land_plays(1, Scenario.you()), Scenario.draw_cards(1, Scenario.you())])
	var colossus: MmCardDefinition = Scenario.creature("Colossus", 6, 6, [], Scenario.mana_cost(6))
	var hero_cards: Array[MmCardDefinition] = []
	for index: int in 40:
		hero_cards.append([forest, explore, colossus, colossus][index % 4])
	var setup: MmEncounterSetup = Scenario.setup_with(hero_cards, Scenario.copies(forest, 40))
	return Scenario.find_engine(setup, func(running: MmEngine) -> bool:
		return Scenario.ready_in_main(running, 3, 2, "Explore") and _lands_of(running, running.hero().id) == 2 \
			and Scenario.card_in_hand(running, running.hero(), "Forest") != -1)


func _lands_of(engine: MmEngine, player_id: int) -> int:
	var lands: int = 0
	for permanent: MmGameObject in engine.game_state().battlefield.objects():
		if permanent.controller_id == player_id \
				and engine.game_state().characteristics_of(permanent).has_card_type(MmCardTypes.CardType.LAND):
			lands += 1
	return lands
