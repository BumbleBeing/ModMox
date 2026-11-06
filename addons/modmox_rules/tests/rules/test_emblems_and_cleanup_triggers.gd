extends GutTest
## ADR 0011: Statuses and boss rules enter as Emblems in the command zone, whose abilities
## work there (CR 113.6). CR 514.3a: if anything happens during cleanup, players get
## priority and another cleanup step follows.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const Whose := MmTrigger.Whose


func test_an_affliction_emblem_makes_its_owner_lose_life_each_upkeep() -> void:
	var engine: MmEngine = MmEngine.start(_setup_with_affliction())

	Scenario.play_until_step(engine, 1, Step.UPKEEP)
	assert_eq(Scenario.stacked_abilities(engine).size(), 1)
	Scenario.resolve_stack(engine)
	assert_eq(engine.hero().life, 19)
	Scenario.play_until_game_turn(engine, 4)

	assert_eq(engine.hero().life, 18, "Only on its owner's upkeeps: Game Turns 1 and 3.")
	assert_eq(engine.villain().life, 20)
	assert_eq(Scenario.events_of(engine, LifeLostEvent).size(), 2)


func test_an_emblem_sits_in_the_command_zone_and_both_players_see_it() -> void:
	var engine: MmEngine = MmEngine.start(_setup_with_affliction())

	var emblem: MmGameObject = engine.game_state().command.objects()[0]

	assert_eq(engine.game_state().command.size(), 1)
	assert_eq(emblem.owner_id, engine.hero().id)
	assert_eq(emblem.controller_id, engine.hero().id)
	assert_false(emblem.is_card(), "An Emblem is not a card.")
	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_eq(view.command.size(), 1)
		assert_eq(view.command[0].name, "Forgetful")
		assert_eq(view.command[0].owner_id, engine.hero().id)


func test_an_emblem_cannot_be_targeted() -> void:
	var engine: MmEngine = MmEngine.start(_setup_with_affliction())
	var emblem: MmGameObject = engine.game_state().command.objects()[0]

	var legal: Array[MmReference] = Scenario.any_target().legal_targets(engine.game_state(), MmEffectContext.new(engine.villain().id, 0))

	for candidate: MmReference in legal:
		assert_false(candidate.is_object() and candidate.id == emblem.id)


func test_a_trigger_during_cleanup_gives_priority_and_another_cleanup_step() -> void:
	var grudge: MmCardDefinition = Scenario.artifact("Grudge", [Scenario.triggered(_discarded_trigger(), [Scenario.gain_life(1, Scenario.you())])])
	var setup: MmEncounterSetup = Scenario.setup_with(Scenario.copies(grudge, 40), Scenario.copies(Scenario.vanilla("Card"), 40))
	setup.hero.maximum_hand_size = 5
	var engine: MmEngine = MmEngine.start(setup)
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.cast_and_resolve(engine, "Grudge")

	Scenario.play_until_step(engine, 1, Step.CLEANUP)
	var discard: ChooseCardsToDiscardDecision = engine.pending_decision() as ChooseCardsToDiscardDecision
	assert_not_null(discard)
	engine.submit(discard.candidate_ids.slice(0, 1))

	var decision: PriorityDecision = engine.pending_decision() as PriorityDecision
	assert_not_null(decision, "CR 514.3a: players get priority in this cleanup step.")
	assert_eq(decision.player_id, engine.hero().id)
	assert_eq(Scenario.stacked_abilities(engine).size(), 1)
	Scenario.play_until_game_turn(engine, 2)
	assert_eq(engine.hero().life, 21)
	assert_eq(Scenario.steps_by_game_turn(engine)[1].count(Step.CLEANUP), 2)


func test_a_quiet_cleanup_step_still_gives_no_priority() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	Scenario.play_until_game_turn(engine, 3)

	assert_eq(Scenario.steps_by_game_turn(engine)[1].count(Step.CLEANUP), 1)
	assert_eq(Scenario.steps_by_game_turn(engine)[2].count(Step.CLEANUP), 1)


## "Whenever a card is put into your graveyard from your hand".
func _discarded_trigger() -> ZoneChangeTrigger:
	var trigger: ZoneChangeTrigger = ZoneChangeTrigger.new()
	trigger.any_from_zone = false
	trigger.from_zone = MmZone.Kind.HAND
	trigger.to_zone = MmZone.Kind.GRAVEYARD
	trigger.whose = Whose.YOU
	return trigger


## A Hero with the Affliction "At the beginning of your upkeep, you lose 1 life."
func _setup_with_affliction() -> MmEncounterSetup:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.hero.emblems = [Scenario.emblem("Forgetful", [Scenario.triggered(Scenario.at_step(Step.UPKEEP, Whose.YOU),
		[Scenario.lose_life(1, Scenario.you())])])]
	return setup
