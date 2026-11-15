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
