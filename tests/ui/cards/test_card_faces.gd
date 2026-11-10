extends GutTest
## A Card Face draws a card in full; a Battlefield Face draws a permanent with its border,
## name, art, P/T box and keyword chips, turned sideways and darkened when tapped.

const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_an_untapped_battlefield_face_is_upright_and_not_darkened() -> void:
	var face: BattlefieldFace = _battlefield(_look("grizzly_bears"), 140.0)

	assert_eq(face.custom_minimum_size, BattlefieldFace.size_for(140.0))
	assert_eq(face.card().rotation_degrees, 0.0)
	assert_false(face.is_darkened())
	assert_null(face.tap_symbol())


func test_a_tapped_battlefield_face_turns_sideways_darkens_and_keeps_its_tap_symbol_upright() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_tapped = true

	var face: BattlefieldFace = _battlefield(look, 140.0)

	var upright: Vector2 = BattlefieldFace.size_for(140.0)
	assert_eq(face.custom_minimum_size, Vector2(upright.y, upright.x), "It takes up its sideways footprint.")
	assert_eq(face.card().rotation_degrees, 90.0)
	assert_true(face.is_darkened())
	assert_almost_eq(face.tap_symbol().get_global_transform().get_rotation(), 0.0, 0.0001)
	assert_eq(face.tap_symbol().modulate.a, 0.5)


func test_a_battlefield_face_cuts_a_long_name_short_with_an_ellipsis() -> void:
	var look: CardLook = _look("merfolk_of_the_pearl_trident")

	var face: BattlefieldFace = _battlefield(look, 100.0)

	assert_true(face.name_text().shown_text().ends_with("…"))


func test_a_battlefield_face_shows_its_keyword_chips() -> void:
	var face: BattlefieldFace = _battlefield(_look("serra_angel"), 140.0)

	assert_eq(face.chip_letters(), ["F", "V"] as Array[String])


func test_a_card_face_credits_the_artist_in_its_border() -> void:
	var face: CardFace = _card(_look("grizzly_bears"), 400.0)

	assert_eq(face.artist_text().shown_text(), "Illus. Jeff A. Menges")


func test_a_card_without_art_shows_its_name_in_the_art_window() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.art_key = "no_such_card"

	var face: CardFace = _card(look, 400.0)

	assert_null(face.art())
	assert_eq(face.art_fallback_text().shown_text(), "Grizzly Bears")
	assert_null(face.artist_text())


func test_a_card_faces_rules_text_leaves_reminder_text_off() -> void:
	var look: CardLook = _look("serra_angel")
	look.rules_text = "Flying\nVigilance (Attacking doesn't cause this creature to tap.)"

	var face: CardFace = _card(look, 400.0)

	assert_eq(face.rules().symbols(), [] as Array[String])
	assert_false(face.rules().overflows())


func test_the_wheel_over_a_card_face_scrolls_rules_text_that_overflows() -> void:
	var face: CardFace = _card(_wordy(), 300.0)

	var handled: bool = face.scroll_by_wheel(_wheel(MOUSE_BUTTON_WHEEL_DOWN))

	assert_true(handled)
	assert_gt(face.rules().scroll_offset(), 0.0)


func test_the_wheel_over_a_card_face_whose_text_fits_is_left_for_the_page() -> void:
	var look: CardLook = _look("serra_angel")
	look.rules_text = "Flying\nVigilance"
	var face: CardFace = _card(look, 300.0)

	assert_false(face.scroll_by_wheel(_wheel(MOUSE_BUTTON_WHEEL_DOWN)))


func test_the_wheel_over_a_battlefield_face_asks_to_scroll_its_card_faces_rules_text() -> void:
	var card: CardFace = _card(_wordy(), 300.0)
	var field: BattlefieldFace = _battlefield(_wordy(), 140.0)
	field.rules_scroll_requested.connect(card.scroll_rules)

	field.scroll_by_wheel(_wheel(MOUSE_BUTTON_WHEEL_DOWN))

	assert_gt(card.rules().scroll_offset(), 0.0)


func test_a_card_faces_scroll_bar_stops_above_its_pt_box() -> void:
	var face: CardFace = _card(_wordy(), 300.0)
	var box_top: float = CardGeometry.POWER_TOUGHNESS.position.y * 300.0
	var rules_top: float = CardGeometry.RULES.position.y * 300.0

	assert_lte(rules_top + face.rules().scroll_bar_height(), box_top)


func _look(file_name: String) -> CardLook:
	return CardLook.of_definition(load(ALPHA % file_name) as MmCardDefinition)


func _wordy() -> CardLook:
	var look: CardLook = _look("prodigal_sorcerer")
	look.rules_text = "Flying, first strike, vigilance\nWhen this creature enters, draw two cards, then discard a card.\n{T}: This creature deals 1 damage to any target.\n{1}{U}, {T}: Tap target creature. It doesn't untap during its controller's next untap step.\nAt the beginning of your upkeep, you gain 1 life for each card in your hand.\nWhenever another creature you control dies, put it on top of its owner's library."
	return look


func _card(look: CardLook, height: float) -> CardFace:
	var face: CardFace = CardFace.new()
	add_child_autofree(face)
	face.setup(look, height)
	return face


func _battlefield(look: CardLook, height: float) -> BattlefieldFace:
	var face: BattlefieldFace = BattlefieldFace.new()
	add_child_autofree(face)
	face.setup(look, height)
	return face


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event
