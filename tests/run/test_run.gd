extends GutTest
## The run's state (milestone 16): its Hearts and gold, the Villains the Run Seed draws, the
## Active Deck, and the encounter's setup built from it (ADRs 0025 and 0028).

const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_a_debug_run_starts_with_three_hearts_and_no_gold() -> void:
	var run: Run = Run.debug(7)
	assert_eq(run.hearts, Run.STARTING_HEARTS)
	assert_eq(Run.STARTING_HEARTS, 3)
	assert_eq(run.gold, 0)
	assert_false(run.is_lost())


func test_a_debug_run_owns_every_nonland_card_of_the_content_decks() -> void:
	var run: Run = Run.debug(7)
	var expected: int = 0
	for deck_name: String in EncounterRequest.deck_names():
		var setup: MmPlayerSetup = load(EncounterRequest.DECKS + deck_name + ".tres") as MmPlayerSetup
		for run_card: MmRunCard in setup.deck:
			if not run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC):
				expected += 1
	assert_eq(run.collection.cards().size(), expected)
	for card: DeckbuilderCard in run.collection.cards():
		assert_false(card.is_basic_land(), card.look().name)


func test_a_debug_run_has_a_legal_active_deck_built_from_red_green() -> void:
	var run: Run = Run.debug(7)
	var active: Deck = run.deckbox.active()
	assert_not_null(active)
	assert_eq(run.deckbox.decks().size(), 1)
	var red_green: MmPlayerSetup = load(EncounterRequest.DECKS + "red_green.tres") as MmPlayerSetup
	assert_eq(active.size(), red_green.deck.size())
	assert_true(run.deckbox.is_legal(active))


func test_the_same_run_seed_draws_the_same_villains_in_the_same_order() -> void:
	var first: Run = Run.debug(42)
	var second: Run = Run.debug(42)
	var drawn: Array[String] = []
	for index: int in 8:
		var villain: String = first.next_villain()
		drawn.append(villain)
		assert_eq(second.next_villain(), villain)
	for villain: String in drawn:
		assert_true(EncounterRequest.deck_names().has(villain), villain)


func test_another_run_seed_can_draw_other_villains() -> void:
	var drawn: Dictionary[String, bool] = {}
	for run_seed: int in 20:
		drawn[Run.debug(run_seed).next_villain()] = true
	assert_gt(drawn.size(), 1)


func test_each_encounter_gets_its_own_encounter_seed() -> void:
	var run: Run = Run.debug(5)
	var first: int = run.next_encounter_seed()
	var second: int = run.next_encounter_seed()
	assert_ne(first, second)
	var again: Run = Run.debug(5)
	assert_eq(again.next_encounter_seed(), first)


func test_drawing_a_villain_does_not_change_the_encounter_seeds() -> void:
	var plain: Run = Run.debug(9)
	var busy: Run = Run.debug(9)
	busy.next_villain()
	busy.next_villain()
	assert_eq(busy.next_encounter_seed(), plain.next_encounter_seed())


func test_a_win_keeps_the_hearts() -> void:
	var run: Run = Run.debug(1)
	run.record_encounter(true)
	assert_eq(run.hearts, Run.STARTING_HEARTS)


func test_a_loss_costs_a_heart_and_the_last_one_ends_the_run() -> void:
	var run: Run = Run.debug(1)
	run.record_encounter(false)
	assert_eq(run.hearts, Run.STARTING_HEARTS - 1)
	assert_false(run.is_lost())
	run.record_encounter(false)
	run.record_encounter(false)
	assert_eq(run.hearts, 0)
	assert_true(run.is_lost())
	run.record_encounter(false)
	assert_eq(run.hearts, 0)


func test_the_heros_setup_is_exactly_the_active_deck_with_fresh_basic_lands() -> void:
	var run: Run = Run.debug(3)
	var active: Deck = run.deckbox.active()
	var setup: MmPlayerSetup = run.hero_setup()
	assert_eq(setup.deck.size(), active.size())
	var owned: Array[MmRunCard] = []
	for id: int in active.card_ids:
		owned.append(run.collection.card(id).run_card)
	var lands: Dictionary[String, int] = {}
	for run_card: MmRunCard in setup.deck:
		if owned.has(run_card):
			owned.erase(run_card)
		else:
			assert_true(run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC), run_card.base.name)
			lands[run_card.base.name] = lands.get(run_card.base.name, 0) + 1
	assert_true(owned.is_empty(), "every Run Card of the Deck is in the setup itself")
	assert_eq(lands, active.basic_lands)


func test_each_setup_gets_new_basic_lands() -> void:
	var run: Run = Run.debug(3)
	var first: MmPlayerSetup = run.hero_setup()
	var second: MmPlayerSetup = run.hero_setup()
	for run_card: MmRunCard in first.deck:
		if run_card.base.supertypes.has(MmCardTypes.Supertype.BASIC):
			assert_false(second.deck.has(run_card))


func test_a_modded_card_keeps_its_mods_in_the_setup() -> void:
	var run: Run = Run.debug(3)
	var card: DeckbuilderCard = run.collection.card(run.deckbox.active().card_ids[0])
	var mod: Mod = Mod.new()
	mod.name = "Ember"
	var symbol: AddManaSymbolModification = AddManaSymbolModification.new()
	symbol.symbol = MmMana.Type.RED
	mod.modification = symbol
	card.attach(mod)
	assert_true(run.hero_setup().deck.has(card.run_card))
	assert_true(card.run_card.modifications.has(symbol))


func test_the_villains_setup_is_its_content_deck() -> void:
	var run: Run = Run.debug(3)
	var request: EncounterRequest = run.encounter_request("white_black")
	assert_eq(request.villain_deck, "white_black")
	assert_not_null(request.hero_setup)
	assert_eq(request.setup().hero, request.hero_setup)
	assert_eq(request.setup().villain.deck.size(), (load(EncounterRequest.DECKS + "white_black.tres") as MmPlayerSetup).deck.size())
