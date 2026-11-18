extends GutTest
## ADR 0004: a Run Card is a base Card Definition plus ordered Modifications.


func test_run_card_without_modifications_flattens_to_a_copy_of_its_base() -> void:
	var run_card: MmRunCard = _run_card("Goblin")

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq(flattened.name, "Goblin")
	assert_ne(flattened, run_card.base, "Flattening must produce a private copy.")


func test_two_name_changes_flatten_to_the_second_name() -> void:
	var run_card: MmRunCard = _run_card("Goblin")
	run_card.modifications.append(_rename("Hobgoblin"))
	run_card.modifications.append(_rename("Goblin King"))

	assert_eq(run_card.flatten().name, "Goblin King")


func test_flattening_never_changes_the_base_definition() -> void:
	var run_card: MmRunCard = _run_card("Goblin")
	run_card.modifications.append(_rename("Hobgoblin"))

	run_card.flatten()

	assert_eq(run_card.base.name, "Goblin")


func test_flattened_copy_is_independent_of_later_edits() -> void:
	var run_card: MmRunCard = _run_card("Goblin")
	var flattened: MmCardDefinition = run_card.flatten()

	flattened.name = "Changed"

	assert_eq(run_card.base.name, "Goblin")


func test_flattening_copies_the_cards_own_parts_and_shares_a_token_definition_file() -> void:
	var cat: MmCardDefinition = load("res://content/tokens/cat_1_1_white.tres") as MmCardDefinition
	var create: CreateTokenEffect = CreateTokenEffect.new()
	create.token = cat
	var spell: SpellAbility = SpellAbility.new()
	spell.effects = [create] as Array[MmEffect]
	var run_card: MmRunCard = _run_card("Kitten")
	run_card.base.abilities = [spell] as Array[MmAbility]

	var flattened: MmCardDefinition = run_card.flatten()

	var copied: SpellAbility = flattened.abilities[0] as SpellAbility
	assert_ne(copied, spell, "The card's own ability is a private copy.")
	assert_eq((copied.effects[0] as CreateTokenEffect).token, cat, "ADR 0044: the Token Definition is shared, file and all.")


func test_a_flattened_card_points_to_its_original() -> void:
	var run_card: MmRunCard = _run_card("Goblin")
	run_card.modifications.append(_rename("Hobgoblin"))

	var flattened: MmCardDefinition = run_card.flatten()

	assert_eq(flattened.original, run_card.base, "The base itself, not a copy of it.")
	assert_eq(flattened.original.name, "Goblin")
	assert_null(run_card.base.original, "A card that was never flattened has no Original.")


func _run_card(card_name: String) -> MmRunCard:
	var definition: MmCardDefinition = MmCardDefinition.new()
	definition.name = card_name
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = definition
	return run_card


func _rename(new_name: String) -> ChangeNameModification:
	var modification: ChangeNameModification = ChangeNameModification.new()
	modification.new_name = new_name
	return modification
