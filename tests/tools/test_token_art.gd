extends GutTest
## TokenArt (game ADR 0045): which tokens a card makes, and which of its first printing's
## related parts is the token whose art they use.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const CAT: String = "res://content/tokens/cat_1_1_white.tres"
const CAT_BEAST: String = "res://content/tokens/cat_beast_2_2_white.tres"


func test_a_card_makes_each_token_its_abilities_create_once() -> void:
	var cat: MmCardDefinition = load(CAT) as MmCardDefinition
	var parent: MmCardDefinition = Scenario.creature("Parent", 2, 2, [
		Scenario.triggered(Scenario.enters(IsSourceFilter.new()), [Scenario.create_tokens(cat)]),
		Scenario.triggered(Scenario.dies(IsSourceFilter.new()), [Scenario.create_tokens(cat, 2)])])

	assert_eq(TokenArt.tokens_made_by(parent), [cat] as Array[MmCardDefinition])
	assert_eq(TokenArt.key_of(cat), "tokens/cat_1_1_white")


func test_a_card_makes_the_tokens_its_modes_create() -> void:
	var cat_beast: MmCardDefinition = load(CAT_BEAST) as MmCardDefinition
	var retreat: MmCardDefinition = Scenario.enchantment("Retreat", [Scenario.modal_triggered(
		Scenario.enters(Scenario.of_type(MmCardTypes.CardType.LAND), MmTrigger.Whose.YOU), [
			Scenario.ability_mode([], [Scenario.create_tokens(cat_beast)]),
			Scenario.ability_mode([], [Scenario.gain_life(1, Scenario.you())]),
		])])

	assert_eq(TokenArt.tokens_made_by(retreat), [cat_beast] as Array[MmCardDefinition], "ADR 0046: a mode's effects count too.")
	assert_eq(TokenArt.key_of(cat_beast), "tokens/cat_beast_2_2_white")


func test_a_token_made_in_code_has_no_file_and_no_art() -> void:
	var spell: MmCardDefinition = Scenario.free_tokens("Kitten", Scenario.cat())

	assert_eq(TokenArt.tokens_made_by(spell).size(), 0)


func test_the_token_part_is_found_by_its_name_without_the_word_token() -> void:
	var printing: Dictionary = {"all_parts": [
		{"component": "combo_piece", "name": "Prideful Parent", "uri": "card"},
		{"component": "token", "name": "Cat Warrior", "uri": "warrior"},
		{"component": "token", "name": "Cat", "uri": "cat"},
	]}

	assert_eq(TokenArt.part_for(printing, load(CAT) as MmCardDefinition).get("uri", ""), "cat")
	assert_eq(TokenArt.part_for({}, load(CAT) as MmCardDefinition), {})
