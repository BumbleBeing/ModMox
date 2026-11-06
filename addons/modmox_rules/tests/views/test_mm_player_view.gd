extends GutTest
## A Player View shows only what that player may legally see (A10).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_a_player_sees_their_own_hand() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	var view: MmPlayerView = engine.view_for(engine.hero())

	var seen_ids: Array[int] = []
	var seen_names: Array[String] = []
	for object: MmObjectView in view.hand:
		seen_ids.append(object.id)
		seen_names.append(object.name)
	assert_eq(seen_ids, engine.hero().hand.object_ids())
	assert_eq(seen_names, Scenario.names(engine, engine.hero().hand))


func test_the_villain_sees_only_the_size_of_the_heros_hand() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	var view: MmPlayerView = engine.view_for(engine.villain())

	assert_eq(view.hand_sizes[engine.hero().id], 7)
	for object: MmObjectView in view.hand:
		assert_false(engine.hero().hand.object_ids().has(object.id), "The Hero's cards must not appear.")


func test_no_view_reveals_library_contents() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		var visible_ids: Array[int] = []
		for object: MmObjectView in view.hand:
			visible_ids.append(object.id)
		for player: MmPlayer in [engine.hero(), engine.villain()]:
			assert_eq(view.library_sizes[player.id], 33)
			for id: int in player.library.object_ids():
				assert_false(visible_ids.has(id), "Library cards must never be visible.")


func test_a_view_shows_both_life_totals() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.villain.starting_life = 30
	var engine: MmEngine = MmEngine.start(setup)

	var view: MmPlayerView = engine.view_for(engine.hero())

	assert_eq(view.viewer_id, engine.hero().id)
	assert_eq(view.life_totals[engine.hero().id], 20)
	assert_eq(view.life_totals[engine.villain().id], 30)
