extends GutTest
## A Battlefield Face shows a chip for each keyword, in a fixed order, along the bottom of
## its art. They are sized so that at least two always fit, and the last one that fits
## becomes "+N" when they run out of room.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_serra_angels_chips_are_flying_then_vigilance() -> void:
	var look: CardLook = CardLook.of_definition(_alpha("serra_angel"))

	assert_eq(_letters(KeywordChips.chips_for(look.abilities)), ["F", "V"])


func test_white_knights_protection_chip_carries_black() -> void:
	var chips: Array[KeywordChip] = KeywordChips.chips_for(CardLook.of_definition(_alpha("white_knight")).abilities)

	assert_eq(_letters(chips), ["FS", "P"])
	assert_true(chips[1].has_protection_color)
	assert_eq(chips[1].protection_color, MmCardTypes.CardColor.BLACK)


func test_abilities_that_are_not_keywords_get_no_chip() -> void:
	assert_eq(KeywordChips.chips_for(CardLook.of_definition(_alpha("prodigal_sorcerer")).abilities).size(), 0)


func test_a_granted_keyword_gets_a_chip_until_it_ends() -> void:
	# Goblin Balloon Brigade: "{R}: This creature gains flying until end of turn." Free here.
	var brigade: MmCardDefinition = _alpha("goblin_balloon_brigade").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MmCardDefinition
	brigade.mana_cost = Scenario.mana_cost(0)
	(brigade.abilities[0] as ActivatedAbility).mana_cost = null
	var engine: MmEngine = Scenario.combat_ready([brigade], [])
	var id: int = Scenario.permanent_named(engine, engine.hero().id, "Goblin Balloon Brigade")
	assert_eq(_letters(_chips_of(engine, id)), [], "No flying yet.")
	Scenario.declare_attackers(engine, [id])

	assert_eq(Scenario.activate(engine, id), "")
	Scenario.resolve_stack(engine)

	assert_eq(_letters(_chips_of(engine, id)), ["F"])
	Scenario.play_until_game_turn(engine, engine.view_for(engine.hero()).game_turn + 1)
	assert_eq(_letters(_chips_of(engine, id)), [], "Gone at end of turn.")


func test_at_least_two_chips_fit_on_a_battlefield_face_of_any_size() -> void:
	for height: int in range(70, 401, 10):
		for is_creature: bool in [true, false]:
			var room: float = BattlefieldFace.chip_room(height, is_creature)

			var chip: float = KeywordChips.chip_size(height, room)

			assert_gte(KeywordChips.fit_count(chip, room), 2, "Height %d." % height)
			assert_eq(fmod(chip, 16.0), 0.0, "A whole multiple of 16 px.")


func test_a_cramped_face_sizes_its_chips_so_two_still_fit() -> void:
	# Room for two 32 px chips with their gaps, but not two 48 px ones.
	var chip: float = KeywordChips.chip_size(400.0, 80.0)

	assert_eq(chip, 32.0)
	assert_eq(KeywordChips.fit_count(chip, 80.0), 2)


func test_seven_keywords_with_room_for_two_show_one_chip_and_plus_six() -> void:
	var chips: Array[KeywordChip] = []
	for letters: String in ["R", "V", "H", "DT", "FS", "T", "I"]:
		var chip: KeywordChip = KeywordChip.new()
		chip.letters = letters
		chips.append(chip)

	assert_eq(_letters(KeywordChips.shown(chips, 2)), ["R", "+6"])


func test_chips_that_fit_are_all_shown() -> void:
	var chips: Array[KeywordChip] = KeywordChips.chips_for(CardLook.of_definition(_alpha("serra_angel")).abilities)

	assert_eq(_letters(KeywordChips.shown(chips, 2)), ["F", "V"])


func test_a_raised_power_and_toughness_print_green_and_the_base_is_unchanged() -> void:
	var growth: MmCardDefinition = Scenario.free_copy(_alpha("giant_growth"))
	var engine: MmEngine = Scenario.combat_ready([Scenario.free_copy(_alpha("grizzly_bears"))], [], [growth])
	var bears: int = Scenario.permanent_named(engine, engine.hero().id, "Grizzly Bears")
	Scenario.declare_attackers(engine, [bears])

	assert_eq(Scenario.cast_and_resolve(engine, "Giant Growth", [MmReference.to_object(bears)]), "")

	var look: CardLook = CardLook.of_view(_view_of(engine, bears))
	assert_eq(look.power_toughness_texts(), ["5", "/", "5"] as Array[String])
	assert_eq(look.power_toughness_colors(), [CardLook.RAISED, Color.BLACK, CardLook.RAISED] as Array[Color])
	assert_eq([look.base_power, look.base_toughness], [2, 2])


func test_a_lowered_number_prints_red_and_a_variable_one_prints_a_star() -> void:
	var look: CardLook = CardLook.new()
	look.power = 1
	look.base_power = 3
	look.is_toughness_variable = true

	assert_eq(look.power_toughness_texts(), ["1", "/", "*"] as Array[String])
	assert_eq(look.power_toughness_colors()[0], CardLook.LOWERED)


func _alpha(file_name: String) -> MmCardDefinition:
	return load(ALPHA % file_name) as MmCardDefinition


func _view_of(engine: MmEngine, id: int) -> MmObjectView:
	for view: MmObjectView in engine.view_for(engine.hero()).battlefield:
		if view.id == id:
			return view
	return null


func _chips_of(engine: MmEngine, id: int) -> Array[KeywordChip]:
	return KeywordChips.chips_for(CardLook.of_view(_view_of(engine, id)).abilities)


func _letters(chips: Array[KeywordChip]) -> Array:
	var letters: Array = []
	for chip: KeywordChip in chips:
		letters.append(chip.letters)
	return letters
