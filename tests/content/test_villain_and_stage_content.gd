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


func test_there_is_a_villain_for_each_content_deck() -> void:
	var names: Array[String] = []
	for villain: Villain in StageDefinition.all_villains():
		names.append(villain.resource_path.get_file().get_basename())

	assert_eq(names, ContentDecks.names())


func test_each_villain_has_a_name_a_sprite_and_its_deck_as_its_one_setup() -> void:
	for villain: Villain in StageDefinition.all_villains():
		var deck: String = villain.resource_path.get_file().get_basename()

		assert_ne(villain.name, "", deck)
		assert_eq(villain.sprite.get_size(), Vector2(32, 32), deck)
		assert_eq(villain.setups.size(), 1, deck)
		assert_eq(villain.setups[0].resource_path, ContentDecks.path_of(deck))
		assert_eq(villain.validate(), "", deck)


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
	for stage: StageDefinition in StageDefinition.all():
		assert_eq(stage.tier, 1, stage.name)
		colors.append(stage.color)

	colors.sort()
	assert_eq(colors, [MmCardTypes.CardColor.WHITE, MmCardTypes.CardColor.BLUE, MmCardTypes.CardColor.BLACK,
		MmCardTypes.CardColor.RED, MmCardTypes.CardColor.GREEN] as Array[MmCardTypes.CardColor])


## T10: every placeholder Stage is valid under ADR 0024.
func test_each_placeholder_stage_has_its_colors_villain_as_boss_and_the_others_one_each() -> void:
	for stage: StageDefinition in StageDefinition.all():
		var boss: String = BOSSES[stage.color]

		assert_eq(stage.validate(), "", stage.name)
		assert_eq(_files(stage.bosses), [boss] as Array[String], stage.name)
		assert_eq(stage.lesser_villains.size(), 1, stage.name)
		assert_eq(stage.elite_villains.size(), 1, stage.name)
		var everyone: Array[Villain] = []
		everyone.append_array(stage.bosses)
		everyone.append_array(stage.elite_villains)
		everyone.append_array(stage.lesser_villains)
		var all: Array[String] = _files(everyone)
		all.sort()
		assert_eq(all, ContentDecks.names(), stage.name)


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
	for stage: StageDefinition in StageDefinition.all():
		if stage != keep:
			assert_null(stage.map_backdrop, stage.name)
			assert_false(stage.has_intro_color(), stage.name)


func _files(villains: Array[Villain]) -> Array[String]:
	var files: Array[String] = []
	for villain: Villain in villains:
		files.append(villain.resource_path.get_file().get_basename())
	return files
