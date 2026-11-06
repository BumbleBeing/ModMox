extends GutTest
## CR 500.4: mana pools empty at the end of each step and phase.
## CR 502.3: the active player untaps their permanents in their untap step.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_unspent_mana_empties_at_the_end_of_the_step() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var forest: int = Scenario.play_first_land(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, forest))
	assert_eq(engine.hero().mana_pool().size(), 1)

	Scenario.play_until_step(engine, 1, Step.BEGINNING_OF_COMBAT)

	assert_eq(engine.hero().mana_pool().size(), 0)
	var emptied: Array[ManaEmptiedEvent] = []
	for event: MmEvent in engine.event_log():
		if event is ManaEmptiedEvent:
			emptied.append(event as ManaEmptiedEvent)
	assert_eq(emptied.size(), 1, "Only a pool that held mana is emptied.")
	assert_eq(emptied[0].player_id, engine.hero().id)
	assert_eq(emptied[0].mana_lost, 1)


func test_the_untap_step_untaps_only_the_active_players_permanents() -> void:
	var engine: MmEngine = _forests_vs_forests()
	# Game turn 1: the Hero plays and taps a Forest.
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var hero_forest: int = Scenario.play_first_land(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, hero_forest))
	# Game turn 2: the Villain plays and taps a Forest.
	Scenario.play_until_step(engine, 2, Step.PRECOMBAT_MAIN)
	var villain_forest: int = Scenario.play_first_land(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, villain_forest))
	assert_true(engine.game_state().object(hero_forest).is_tapped, "The Hero's Forest stays tapped through the Villain's turn.")

	# Game turn 3: the Hero's untap step.
	Scenario.play_until_step(engine, 3, Step.UPKEEP)

	assert_false(engine.game_state().object(hero_forest).is_tapped)
	assert_true(engine.game_state().object(villain_forest).is_tapped, "Not the Villain's untap step.")


func test_untapped_permanents_produce_no_untap_events() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	Scenario.play_first_land(engine)

	Scenario.play_until_step(engine, 3, Step.UPKEEP)

	for event: MmEvent in engine.event_log():
		assert_false(event is UntapEvent, "Nothing was tapped, so nothing untaps.")


func _forests_vs_forests() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	return MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
