extends GutTest
## The battlefield and mana pools are public (CR 400.2, 106.4), so every view shows them.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step


func test_both_players_see_the_battlefield_with_tapped_state_and_controller() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var forest: int = Scenario.play_first_land(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, forest))

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_eq(view.battlefield.size(), 1)
		var seen: MmObjectView = view.battlefield[0]
		assert_eq(seen.id, forest)
		assert_eq(seen.name, "Forest")
		assert_true(seen.is_tapped)
		assert_eq(seen.controller_id, engine.hero().id)


func test_both_players_see_both_mana_pools() -> void:
	var engine: MmEngine = _forests_vs_forests()
	Scenario.play_until_step(engine, 1, Step.PRECOMBAT_MAIN)
	var forest: int = Scenario.play_first_land(engine)
	engine.submit(Scenario.activate_index(engine.pending_decision() as PriorityDecision, forest))

	var view: MmPlayerView = engine.view_for(engine.villain())

	assert_eq(view.mana_pools[engine.hero().id].size(), 1)
	assert_eq((view.mana_pools[engine.hero().id][0] as MmMana).type, MmMana.Type.GREEN)
	assert_eq(view.mana_pools[engine.villain().id].size(), 0)


func _forests_vs_forests() -> MmEngine:
	var forests: Array[MmCardDefinition] = Scenario.copies(Scenario.basic_land("Forest"), 40)
	return MmEngine.start(Scenario.setup_with(forests, forests.duplicate()))
