extends GutTest
## Milestone 23: an Armor's words are written from its Starting Conditions, one sentence for
## each, never by hand (game ADR 0106). An Emblem's ability is quoted in AbilityText's words.

const ArmorSample := preload("res://tests/support/armor_sample.gd")


## A8: more life, one and several.
func test_more_life_says_how_much_more() -> void:
	assert_eq(StartingConditionText.of(ArmorSample.life(3)), "You start each encounter with 3 more life.")
	assert_eq(StartingConditionText.of(ArmorSample.life(1)), "You start each encounter with 1 more life.")


## A8: less life.
func test_less_life_says_how_much_less() -> void:
	assert_eq(StartingConditionText.of(ArmorSample.life(-2)), "You start each encounter with 2 less life.")


## A8: a smaller opening hand, one card and several.
func test_a_smaller_opening_hand_says_how_many_fewer_cards() -> void:
	assert_eq(StartingConditionText.of(ArmorSample.fewer_cards(1)), "Your opening hand has one fewer card.")
	assert_eq(StartingConditionText.of(ArmorSample.fewer_cards(2)), "Your opening hand has two fewer cards.")


## A8: extra free mulligans, one and several.
func test_extra_free_mulligans_say_how_many() -> void:
	assert_eq(StartingConditionText.of(ArmorSample.mulligans(1)),
		"You start each encounter with an extra free mulligan.")
	assert_eq(StartingConditionText.of(ArmorSample.mulligans(2)),
		"You start each encounter with two extra free mulligans.")


## A8: an Emblem quotes its ability as AbilityText writes it, calling itself "this emblem".
func test_an_emblem_quotes_its_ability() -> void:
	assert_eq(StartingConditionText.of(ArmorSample.emblem(ArmorSample.DIVINERS_BOON)),
		"You get an emblem with \"{2}{U}: Draw two cards. Activate only as a sorcery and only once each game.\"")
	assert_eq(StartingConditionText.of(ArmorSample.emblem(ArmorSample.ELECTROMANCERS_BOON)),
		"You get an emblem with \"{R}: This emblem deals 3 damage to any target. Activate only once each game.\"")


## A8: an Emblem with two abilities quotes each, joined by "and".
func test_an_emblem_with_two_abilities_quotes_each() -> void:
	var both: MmCardDefinition = MmCardDefinition.new()
	both.name = "Both Boons"
	both.abilities.append((load(ArmorSample.DIVINERS_BOON) as MmCardDefinition).abilities[0])
	both.abilities.append((load(ArmorSample.ELECTROMANCERS_BOON) as MmCardDefinition).abilities[0])
	var condition: EmblemStartingCondition = EmblemStartingCondition.new()
	condition.emblem = both

	assert_eq(StartingConditionText.of(condition),
		"You get an emblem with \"{2}{U}: Draw two cards. Activate only as a sorcery and only once each game.\" "
		+ "and \"{R}: This emblem deals 3 damage to any target. Activate only once each game.\"")


## A8: an Armor's words are a sentence for each Starting Condition, in the order authored.
func test_an_armors_words_are_a_sentence_for_each_starting_condition_in_order() -> void:
	var armor: Armor = ArmorSample.armor("Seer's Cuirass", Armor.Slot.CUIRASS,
		[ArmorSample.mulligans(1), ArmorSample.life(-2)])

	assert_eq(StartingConditionText.lines_of(armor.starting_conditions), [
		"You start each encounter with an extra free mulligan.",
		"You start each encounter with 2 less life.",
	] as Array[String])
