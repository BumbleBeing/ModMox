extends GutTest
## An Emblem drawn in full (ADR 0033, A533): art in a border of its own, name, the type
## line "Emblem", rules text with any Spent ability gray and marked "(used)", and the
## artist's credit. With no art it shows a gray box and no credit.


func test_an_emblem_with_no_art_shows_a_gray_box_and_no_credit() -> void:
	var face: EmblemFace = _face(_look("emblems/electromancers_boon", []))

	assert_false(face.has_art())
	assert_eq(face.no_art_box().color, EmblemFace.NO_ART_COLOR)
	assert_eq(face.credit_text(), "")
	assert_eq(face.name_text(), "Electromancer's Boon")
	assert_eq(face.type_line_text(), "Emblem")


func test_an_emblem_that_borrows_a_cards_art_credits_its_artist() -> void:
	var face: EmblemFace = _face(_look("howling_mine", []))

	assert_true(face.has_art())
	assert_null(face.no_art_box())
	assert_eq(face.credit_text(), "Illus. " + ArtLibrary.shared().artist("howling_mine"))
	assert_ne(ArtLibrary.shared().artist("howling_mine"), "")


func test_a_spent_ability_is_gray_and_marked_used() -> void:
	var look: CardLook = _look("", [0])

	var face: EmblemFace = _face(look)

	assert_eq(face.rules_text(), "{R}: This emblem deals 3 damage to any target. Activate only once each game. (used)")
	assert_true(EmblemFace.rules_bbcode(look).begins_with("[color=#%s]" % EmblemFace.USED_INK.to_html(false)))
	assert_false(EmblemFace.rules_bbcode(_look("", [])).contains("[color"))


func test_it_is_scaled_from_its_design_to_the_height_it_is_given() -> void:
	var face: EmblemFace = _face(_look("", []), 1086.0)

	assert_eq(face.size, EmblemFace.DESIGN * 2.0)
	assert_eq(face.no_art_box().size, Vector2(688, 500))


func _face(look: CardLook, height: float = 543.0) -> EmblemFace:
	var face: EmblemFace = EmblemFace.new()
	add_child_autofree(face)
	face.setup(look, height)
	return face


func _look(art_key: String, spent: Array[int]) -> CardLook:
	var definition: MmCardDefinition = load("res://content/emblems/electromancers_boon.tres")
	var seen: MmObjectView = MmObjectView.new()
	seen.name = definition.name
	seen.abilities = definition.abilities
	seen.spent_ability_indexes = spent
	return CardLook.of_held(seen, art_key, CardLook.Kind.EMBLEM)
