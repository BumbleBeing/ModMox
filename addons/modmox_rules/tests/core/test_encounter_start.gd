extends GutTest
## Starting an encounter from its Encounter Setup.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_each_library_holds_one_game_object_per_card_with_unique_ids() -> void:
	# With HERO_CHOOSES, the play/draw choice comes before any shuffle or draw.
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES))

	var hero_ids: Array[int] = engine.hero().library.object_ids()
	var villain_ids: Array[int] = engine.villain().library.object_ids()

	assert_eq(hero_ids.size(), 40)
	assert_eq(villain_ids.size(), 40)
	var all_ids: Dictionary[int, bool] = {}
	for id: int in hero_ids + villain_ids:
		all_ids[id] = true
	assert_eq(all_ids.size(), 80, "Every Game Object needs its own ID.")


func test_libraries_start_in_deck_order_before_shuffling() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_CHOOSES, 1, 3, 3))

	assert_eq(Scenario.names(engine, engine.hero().library), ["Hero Card 1", "Hero Card 2", "Hero Card 3"])


func test_life_totals_and_opening_hand_sizes_come_from_the_setup() -> void:
	var setup: MmEncounterSetup = Scenario.setup()
	setup.villain.starting_life = 30
	setup.hero.opening_hand_size = 6

	var engine: MmEngine = MmEngine.start(setup)

	assert_eq(engine.hero().life, 20)
	assert_eq(engine.villain().life, 30)
	assert_eq(engine.hero().hand.size(), 6)
	assert_eq(engine.villain().hand.size(), 7)


func test_modified_run_cards_enter_the_game_with_their_modifications() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.HERO_CHOOSES, 1, 1, 1)
	var rename: ChangeNameModification = ChangeNameModification.new()
	rename.new_name = "Upgraded Card"
	setup.hero.deck[0].modifications.append(rename)

	var engine: MmEngine = MmEngine.start(setup)

	assert_eq(Scenario.names(engine, engine.hero().library), ["Upgraded Card"])
	assert_eq(setup.hero.deck[0].base.name, "Hero Card 1", "The base definition must stay untouched.")


func test_every_game_object_knows_its_run_card() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.HERO_CHOOSES, 1, 2, 2)

	var engine: MmEngine = MmEngine.start(setup)

	var first: MmGameObject = engine.hero().library.objects()[0]
	assert_eq(engine.game_state().run_card_of(first), setup.hero.deck[0])


func test_all_seven_zones_exist() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	var state: MmGameState = engine.game_state()

	for player: MmPlayer in [engine.hero(), engine.villain()]:
		assert_eq(player.library.kind, MmZone.Kind.LIBRARY)
		assert_eq(player.hand.kind, MmZone.Kind.HAND)
		assert_eq(player.graveyard.kind, MmZone.Kind.GRAVEYARD)
	assert_eq(state.battlefield.kind, MmZone.Kind.BATTLEFIELD)
	assert_eq(state.stack.kind, MmZone.Kind.STACK)
	assert_eq(state.exile.kind, MmZone.Kind.EXILE)
	assert_eq(state.command.kind, MmZone.Kind.COMMAND)
