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


func test_both_players_see_exiled_cards_under_their_owner() -> void:
	# CR 400.2, 406: exile is one shared zone, and public.
	var ogre_card: MmCardDefinition = Scenario.creature("Ogre", 2, 2, [], Scenario.mana_cost(0))
	var bear_card: MmCardDefinition = Scenario.creature("Bear", 2, 2, [], Scenario.mana_cost(0))
	var engine: MmEngine = Scenario.combat_ready([bear_card], [ogre_card], [Scenario.exile_spell("Banish")])
	var ogre: int = Scenario.permanent_named(engine, engine.villain().id, "Ogre")
	Scenario.declare_attackers(engine, [])

	assert_eq(Scenario.cast_and_resolve(engine, "Banish", [MmReference.to_object(ogre)]), "")

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		assert_eq(view.exiles[engine.villain().id].size(), 1, "The Villain's Ogre, exiled by the Hero.")
		assert_eq((view.exiles[engine.villain().id][0] as MmObjectView).name, "Ogre")
		assert_eq(view.exiles[engine.hero().id].size(), 0)
