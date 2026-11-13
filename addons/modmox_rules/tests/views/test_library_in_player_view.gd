extends GutTest
## A Player View lists each library top first, one entry for each card: a card its viewer
## knows as itself, and null for one they do not (A10). A player knows a card they put into
## their library from their hand, until that library is shuffled (CR 701.24).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const KEEP: KeepOrMulliganDecision.Choice = KeepOrMulliganDecision.Choice.KEEP
const MULLIGAN: KeepOrMulliganDecision.Choice = KeepOrMulliganDecision.Choice.MULLIGAN


func test_a_library_has_one_unknown_entry_for_each_card() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())

	for viewer: MmPlayer in [engine.hero(), engine.villain()]:
		var view: MmPlayerView = engine.view_for(viewer)
		for player: MmPlayer in [engine.hero(), engine.villain()]:
			assert_eq(view.libraries[player.id].size(), 33)
			assert_eq(view.libraries[player.id].count(null), 33, "Nobody has seen a card of it.")


func test_a_card_put_on_the_bottom_is_known_to_its_owner_alone() -> void:
	var engine: MmEngine = _engine_with_one_card_on_the_bottom()
	var hero: MmPlayer = engine.hero()
	var bottomed: MmGameObject = hero.library.objects().back()

	var mine: Array = engine.view_for(hero).libraries[hero.id]
	var theirs: Array = engine.view_for(engine.villain()).libraries[hero.id]

	assert_eq(mine.size(), 34)
	assert_eq(mine.count(null), 33, "Only the last entry is known.")
	var seen: MmObjectView = mine.back() as MmObjectView
	assert_eq(seen.id, bottomed.id)
	assert_eq(seen.name, engine.game_state().characteristics_of(bottomed).name)
	assert_eq(theirs.count(null), 34, "The Villain did not see it.")


func test_a_known_card_stays_last_while_cards_are_drawn_from_the_top() -> void:
	var engine: MmEngine = _engine_with_one_card_on_the_bottom()
	var hero: MmPlayer = engine.hero()
	var bottomed: int = (hero.library.objects().back() as MmGameObject).id

	Scenario.play_until_step(engine, 3, MmTurn.Step.PRECOMBAT_MAIN)

	var mine: Array = engine.view_for(hero).libraries[hero.id]
	assert_eq(mine.size(), hero.library.size())
	assert_lt(mine.size(), 34, "The Hero has drawn.")
	assert_eq((mine.back() as MmObjectView).id, bottomed)
	assert_eq(mine.count(null), mine.size() - 1)


func test_a_shuffle_forgets_the_cards_a_mulligan_put_back() -> void:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	var hero: MmPlayer = engine.hero()

	engine.submit(MULLIGAN)

	var mine: Array = engine.view_for(hero).libraries[hero.id]
	assert_eq(mine.count(null), 33, "CR 701.24: the hand went back, known, and was shuffled in.")


func test_a_copy_of_the_game_keeps_what_is_known() -> void:
	var engine: MmEngine = _engine_with_one_card_on_the_bottom()
	var hero: MmPlayer = engine.hero()
	var copy: MmEngine = engine.simulation_copy(hero.id, MmRng.new(1), true)

	assert_eq(engine.view_for(hero).libraries[hero.id].count(null), 33)
	assert_true((hero.library.objects().back() as MmGameObject).is_known_to(hero.id))
	assert_false((hero.library.objects().back() as MmGameObject).is_known_to(engine.villain().id))
	assert_true((copy.hero().library.objects().back() as MmGameObject).is_known_to(hero.id), "A copy keeps it.")


## The Hero mulligans once, keeps six and puts one card on the bottom; the Villain keeps.
func _engine_with_one_card_on_the_bottom() -> MmEngine:
	var engine: MmEngine = MmEngine.start(Scenario.setup())
	for answer: KeepOrMulliganDecision.Choice in [MULLIGAN, KEEP, KEEP]:
		engine.submit(answer)
	var bottom: ChooseCardsToBottomDecision = engine.pending_decision() as ChooseCardsToBottomDecision
	engine.submit([bottom.candidate_ids[3]])
	return engine
