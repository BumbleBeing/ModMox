extends GutTest
## The authored Villains and placeholder Stages (ADR 0024, milestone 17): a Villain for
## each deck in content/decks/, and a Tier 1 Stage of each color whose Boss is the Villain
## with that color, each Villain in at most one list of a Stage.

const VILLAINS: String = "res://content/villains/"
const STAGES: String = "res://content/stages/"
## The Villain each placeholder Stage has as its Boss, by the Stage's color.
const BOSSES: Dictionary[MmCardTypes.CardColor, String] = {
	MmCardTypes.CardColor.WHITE: "white_black", MmCardTypes.CardColor.BLACK: "white_black",
	MmCardTypes.CardColor.BLUE: "blue_red", MmCardTypes.CardColor.RED: "blue_red",
	MmCardTypes.CardColor.GREEN: "red_green",
}


## Every deck in content/decks/ is a setup of exactly one Villain. A Villain's setups are its
## decks: one named after it, or one for each Tier, named <villain>_<tier>, in Tier order. A
## Villain whose Tier decks are not all written yet is invalid, so no Stage can list it.
func test_every_content_deck_is_a_setup_of_one_villain() -> void:
	var decks: Array[String] = []
	for villain: Villain in ContentStages.all_villains():
		var file: String = villain.resource_path.get_file().get_basename()
		for index: int in villain.setups.size():
			var path: String = villain.setups[index].resource_path
			var deck: String = path.get_file().get_basename()

			assert_eq(path, ContentDecks.path_of(deck), file)
			assert_true(deck == "%s_%d" % [file, index + 1] or (deck == file and villain.setups.size() == 1),
				"%s plays %s as setup %d" % [file, deck, index + 1])
			decks.append(deck)

	decks.sort()
	assert_eq(decks, ContentDecks.names())


func test_each_villain_has_a_name_a_sprite_and_at_least_one_setup() -> void:
	for villain: Villain in ContentStages.all_villains():
		var file: String = villain.resource_path.get_file().get_basename()

		assert_ne(villain.name, "", file)
		assert_eq(villain.sprite.get_size(), Vector2(32, 32), file)
		assert_between(villain.setups.size(), 1, Villain.TIERS, file)


func test_a_villain_with_one_setup_plays_it_at_every_tier() -> void:
	var villain: Villain = load(VILLAINS + "red_green.tres")

	for tier: int in range(1, 6):
		assert_eq(villain.setup_for_tier(tier), villain.setups[0])


func test_a_villain_with_five_setups_plays_one_for_each_tier() -> void:
	var villain: Villain = Villain.new()
	for index: int in 5:
		villain.setups.append(MmPlayerSetup.new())

	assert_eq(villain.setup_for_tier(3), villain.setups[2])
	assert_eq(villain.validate(), "")


func test_a_villain_with_another_number_of_setups_is_invalid() -> void:
	var villain: Villain = Villain.new()
	villain.setups.append(MmPlayerSetup.new())
	villain.setups.append(MmPlayerSetup.new())

	assert_ne(villain.validate(), "")


func test_there_is_one_tier_one_placeholder_stage_of_each_color() -> void:
	var colors: Array[MmCardTypes.CardColor] = []
	for stage: StageDefinition in ContentStages.all():
		assert_eq(stage.tier, 1, stage.name)
		colors.append(stage.color)

	colors.sort()
	assert_eq(colors, [MmCardTypes.CardColor.WHITE, MmCardTypes.CardColor.BLUE, MmCardTypes.CardColor.BLACK,
		MmCardTypes.CardColor.RED, MmCardTypes.CardColor.GREEN] as Array[MmCardTypes.CardColor])


## T10: every Stage is valid under ADR 0024, and has its color's placeholder Villain as a
## Boss. Villains added since are listed wherever they were put.
func test_each_stage_is_valid_with_its_colors_placeholder_villain_as_a_boss() -> void:
	for stage: StageDefinition in ContentStages.all():
		var boss: String = BOSSES[stage.color]

		assert_eq(stage.validate(), "", stage.name)
		assert_has(_files(stage.bosses), boss, stage.name)


func test_a_stage_with_a_villain_in_two_lists_is_invalid() -> void:
	var stage: StageDefinition = load(STAGES + "placeholder_green.tres").duplicate() as StageDefinition
	stage.elite_villains = stage.bosses.duplicate()

	assert_ne(stage.validate(), "")


func test_a_stage_with_no_boss_is_invalid() -> void:
	var stage: StageDefinition = load(STAGES + "placeholder_green.tres").duplicate() as StageDefinition
	stage.bosses = []

	assert_ne(stage.validate(), "")


func test_a_stages_color_names_its_backdrop() -> void:
	var stage: StageDefinition = load(STAGES + "placeholder_green.tres")

	assert_eq(stage.backdrop(), "green")
	assert_true(Backdrops.has(stage.backdrop()))


## ADR 0038: Kitty Keep, the white Tier 1 Stage, has its Map Backdrop and Intro color; no
## other Stage has either yet.
func test_kitty_keep_has_a_map_backdrop_and_an_intro_color() -> void:
	var keep: StageDefinition = load(STAGES + "kitty_keep.tres")

	assert_eq(keep.name, "Kitty Keep")
	assert_eq(keep.color, MmCardTypes.CardColor.WHITE)
	assert_eq(keep.tier, 1)
	assert_not_null(keep.map_backdrop)
	assert_eq(Vector2i(keep.map_backdrop.get_size()), StageMapLayout.MAP_BACKDROP_SIZE)
	assert_eq(keep.map_backdrop.resource_path.get_base_dir(), "res://ui/sprites/backgrounds/stage_maps")
	assert_true(keep.has_intro_color())
	for stage: StageDefinition in ContentStages.all():
		if stage != keep:
			assert_null(stage.map_backdrop, stage.name)
			assert_false(stage.has_intro_color(), stage.name)


## ADR 0038: Kitty Keep has six Scenery Kinds, all valid: three still at 4 and three
## cats of different colors that flick their tails at 3.
func test_kitty_keep_has_six_valid_scenery_kinds() -> void:
	var keep: StageDefinition = load(STAGES + "kitty_keep.tres")
	var names: Array[String] = []
	for kind: SceneryKind in keep.scenery:
		assert_eq(kind.validate(), "", kind.name)
		names.append(kind.name)
		var is_creature: bool = kind.frames.size() > 1
		assert_eq(kind.scale, 3 if is_creature else 4, kind.name)

	assert_eq(names, ["Tree", "Flower Bush", "Hay Bale", "Ginger Cat", "Gray Cat", "Black Cat"] as Array[String])
	assert_not_null(keep.scenery_ground, "Its Scenery keeps off the castle and the sky.")
	assert_eq(Vector2i(keep.scenery_ground.get_size()), StageMapLayout.MAP_BACKDROP_SIZE)


func _files(villains: Array[Villain]) -> Array[String]:
	var files: Array[String] = []
	for villain: Villain in villains:
		files.append(villain.resource_path.get_file().get_basename())
	return files
