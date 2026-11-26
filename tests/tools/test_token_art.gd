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


func test_a_card_makes_the_tokens_an_effect_it_may_pay_for_creates() -> void:
	# Myrsmith's: "you may pay {1}. If you do, create ...", and an "if" around a "you may".
	var cat: MmCardDefinition = load(CAT) as MmCardDefinition
	var cat_beast: MmCardDefinition = load(CAT_BEAST) as MmCardDefinition
	var paying: MayPayEffect = Scenario.may_pay_mana(Scenario.mana_cost(1), Scenario.create_tokens(cat))
	var maybe: IfEffect = Scenario.if_then(LifeAtLeastStartingCondition.new(), Scenario.may(Scenario.create_tokens(cat_beast)))
	var smith: MmCardDefinition = Scenario.creature("Smith", 2, 1, [
		Scenario.triggered(Scenario.casts(Scenario.of_type(MmCardTypes.CardType.ARTIFACT), MmTrigger.Whose.YOU), [paying, maybe])])

	assert_eq(TokenArt.tokens_made_by(smith), [cat, cat_beast] as Array[MmCardDefinition])


func test_a_card_makes_the_tokens_its_adventure_creates() -> void:
	# Conceited Witch's Price of Beauty creates its Wicked Role (engine ADR 0078).
	var cat: MmCardDefinition = load(CAT) as MmCardDefinition
	var guide: MmCardDefinition = Scenario.adventurer()
	var make: SpellAbility = SpellAbility.new()
	make.effects = [Scenario.create_tokens(cat)]
	guide.adventure.abilities = [make]

	assert_eq(TokenArt.tokens_made_by(guide), [cat] as Array[MmCardDefinition])


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


func test_a_role_token_part_is_found_by_its_face_named_without_the_word_role() -> void:
	# Scryfall prints the Wicked Role as one face of a flip token, "Wicked // Cursed".
	var printing: Dictionary = {"all_parts": [
		{"component": "combo_piece", "name": "Conceited Witch // Price of Beauty", "uri": "card"},
		{"component": "token", "name": "Wicked // Cursed", "uri": "roles"},
	]}
	var wicked: MmCardDefinition = load("res://content/tokens/wicked_role.tres") as MmCardDefinition
	var monster: MmCardDefinition = MmCardDefinition.new()
	monster.name = "Monster Role"
	monster.subtypes = ["Aura", "Role"]

	assert_eq(TokenArt.part_for(printing, wicked).get("uri", ""), "roles")
	assert_eq(TokenArt.part_for(printing, monster), {}, "No face is a Monster.")


func test_a_flip_tokens_art_is_cut_to_the_art_panel_of_its_upper_face() -> void:
	# Scryfall's art crop of a flip token is its whole upper face, rules text and all; its
	# picture is the panel at its left, below the type line.
	var face: Image = Image.create(684, 570, false, Image.FORMAT_RGB8)
	face.fill(Color.WHITE)
	face.fill_rect(Rect2i(0, 66, 237, 305), Color.RED)

	var panel: Image = TokenArt.art_of({"layout": "flip"}, face)

	assert_eq(panel.get_size(), Vector2i(237, 305))
	assert_eq(panel.get_pixel(0, 0), Color.RED)
	assert_eq(panel.get_pixel(236, 304), Color.RED)
	assert_eq(TokenArt.art_of({"layout": "token"}, face), face, "Any other token's art crop is its art.")

