extends GutTest
## The stack is public (CR 400.2): every view shows each item, its controller and targets.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_both_players_see_the_stack_with_its_targets() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Bolt"))
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_eq(view.stack.size(), 1)
		var item: MmObjectView = view.stack[0]
		assert_eq(item.name, "Bolt")
		assert_eq(item.controller_id, engine.hero().id)
		assert_eq(item.targets.size(), 1)
		assert_true(item.targets[0].equals(MmReference.to_player(engine.villain().id)))


func test_an_ability_on_the_stack_shows_what_it_does_and_what_triggered_it() -> void:
	var chime: MmCardDefinition = Scenario.artifact("Chime", [Scenario.triggered(
		Scenario.at_step(MmTurn.Step.UPKEEP, MmTrigger.Whose.YOU), [Scenario.gain_life(1, Scenario.you())])])
	var setup: MmEncounterSetup = Scenario.combat_setup([chime], [])
	var engine: MmEngine = Scenario.permanents_ready_with(setup, [chime], [], [], [], 3, MmTurn.Step.UPKEEP)

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var item: MmObjectView = engine.view_for(viewer).stack[0]
		assert_true(item.ability is TriggeredAbility)
		assert_eq((item.ability as TriggeredAbility).effects.size(), 1)
		assert_eq(item.triggering_player_id, engine.hero().id, "The Hero's upkeep triggered it.")
		assert_eq(item.triggering_object_id, 0)


func test_a_spell_on_the_stack_has_no_ability_of_its_own_in_the_view() -> void:
	var cards: Array[MmCardDefinition] = Scenario.deck_of(Scenario.basic_land("Mountain"), 20, Scenario.bolt(), 20)
	var engine: MmEngine = Scenario.find_engine(Scenario.setup_with(cards, Scenario.copies(Scenario.vanilla("Card"), 40)),
		func(running: MmEngine) -> bool: return Scenario.ready_in_main(running, 1, 1, "Bolt"))
	Scenario.cast(engine, Scenario.card_in_hand(engine, engine.hero(), "Bolt"), [MmReference.to_player(engine.villain().id)])

	var item: MmObjectView = engine.view_for(engine.hero()).stack[0]

	assert_null(item.ability)
	assert_eq(item.triggering_player_id, MmGameState.NO_PLAYER)
	assert_eq(item.abilities.size(), 1, "Its spell ability is among its characteristics.")
