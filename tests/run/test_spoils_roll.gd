extends GutTest
## The Spoils of a win (milestone 18, ADR 0039), rolled on their own: how much gold and how
## many cards each Rank pays at each Tier, and which cards, drawn evenly from the copies in
## the Villain's deck for that Tier, never its basic lands. Every number here is the spec's,
## written out, never worked out the way the roll works it out.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const LESSER: StageMap.Kind = StageMap.Kind.LESSER
const ELITE: StageMap.Kind = StageMap.Kind.ELITE
const BOSS: StageMap.Kind = StageMap.Kind.BOSS
## Enough rolls that a share is within a few points of its odds.
const MANY: int = 4000


## T5, retuned in milestone 24 (SR9): Lesser gold is 15 to 30 at Tier 1, and every amount in
## that range comes up.
func test_lesser_gold_at_tier_1_is_from_15_to_30() -> void:
	var seen: Dictionary[int, bool] = {}
	for run_seed: int in 800:
		var gold: int = SpoilsRoll.roll(LESSER, 1, _villain(["lightning_bolt"]), RunRandom.new(run_seed)).gold
		assert_between(gold, 15, 30)
		seen[gold] = true
	assert_eq(seen.size(), 16, "every amount from 15 to 30 comes up")


## T5 and SR9: each end of a Rank's range is multiplied by 1.5 at Tier 2: a Boss pays 85 to
## 130 at Tier 1, and 128 (127.5, rounded) to 195 at Tier 2.
func test_boss_gold_at_tier_2_is_from_128_to_195() -> void:
	var lowest: int = 1000
	var highest: int = 0
	for run_seed: int in 1500:
		var gold: int = SpoilsRoll.roll(BOSS, 2, _villain(["lightning_bolt"]), RunRandom.new(run_seed)).gold
		lowest = mini(lowest, gold)
		highest = maxi(highest, gold)
	assert_eq(lowest, 128)
	assert_eq(highest, 195)


## T5 and SR9: an Elite pays 35 to 55 at Tier 1 and, at Tier 5 (three times as much), 105 to
## 165.
func test_elite_gold_at_tiers_1_and_5() -> void:
	for tier: int in [1, 5]:
		var lowest: int = 1000
		var highest: int = 0
		for run_seed: int in 1500:
			var gold: int = SpoilsRoll.roll(ELITE, tier, _villain(["lightning_bolt"]), RunRandom.new(run_seed)).gold
			lowest = mini(lowest, gold)
			highest = maxi(highest, gold)
		assert_eq([lowest, highest], [35, 55] if tier == 1 else [105, 165], "Tier %d" % tier)


## T4: a Lesser win pays 1, 2 or 3 cards, 60%, 30% and 10% of the time.
func test_a_lesser_win_pays_one_card_mostly() -> void:
	assert_shares(_counts(LESSER), {1: 0.6, 2: 0.3, 3: 0.1})


## T4: an Elite win pays 1, 2 or 3 cards, 40%, 40% and 20% of the time.
func test_an_elite_win_pays_one_to_three_cards() -> void:
	assert_shares(_counts(ELITE), {1: 0.4, 2: 0.4, 3: 0.2})


## T4: a Boss win pays 2 or 3 cards, as often as each other, and never 1.
func test_a_boss_win_pays_two_or_three_cards() -> void:
	assert_shares(_counts(BOSS), {2: 0.5, 3: 0.5})


## T6: the cards never include a basic land, even from a deck of nearly nothing else.
func test_the_cards_are_never_basic_lands() -> void:
	var villain: Villain = _villain(["plains", "plains", "swamp", "island", "lightning_bolt", "plains", "forest",
			"mountain", "plains", "ivory_tower"])
	var paid: Dictionary[String, bool] = {}
	for run_seed: int in 300:
		for card: MmRunCard in SpoilsRoll.roll(BOSS, 1, villain, RunRandom.new(run_seed)).cards:
			assert_false(card.base.supertypes.has(MmCardTypes.Supertype.BASIC), card.base.name)
			paid[card.base.name] = true
	assert_eq(paid.keys().size(), 2, "both nonbasic cards are paid")


## T6: a Villain with a setup for each Tier pays from its Tier's setup alone.
func test_a_villain_with_five_setups_pays_from_its_tiers_setup() -> void:
	var files: Array[String] = ["lightning_bolt", "giant_growth", "terror", "fog", "shatter"]
	var villain: Villain = Villain.new()
	for file: String in files:
		villain.setups.append(_villain([file, file, file]).setups[0])
	for run_seed: int in 100:
		for card: MmRunCard in SpoilsRoll.roll(ELITE, 3, villain, RunRandom.new(run_seed)).cards:
			assert_eq(card.base.name, "Terror")


## T7: no one copy is paid twice: a deck with two cards pays exactly those two, whatever
## the roll, and a deck of one card run three times can pay it three times over.
func test_no_copy_is_paid_twice_and_a_small_deck_pays_all_it_has() -> void:
	var pair: Villain = _villain(["lightning_bolt", "terror"])
	var triple: Villain = _villain(["lightning_bolt", "lightning_bolt", "lightning_bolt"])
	var thrice: int = 0
	for run_seed: int in 200:
		var names: Array[String] = []
		for card: MmRunCard in SpoilsRoll.roll(BOSS, 1, pair, RunRandom.new(run_seed)).cards:
			names.append(card.base.name)
		names.sort()
		assert_eq(names, ["Lightning Bolt", "Terror"] as Array[String])
		var from_triple: Array[MmRunCard] = SpoilsRoll.roll(BOSS, 1, triple, RunRandom.new(run_seed)).cards
		assert_true(from_triple.size() == 2 or from_triple.size() == 3)
		if from_triple.size() == 3:
			thrice += 1
	assert_gt(thrice, 0, "three copies of the same card are paid together")


## T3, in part: each card paid is a plain Run Card of its own, the base alone, never the
## Villain's copy.
func test_each_card_is_a_plain_new_run_card() -> void:
	var villain: Villain = _villain(["lightning_bolt"])
	var original: MmRunCard = villain.setups[0].deck[0]
	original.modifications.append(MmModification.new())
	var paid: MmRunCard = SpoilsRoll.roll(LESSER, 1, villain, RunRandom.new(3)).cards[0]
	assert_ne(paid, original)
	assert_eq(paid.base, original.base)
	assert_true(paid.modifications.is_empty())


## T8: each copy is an even ticket: from three Lightning Bolts and a Terror, three cards in
## four paid are Bolts.
func test_every_copy_is_drawn_about_as_often() -> void:
	var villain: Villain = _villain(["lightning_bolt", "lightning_bolt", "terror", "lightning_bolt"])
	var bolts: float = 0.0
	var all: float = 0.0
	for run_seed: int in MANY:
		for card: MmRunCard in SpoilsRoll.roll(LESSER, 1, villain, RunRandom.new(run_seed)).cards:
			all += 1.0
			if card.base.name == "Lightning Bolt":
				bolts += 1.0
	assert_almost_eq(bolts / all, 0.75, 0.03)


## T9: what is drawn from the gold's stream never changes the cards, nor the other way
## round.
func test_the_gold_and_the_cards_draw_from_streams_of_their_own() -> void:
	var villain: Villain = _villain(["lightning_bolt", "giant_growth", "terror", "fog", "shatter", "dark_ritual"])
	for run_seed: int in 50:
		var plain: Spoils = SpoilsRoll.roll(ELITE, 1, villain, RunRandom.new(run_seed))
		var gold_moved: RunRandom = RunRandom.new(run_seed)
		for index: int in 7:
			gold_moved.pick(RunRandom.SPOILS_GOLD, 100)
		var cards_moved: RunRandom = RunRandom.new(run_seed)
		for index: int in 7:
			cards_moved.pick(RunRandom.SPOILS_CARDS, 100)
		assert_eq(_names(SpoilsRoll.roll(ELITE, 1, villain, gold_moved)), _names(plain), "cards, seed %d" % run_seed)
		assert_eq(SpoilsRoll.roll(ELITE, 1, villain, cards_moved).gold, plain.gold, "gold, seed %d" % run_seed)


func _names(spoils: Spoils) -> Array[String]:
	var found: Array[String] = []
	for card: MmRunCard in spoils.cards:
		found.append(card.base.name)
	return found


## The share of MANY rolls at [param rank] that paid each number of cards, from a deck of
## six different cards, more than any roll pays.
func _counts(rank: StageMap.Kind) -> Dictionary[int, float]:
	var villain: Villain = _villain(["lightning_bolt", "giant_growth", "terror", "fog", "shatter", "dark_ritual"])
	var tally: Dictionary[int, float] = {}
	for run_seed: int in MANY:
		var count: int = SpoilsRoll.roll(rank, 1, villain, RunRandom.new(run_seed)).cards.size()
		tally[count] = tally.get(count, 0.0) + 1.0 / MANY
	return tally


## That [param shares] has exactly the keys of [param expected], each within 0.03 of it.
func assert_shares(shares: Dictionary, expected: Dictionary) -> void:
	var keys: Array = shares.keys()
	keys.sort()
	var wanted: Array = expected.keys()
	wanted.sort()
	assert_eq(keys, wanted, "which counts come up")
	for key: Variant in expected:
		assert_almost_eq(float(shares.get(key, 0.0)), float(expected[key]), 0.03, "share of %s" % key)


## A Villain with one setup: a copy of each card named, by file in content/cards/alpha/.
func _villain(files: Array[String]) -> Villain:
	var setup: MmPlayerSetup = MmPlayerSetup.new()
	for file: String in files:
		var run_card: MmRunCard = MmRunCard.new()
		run_card.base = load(ALPHA % file) as MmCardDefinition
		setup.deck.append(run_card)
	var made: Villain = Villain.new()
	made.name = "Test Villain"
	made.setups.append(setup)
	return made
