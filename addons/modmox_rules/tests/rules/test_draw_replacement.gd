extends GutTest
## A replacement effect on drawing a card (CR 614.1a, 614.11, engine ADR 0097), as Blood
## Scrivener's: "If you would draw a card while you have no cards in hand, instead you draw
## two cards and you lose 1 life." Scrivener is a 2/1 costing {0} with it. Each draw is its
## own event, its card the top one of the library as it is drawn, so the replacement sees
## the hand as it is before each draw (CR 121.2).

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const Step := MmTurn.Step
const NO_CARDS: Array[MmCardDefinition] = []


func test_with_an_empty_hand_the_draw_step_draws_two_and_loses_a_life() -> void:
	var engine: MmEngine = _cast_on_turn_one([Scenario.scrivener()], 1)
	assert_eq(engine.hero().hand.size(), 0)

	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")

	assert_eq(engine.hero().hand.size(), 2, "CR 614.5: its own two draws are not replaced again.")
	assert_eq(engine.hero().life, 19)


func test_with_a_card_in_hand_a_draw_is_not_replaced() -> void:
	var engine: MmEngine = _cast_on_turn_one([Scenario.scrivener()], 2)
	assert_eq(engine.hero().hand.size(), 1)

	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")

	assert_eq(engine.hero().hand.size(), 2)
	assert_eq(engine.hero().life, 20)


func test_of_two_draws_only_the_first_is_replaced() -> void:
	var divination: MmCardDefinition = Scenario.sorcery("Divination", Scenario.mana_cost(0), [],
		[Scenario.draw_cards(2, Scenario.you())])

	var engine: MmEngine = _cast_on_turn_one([Scenario.scrivener(), divination], 2)

	assert_eq(engine.hero().hand.size(), 3, "Two for the first draw, then one: the hand is no longer empty.")
	assert_eq(engine.hero().life, 19)


func test_two_scriveners_draw_three_and_lose_two() -> void:
	# The second Scrivener replaces the first of the two draws the first one made, while the
	# hand is still empty; each applies only once to a draw (CR 616.2).
	var engine: MmEngine = _cast_on_turn_one([Scenario.scrivener("First"), Scenario.scrivener("Second")], 2)

	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")

	assert_eq(engine.hero().hand.size(), 3)
	assert_eq(engine.hero().life, 18)


func test_a_draw_from_an_empty_library_is_replaced_too() -> void:
	# CR 614.11: it applies even when there is no card to draw.
	var engine: MmEngine = _cast_on_turn_one([Scenario.scrivener()], 1, 1)
	assert_eq(engine.hero().library.size(), 0)

	Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN)

	assert_eq(engine.hero().life, 19, "It lost a life, and then the encounter for drawing from an empty library.")
	assert_true(engine.game_state().is_over)


func test_the_other_players_draws_are_not_replaced() -> void:
	var engine: MmEngine = _cast_on_turn_one([Scenario.scrivener()], 1)
	assert_eq(engine.villain().hand.size(), 0)

	assert_eq(Scenario.play_until_step(engine, 2, Step.PRECOMBAT_MAIN), "")

	assert_eq(engine.villain().hand.size(), 1, "The Hero's Scrivener replaces only the Hero's draws.")
	assert_eq(engine.villain().life, 20)


func test_replays_draw_the_same_cards() -> void:
	var setup: MmEncounterSetup = _setup([Scenario.scrivener()], 1)
	var engine: MmEngine = _find_ready(setup, [Scenario.scrivener()])
	assert_eq(Scenario.play_until_step(engine, 3, Step.PRECOMBAT_MAIN), "")

	var replayed: MmEngine = MmEngine.replay(setup, engine.decision_log())

	assert_eq(replayed.fingerprint(), engine.fingerprint())


## The Hero's main phase of Game Turn 1, having cast [param cast] from an opening hand of
## [param hand_size], from a deck of [param deck_size] cards if given.
func _cast_on_turn_one(cast: Array[MmCardDefinition], hand_size: int, deck_size: int = 0) -> MmEngine:
	return _find_ready(_setup(cast, hand_size, deck_size), cast)


func _setup(cast: Array[MmCardDefinition], hand_size: int, deck_size: int = 0) -> MmEncounterSetup:
	var hero_cards: Array[MmCardDefinition] = Scenario.cycled(cast) if deck_size == 0 else cast.slice(0, deck_size)
	var setup: MmEncounterSetup = Scenario.setup_with(hero_cards, Scenario.cycled([Scenario.creature("Bear", 2, 2)]))
	setup.hero.opening_hand_size = hand_size
	setup.villain.opening_hand_size = 0  # So the Villain's hand is empty as they draw, too.
	return setup


func _find_ready(setup: MmEncounterSetup, cast: Array[MmCardDefinition]) -> MmEngine:
	var engine: MmEngine = Scenario.find_engine(setup, func(started: MmEngine) -> bool:
		if Scenario.play_until_step(started, 1, Step.PRECOMBAT_MAIN) != "":
			return false
		for definition: MmCardDefinition in cast:
			if Scenario.cast_and_resolve(started, definition.name) != "" or Scenario.resolve_stack(started) != "":
				return false
		return true)
	assert_not_null(engine, "No seed dealt the opening hand.")
	return engine
