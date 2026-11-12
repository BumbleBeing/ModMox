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


func test_a_face_part_way_through_turning_is_part_way_darkened_about_its_middle() -> void:
	var face: BattlefieldFace = _battlefield(_look("grizzly_bears"), 140.0)

	face.show_turn(0.5)

	assert_eq(face.turn(), 0.5)
	assert_eq(face.card().rotation_degrees, 45.0)
	assert_almost_eq(face.card().get_global_transform() * (face.card().size / 2.0), face.global_position + face.size / 2.0,
			Vector2(0.01, 0.01), "It turns about the middle of its footprint.")
	assert_true(face.is_darkened())
	assert_almost_eq(face.shade_alpha(), BattlefieldFace.TAPPED_SHADE / 2.0, 0.0001)
	assert_eq(face.tap_symbol().modulate.a, 0.25)
	assert_almost_eq(face.tap_symbol().get_global_transform().get_rotation(), 0.0, 0.0001, "The symbol stays upright.")


func test_a_face_turned_all_the_way_back_is_as_if_it_had_never_been_tapped() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_tapped = true
	var face: BattlefieldFace = _battlefield(look, 140.0)
	assert_eq(face.turn(), 1.0)
	assert_almost_eq(face.shade_alpha(), BattlefieldFace.TAPPED_SHADE, 0.0001)

	face.show_turn(0.0)

	assert_eq(face.card().rotation_degrees, 0.0)
	assert_false(face.is_darkened())
	assert_null(face.tap_symbol())
	assert_eq(face.shade_alpha(), 0.0)
	assert_almost_eq(face.card().get_global_transform() * (face.card().size / 2.0), face.global_position + face.size / 2.0,
			Vector2(0.01, 0.01), "Still about the middle of its sideways footprint.")

	face.show_turn(1.0)

	assert_eq(face.card().rotation_degrees, 90.0)
	assert_eq(face.tap_symbol().modulate.a, 0.5)


func test_the_shade_covers_the_card_and_the_tap_symbol_sits_in_the_middle_of_its_art() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_tapped = true

	var face: BattlefieldFace = _battlefield(look, 140.0)

	var shades: Array[Node] = face.card().find_children("*", "ColorRect", true, false)
	var shade: ColorRect = shades[0] as ColorRect
	var art: Rect2 = BattlefieldFace.art_box(140.0)
	var symbol: TextureRect = face.tap_symbol()
	assert_eq(shades.size(), 1)
	assert_eq(shade.size, BattlefieldFace.size_for(140.0))
	assert_eq(Color(shade.color, 1.0), Color.BLACK)
	assert_eq(shade.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_almost_eq(symbol.size.x, minf(art.size.x, art.size.y) * 0.92, 0.001)
	assert_eq(symbol.size.x, symbol.size.y)
	assert_almost_eq(symbol.position + symbol.size / 2.0, art.get_center(), Vector2(0.001, 0.001))
	assert_eq(symbol.pivot_offset, symbol.size / 2.0, "It turns back about its own middle.")
	assert_true(symbol.get_parent() == shade.get_parent() and symbol.get_index() > shade.get_index(), "Over the shade.")


func test_a_damaged_creature_shows_its_damage_on_a_chip_over_its_toughness() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.damage_marked = 2

	var face: BattlefieldFace = _battlefield(look, 140.0)

	var box: Rect2 = BattlefieldFace.power_toughness_box(140.0)
	var chip: DamageChip = face.damage_chip()
	assert_eq(chip.amount, 2)
	assert_almost_eq(chip.position, DamageChip.box_over(box).position, Vector2(0.001, 0.001))
	assert_almost_eq(chip.size, DamageChip.box_over(box).size, Vector2(0.001, 0.001))
	assert_eq(chip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(chip.get_parent(), face.card(), "It turns with the card when the creature is tapped.")
	assert_eq(chip.get_index(), face.card().get_child_count() - 1, "And is drawn over everything else on it.")


func test_a_creature_with_no_damage_and_a_damaged_noncreature_have_no_chip() -> void:
	var land: CardLook = _look("forest")
	land.damage_marked = 3

	assert_null(_battlefield(_look("grizzly_bears"), 140.0).damage_chip())
	assert_null(_battlefield(land, 140.0).damage_chip())


func test_damage_does_not_change_the_power_and_toughness_shown() -> void:
	var look: CardLook = _look("grizzly_bears")
	var texts: Array[String] = look.power_toughness_texts()
	var colors: Array[Color] = look.power_toughness_colors()

	look.damage_marked = 1

	assert_eq(look.power_toughness_texts(), texts)
	assert_eq(look.power_toughness_colors(), colors)


func test_a_look_takes_its_damage_from_the_view_and_has_none_as_printed() -> void:
	var view: MmObjectView = MmObjectView.new()
	view.damage_marked = 3

	assert_eq(CardLook.of_view(view).damage_marked, 3)
	assert_eq(_look("grizzly_bears").damage_marked, 0)


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
