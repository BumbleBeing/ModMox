extends GutTest
## A card's Frame is worked out from its characteristics alone (ADR 0009), as a stack of
## layers from the card frame guide.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_a_white_creature_gets_the_white_frame_and_white_pt_box() -> void:
	var spec: FrameSpec = FrameSpec.of(CardLook.of_definition(_alpha("savannah_lions")))

	assert_eq(_layers(spec), ["frames/w", "pt/w"])
	assert_eq(spec.key(), "card1:w:pt")


func test_a_colorless_artifact_creature_gets_the_artifact_frame_and_pt_box() -> void:
	var golem: MmCardDefinition = Scenario.creature("Golem", 3, 3, [], Scenario.mana_cost(3))
	golem.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]

	assert_eq(_layers(FrameSpec.of(_look(golem))), ["frames/a", "pt/a"])


func test_a_colorless_noncreature_spell_gets_the_colorless_frame() -> void:
	var spell: MmCardDefinition = Scenario.sorcery("Nothing", Scenario.mana_cost(2), [], [])

	assert_eq(_layers(FrameSpec.of(_look(spell))), ["frames/c"])


func test_a_forest_gets_the_green_land_frame_from_its_mana_ability_not_a_color() -> void:
	var look: CardLook = CardLook.of_definition(_alpha("forest"))

	assert_eq(look.colors, [] as Array[MmCardTypes.CardColor], "A Forest is colorless.")
	assert_eq(_layers(FrameSpec.of(look)), ["lands/g"])


func test_a_land_with_no_colored_mana_gets_the_colorless_land_frame() -> void:
	var land: MmCardDefinition = Scenario.mana_land("Wastes", MmMana.Type.COLORLESS, 1)

	assert_eq(_layers(FrameSpec.of(_look(land))), ["lands/c"])


func test_a_red_white_land_draws_red_left_and_white_right_in_the_fixed_pair_order() -> void:
	# White comes first in WUBRG, but the pair order puts red on the left.
	var land: MmCardDefinition = _land("Plateau", [MmMana.Type.WHITE, MmMana.Type.RED])

	var spec: FrameSpec = FrameSpec.of(_look(land))

	assert_eq(spec.letters, ["r", "w"] as Array[String])
	assert_eq(_layers(spec), [
		"lands/c",
		"lands/r through rules",
		"lands/w through rules ∩ right_half",
		"lands/r through pinline",
		"lands/w through pinline ∩ right_half",
	])


func test_a_two_color_spell_is_gold_with_its_colors_in_the_pinlines_and_rules_box() -> void:
	var spell: MmCardDefinition = Scenario.instant("Charm", Scenario.mana_cost(0, [MmMana.Type.WHITE, MmMana.Type.BLUE]), [], [])

	assert_eq(_layers(FrameSpec.of(_look(spell))), [
		"frames/m",
		"frames/w through rules",
		"frames/u through rules ∩ right_half",
		"frames/w through pinline",
		"frames/u through pinline ∩ right_half",
	])


func test_a_three_color_spell_and_a_three_color_land_are_gold() -> void:
	var spell: MmCardDefinition = Scenario.instant("Charm", Scenario.mana_cost(0, [MmMana.Type.BLACK, MmMana.Type.RED, MmMana.Type.GREEN]), [], [])
	var land: MmCardDefinition = _land("Tri-Land", [MmMana.Type.GREEN, MmMana.Type.WHITE, MmMana.Type.BLUE])

	assert_eq(_layers(FrameSpec.of(_look(spell))), ["frames/m"])
	assert_eq(_layers(FrameSpec.of(_look(land))), ["lands/m"])


func test_pt_boxes_follow_the_color_category() -> void:
	var gold: MmCardDefinition = Scenario.creature("Gold", 2, 2, [], Scenario.mana_cost(0, [MmMana.Type.WHITE, MmMana.Type.BLUE]))
	var land: MmCardDefinition = _land("Land Creature", [MmMana.Type.RED, MmMana.Type.WHITE])
	land.card_types = [MmCardTypes.CardType.LAND, MmCardTypes.CardType.CREATURE]
	var colorless: MmCardDefinition = Scenario.creature("Thing", 1, 1, [], Scenario.mana_cost(1))

	assert_eq(FrameSpec.of(_look(gold)).power_toughness_image(), "pt/m")
	assert_eq(FrameSpec.of(_look(land)).power_toughness_image(), "pt/c", "A two-color land's box is colorless.")
	assert_eq(FrameSpec.of(_look(colorless)).power_toughness_image(), "pt/c")


func test_a_legendary_two_color_creature_puts_both_crowns_above_the_pt_box() -> void:
	var legend: MmCardDefinition = Scenario.creature("Legend", 3, 3, [], Scenario.mana_cost(0, [MmMana.Type.RED, MmMana.Type.WHITE]))
	legend.supertypes = [MmCardTypes.Supertype.LEGENDARY]

	var layers: Array[FrameLayer] = FrameSpec.of(_look(legend)).layers()

	var names: Array = _layers(FrameSpec.of(_look(legend)))
	assert_eq(names.slice(5), ["pt/m", "cover", "crowns/r", "crowns/w through right_half"])
	assert_eq(layers[6].bounds, CardGeometry.CROWN_COVER)
	assert_eq(layers[7].bounds, CardGeometry.CROWN)


func test_crowns_for_colorless_cards_follow_artifact_land_or_neither() -> void:
	var artifact: MmCardDefinition = Scenario.artifact("Relic", [])
	artifact.supertypes = [MmCardTypes.Supertype.LEGENDARY]
	var land: MmCardDefinition = Scenario.mana_land("Ruin", MmMana.Type.COLORLESS, 1)
	land.supertypes = [MmCardTypes.Supertype.LEGENDARY]

	assert_true(_layers(FrameSpec.of(_look(artifact))).has("crowns/a"))
	assert_true(_layers(FrameSpec.of(_look(land))).has("crowns/l"))


func test_a_colored_artifact_gets_its_colors_frame_inside_the_artifact_border() -> void:
	var spec: FrameSpec = FrameSpec.of(_look(_artifact([MmMana.Type.BLUE])))

	assert_eq(_layers(spec), ["frames/u", "frames/a through frame"])


func test_a_colored_artifact_creatures_pt_box_follows_its_color() -> void:
	var golem: MmCardDefinition = _artifact([MmMana.Type.BLUE])
	golem.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	golem.power = 2
	golem.toughness = 2

	assert_eq(_layers(FrameSpec.of(_look(golem))), ["frames/u", "frames/a through frame", "pt/u"])


func test_a_two_color_artifact_is_gold_inside_the_artifact_border_under_its_pt_box_and_crowns() -> void:
	var golem: MmCardDefinition = _artifact([MmMana.Type.WHITE, MmMana.Type.BLUE])
	golem.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	golem.supertypes = [MmCardTypes.Supertype.LEGENDARY]
	golem.power = 2
	golem.toughness = 2

	assert_eq(_layers(FrameSpec.of(_look(golem))), [
		"frames/m",
		"frames/w through rules",
		"frames/u through rules ∩ right_half",
		"frames/w through pinline",
		"frames/u through pinline ∩ right_half",
		"frames/a through frame",
		"pt/m",
		"cover",
		"crowns/w",
		"crowns/u through right_half",
	])


func test_a_three_color_artifact_is_gold_inside_the_artifact_border() -> void:
	var relic: MmCardDefinition = _artifact([MmMana.Type.BLACK, MmMana.Type.RED, MmMana.Type.GREEN])

	assert_eq(_layers(FrameSpec.of(_look(relic))), ["frames/m", "frames/a through frame"])


func test_a_legendary_colored_artifact_gets_its_colors_crown() -> void:
	var relic: MmCardDefinition = _artifact([MmMana.Type.BLUE])
	relic.supertypes = [MmCardTypes.Supertype.LEGENDARY]

	assert_eq(_layers(FrameSpec.of(_look(relic))), ["frames/u", "frames/a through frame", "cover", "crowns/u"])


func test_a_colored_artifact_and_a_spell_of_its_color_are_baked_apart() -> void:
	var spell: MmCardDefinition = Scenario.sorcery("Spell", Scenario.mana_cost(0, [MmMana.Type.BLUE]), [], [])
	var colorless: FrameSpec = FrameSpec.of(_look(Scenario.artifact("Relic", [])))

	assert_eq(FrameSpec.of(_look(_artifact([MmMana.Type.BLUE]))).key(), "card1:u:artifact")
	assert_eq(FrameSpec.of(_look(spell)).key(), "card1:u")
	assert_eq(colorless.key(), "card0::artifact", "A colorless artifact is as it was.")
	assert_eq(_layers(colorless), ["frames/a"])


func test_a_modification_adding_a_color_to_an_artifact_keeps_the_artifact_border() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = _alpha("ankh_of_mishra")
	var add_blue: AddManaSymbolModification = AddManaSymbolModification.new()
	add_blue.symbol = MmMana.Type.BLUE
	run_card.modifications = [add_blue]

	var modified: FrameSpec = FrameSpec.of(CardLook.of_characteristics(MmCharacteristics.printed(run_card.flatten())))

	assert_eq(_layers(modified), ["frames/u", "frames/a through frame"])
	assert_eq(_layers(FrameSpec.of(CardLook.of_definition(_alpha("ankh_of_mishra")))), ["frames/a"], "The base card is unchanged.")


func test_an_artifact_land_keeps_the_land_frame() -> void:
	var land: MmCardDefinition = _land("Vault", [MmMana.Type.BLUE])
	land.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.LAND]

	var spec: FrameSpec = FrameSpec.of(_look(land))

	assert_eq(_layers(spec), ["lands/u"])
	assert_eq(spec.key(), "land1:u")


func test_a_modification_adding_a_second_color_turns_a_mono_frame_gold() -> void:
	var run_card: MmRunCard = MmRunCard.new()
	run_card.base = _alpha("savannah_lions")
	var add_blue: AddManaSymbolModification = AddManaSymbolModification.new()
	add_blue.symbol = MmMana.Type.BLUE
	run_card.modifications = [add_blue]

	var modified: FrameSpec = FrameSpec.of(CardLook.of_characteristics(MmCharacteristics.printed(run_card.flatten())))

	assert_eq(modified.key(), "card2:wu:pt")
	assert_eq(FrameSpec.of(CardLook.of_definition(_alpha("savannah_lions"))).key(), "card1:w:pt", "The base card is unchanged.")


func test_a_cards_frame_is_the_same_from_printed_characteristics_and_from_a_player_view() -> void:
	var bears: MmCardDefinition = _alpha("grizzly_bears")
	var engine: MmEngine = MmEngine.start(Scenario.setup_with(Scenario.copies(bears, 40), Scenario.copies(bears, 40)))

	var from_view: FrameSpec = FrameSpec.of(CardLook.of_view(engine.view_for(engine.hero()).hand[0]))

	assert_eq(from_view.key(), FrameSpec.of(CardLook.of_definition(bears)).key())


func test_mana_cost_pips_come_generic_first_then_each_symbol() -> void:
	assert_eq(ManaSymbols.pip_names(Scenario.mana_cost(2, [MmMana.Type.RED, MmMana.Type.RED])), ["2", "r", "r"] as Array[String])
	assert_eq(ManaSymbols.pip_names(Scenario.mana_cost(0)), ["0"] as Array[String])
	assert_eq(ManaSymbols.pip_names(Scenario.mana_cost(0, [MmMana.Type.GREEN])), ["g"] as Array[String])
	assert_eq(ManaSymbols.pip_names(null), [] as Array[String], "No mana cost is not {0}.")


func _alpha(file_name: String) -> MmCardDefinition:
	return load(ALPHA % file_name) as MmCardDefinition


## A noncreature artifact of [param colors], from the symbols in its cost.
func _artifact(colors: Array[MmMana.Type]) -> MmCardDefinition:
	var relic: MmCardDefinition = Scenario.artifact("Relic", [])
	relic.mana_cost = Scenario.mana_cost(0, colors)
	return relic


func _look(definition: MmCardDefinition) -> CardLook:
	return CardLook.of_characteristics(MmCharacteristics.printed(definition))


func _land(card_name: String, mana: Array[MmMana.Type]) -> MmCardDefinition:
	var land: MmCardDefinition = Scenario.vanilla(card_name)
	land.card_types = [MmCardTypes.CardType.LAND]
	land.mana_cost = null
	var abilities: Array[MmAbility] = []
	for type: MmMana.Type in mana:
		abilities.append(Scenario.tap_for_mana(type, 1))
	land.abilities = abilities
	return land


func _layers(spec: FrameSpec) -> Array:
	var names: Array = []
	for layer: FrameLayer in spec.layers():
		names.append(layer.describe())
	return names
