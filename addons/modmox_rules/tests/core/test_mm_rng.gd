extends GutTest
## ADR 0006: seeded randomness with separate Game RNG and AI RNG.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")


func test_the_same_seed_shuffles_identically() -> void:
	var first: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 42))
	var second: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 42))

	assert_eq(Scenario.card_ids(first.hero().library), Scenario.card_ids(second.hero().library))
	assert_eq(Scenario.card_ids(first.hero().hand), Scenario.card_ids(second.hero().hand))


func test_a_different_seed_shuffles_differently() -> void:
	var first: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 42))
	var second: MmEngine = MmEngine.start(Scenario.setup(Scenario.Rule.HERO_STARTS, 43))

	assert_ne(Scenario.card_ids(first.hero().library), Scenario.card_ids(second.hero().library))


func test_using_the_ai_rng_does_not_change_the_game() -> void:
	var setup: MmEncounterSetup = Scenario.setup(Scenario.Rule.HERO_CHOOSES, 42)
	var undisturbed: MmEngine = MmEngine.start(setup)
	undisturbed.submit(ChoosePlayOrDrawDecision.Choice.PLAY)

	var disturbed: MmEngine = MmEngine.start(setup)
	var ai_rng: MmRng = MmRng.for_ai(MmRng.ai_seed_for(setup.encounter_seed), 1, 0)
	for _index: int in 100:
		ai_rng.next_int(10)
	disturbed.submit(ChoosePlayOrDrawDecision.Choice.PLAY)

	assert_eq(disturbed.fingerprint(), undisturbed.fingerprint())


func test_game_and_ai_streams_differ_for_the_same_seed() -> void:
	var game_rng: MmRng = MmRng.for_game(7)
	var ai_rng: MmRng = MmRng.for_ai(MmRng.ai_seed_for(7), 1, 0)

	var game_numbers: Array[int] = []
	var ai_numbers: Array[int] = []
	for _index: int in 10:
		game_numbers.append(game_rng.next_int(1000))
		ai_numbers.append(ai_rng.next_int(1000))

	assert_ne(game_numbers, ai_numbers)


func test_shuffle_in_place_is_a_permutation() -> void:
	var rng: MmRng = MmRng.for_game(3)
	var items: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

	rng.shuffle_in_place(items)

	var sorted: Array[int] = items.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	assert_ne(items, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "Ten items should not come out in order.")


func test_next_int_stays_in_range() -> void:
	var rng: MmRng = MmRng.for_game(5)

	for _index: int in 200:
		assert_between(rng.next_int(3), 0, 2)


func test_each_ai_decision_gets_its_own_stream() -> void:
	var seed: int = MmRng.ai_seed_for(7)

	var again: Array[int] = [MmRng.for_ai(seed, 1, 5).next_int(1000000), MmRng.for_ai(seed, 1, 5).next_int(1000000)]
	var other_player: int = MmRng.for_ai(seed, 0, 5).next_int(1000000)
	var other_decision: int = MmRng.for_ai(seed, 1, 6).next_int(1000000)

	assert_eq(again[0], again[1], "The same decision gets the same numbers.")
	assert_ne(other_player, again[0], "Two AI players never share numbers.")
	assert_ne(other_decision, again[0])
