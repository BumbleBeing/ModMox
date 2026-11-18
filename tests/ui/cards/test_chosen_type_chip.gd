extends GutTest
## The Chosen Type Chip (game ADR 0053): a permanent's chosen creature type as a chip
## holding its name, first in the chips' row of its Battlefield Face. Its words never shrink
## below a floor; on a face too small for the whole name, the name is cut with an ellipsis.

const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_a_short_name_is_shown_whole_in_a_chip_as_tall_as_a_keyword_chip() -> void:
	var chip: ChosenTypeChip = ChosenTypeChip.fit("Cat", 32.0, 200.0)

	assert_eq(chip.shown_text, "Cat")
	assert_eq(chip.side, 32.0)
	assert_eq(chip.font_size, 16, "Half the chip's height, as a Keyword Chip's letters are.")
	assert_gt(chip.width, 32.0)
	assert_lt(chip.width, 200.0)


func test_on_a_small_face_the_words_keep_the_floor_size() -> void:
	var chip: ChosenTypeChip = ChosenTypeChip.fit("Cat", 16.0, 200.0)

	assert_eq(chip.font_size, ChosenTypeChip.SMALLEST_FONT_SIZE)
	assert_eq(chip.shown_text, "Cat")


func test_a_name_too_long_for_the_room_is_cut_with_an_ellipsis_and_never_shrunk() -> void:
	var chip: ChosenTypeChip = ChosenTypeChip.fit("Assembly-Worker", 16.0, 70.0)

	assert_true(chip.shown_text.ends_with("…"), chip.shown_text)
	assert_true("Assembly-Worker".begins_with(chip.shown_text.trim_suffix("…")))
	assert_eq(chip.font_size, ChosenTypeChip.SMALLEST_FONT_SIZE)
	assert_lte(chip.width, 70.0)


func test_a_battlefield_face_shows_its_chosen_type_first_in_its_chips_row() -> void:
	var look: CardLook = _look("ivory_tower")
	look.abilities = [FlyingAbility.new(), VigilanceAbility.new()]
	look.chosen_creature_type = "Angel"

	var face: BattlefieldFace = _battlefield(look, 240.0)

	assert_not_null(face.chosen_type_chip())
	assert_eq(face.chosen_type_chip().shown_text, "Angel")
	var drawn: Control = face.find_child("ChosenTypeChip", true, false) as Control
	assert_not_null(drawn)
	var art: Rect2 = BattlefieldFace.art_box(240.0)
	assert_almost_eq(drawn.position.x, art.position.x + KeywordChips.gap(face.chosen_type_chip().side), 0.5, "First in the row.")
	assert_eq(face.chip_letters(), ["F", "V"] as Array[String], "The keywords follow it.")


func test_room_is_always_left_for_one_keyword_chip() -> void:
	var look: CardLook = _look("serra_angel")
	look.chosen_creature_type = "Assembly-Worker"

	var face: BattlefieldFace = _battlefield(look, 100.0)

	assert_eq(face.chip_letters().size(), 1, "One chip, folded into \"+N\".")
	assert_true(face.chosen_type_chip().shown_text.ends_with("…"))


func test_the_chosen_type_takes_room_from_the_keyword_chips() -> void:
	var plain: BattlefieldFace = _battlefield(_look("serra_angel"), 100.0)
	var look: CardLook = _look("serra_angel")
	look.chosen_creature_type = "Assembly-Worker"

	var face: BattlefieldFace = _battlefield(look, 100.0)

	assert_lte(face.chip_letters().size(), plain.chip_letters().size())
	var room: float = BattlefieldFace.chip_room(100.0, true)
	assert_lte(face.chosen_type_chip().width, room)


func test_a_face_with_no_chosen_type_has_no_chip_for_one() -> void:
	var face: BattlefieldFace = _battlefield(_look("ivory_tower"), 140.0)

	assert_null(face.chosen_type_chip())


func _look(file_name: String) -> CardLook:
	return CardLook.of_definition(load(ALPHA % file_name) as MmCardDefinition)


func _battlefield(look: CardLook, height: float) -> BattlefieldFace:
	var face: BattlefieldFace = BattlefieldFace.new()
	add_child_autofree(face)
	face.setup(look, height)
	return face
