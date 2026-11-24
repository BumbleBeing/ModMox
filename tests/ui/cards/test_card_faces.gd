extends GutTest
## A Card Face draws a card in full; a Battlefield Face draws a permanent with its border,
## name, art, P/T box and keyword chips, turned sideways and darkened when tapped.

const Scenario := preload("res://addons/modmox_rules/tests/support/scenario.gd")
const ALPHA: String = "res://content/cards/alpha/%s.tres"


func test_an_untapped_battlefield_face_is_upright_and_not_darkened() -> void:
	var face: BattlefieldFace = _battlefield(_look("grizzly_bears"), 140.0)

	assert_eq(face.custom_minimum_size, BattlefieldFace.size_for(140.0))
	assert_eq(face.card().rotation_degrees, 0.0)
	assert_false(face.is_darkened())
	assert_null(face.tap_symbol())


func test_a_dimmed_battlefield_face_is_grayed_over_in_its_own_rounded_shape() -> void:
	# Game ADR 0055: its cast from the top of the library is Spent this turn.
	var look: CardLook = _look("grizzly_bears")
	look.is_dimmed = true

	var face: BattlefieldFace = _battlefield(look, 140.0)
	var plain: BattlefieldFace = _battlefield(_look("grizzly_bears"), 140.0)

	assert_null(plain.dim())
	assert_not_null(face.dim())
	assert_eq(face.dim().get_parent(), face.card(), "It turns with the card.")
	assert_eq(face.dim().size, face.card().size)
	assert_eq(face.dim().get_index(), face.card().get_child_count() - 1, "Over everything on the face.")
	var style: StyleBoxFlat = face.dim().get_theme_stylebox("panel") as StyleBoxFlat
	var shape: StyleBoxFlat = (face.card().get_child(0) as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(style.corner_radius_top_left, 0, "Its corners are rounded.")
	assert_eq(style.corner_radius_top_left, shape.corner_radius_top_left, "As the card's are.")
	assert_eq((face.dim().material as ShaderMaterial).shader, BattlefieldFace.DIMMED_SHADER)
	assert_false(face.is_darkened(), "Not as a tapped one is.")


func test_a_permanent_is_dimmed_while_a_permission_of_it_is_spent_this_turn() -> void:
	var seen: MmObjectView = MmObjectView.new()
	seen.name = "Assemble the Players"

	assert_false(CardLook.of_view(seen).is_dimmed)
	seen.permissions_used_this_turn = {1: "Savannah Lions"}
	assert_true(CardLook.of_view(seen).is_dimmed)


func test_a_permanent_is_dimmed_while_a_trigger_of_it_is_spent_this_turn() -> void:
	var seen: MmObjectView = MmObjectView.new()
	seen.name = "Tocasia's Welcome"

	assert_false(CardLook.of_view(seen).is_dimmed)
	seen.triggered_this_turn = [0]
	assert_true(CardLook.of_view(seen).is_dimmed)


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


func test_an_attached_face_lies_sideways_without_being_darkened_and_carries_the_attached_mark() -> void:
	var face: BattlefieldFace = _attached(_look("ivory_tower"), 140.0)

	var upright: Vector2 = BattlefieldFace.size_for(140.0)
	assert_true(face.is_attached())
	assert_eq(face.custom_minimum_size, Vector2(upright.y, upright.x), "Its sideways footprint.")
	assert_eq(face.card().rotation_degrees, 90.0, "Its name runs down its right side.")
	assert_false(face.is_darkened(), "Sideways is not tapped here.")
	assert_null(face.tap_symbol(), "Its art is behind the permanent it is attached to.")
	var mark: AttachedMark = face.attached_mark()
	assert_not_null(mark)
	var strip: float = BattlefieldFace.attached_strip(140.0)
	assert_eq(Rect2(mark.position, mark.size), Rect2(upright.x - strip, 0.0, strip, strip),
		"A square as wide as the strip that shows, in the corner past the end of its name.")
	assert_null(_battlefield(_look("ivory_tower"), 140.0).attached_mark(), "A face on its own has none.")
	assert_almost_eq(face.name_text().position.x + face.name_text().size.x, mark.position.x, 0.01, "Its name stops short of the mark.")


func test_a_tucked_face_lies_as_an_attached_one_does_with_no_attached_mark_and_its_name_the_whole_strip() -> void:
	var face: BattlefieldFace = BattlefieldFace.new()
	add_child_autofree(face)
	face.setup(_look("ivory_tower"), 140.0, true, true)

	var upright: Vector2 = BattlefieldFace.size_for(140.0)
	assert_true(face.is_attached())
	assert_eq(face.custom_minimum_size, Vector2(upright.y, upright.x))
	assert_eq(face.card().rotation_degrees, 90.0)
	assert_false(face.is_darkened())
	assert_null(face.attached_mark(), "The plus is for what is attached (ADR 0043).")
	var free: BattlefieldFace = _battlefield(_look("ivory_tower"), 140.0)
	assert_almost_eq(face.name_text().size.x, free.name_text().size.x, 0.01, "Its name runs as far as on a face on its own.")


func test_a_tapped_attached_face_is_darkened_like_any_tapped_permanent_and_eases_there() -> void:
	var look: CardLook = _look("ivory_tower")
	look.is_tapped = true

	var face: BattlefieldFace = _attached(look, 140.0)

	assert_eq(face.card().rotation_degrees, 90.0)
	assert_true(face.is_darkened())
	assert_almost_eq(face.shade_alpha(), BattlefieldFace.TAPPED_SHADE, 0.0001)
	assert_null(face.tap_symbol())
	face.show_turn(0.5)
	assert_eq(face.card().rotation_degrees, 90.0, "It stays sideways while it untaps;")
	assert_almost_eq(face.shade_alpha(), BattlefieldFace.TAPPED_SHADE / 2.0, 0.0001, "only the shade eases.")
	face.show_turn(0.0)
	assert_false(face.is_darkened())
	assert_eq(face.card().rotation_degrees, 90.0)


func test_a_face_part_way_to_lying_attached_is_turned_that_far_with_its_mark_that_solid() -> void:
	var face: BattlefieldFace = _attached(_look("ivory_tower"), 140.0)

	face.show_turn(0.0, 0.5)

	assert_eq(face.card().rotation_degrees, 45.0, "Half-way over on its way behind its creature.")
	assert_false(face.is_darkened(), "Lying down is not tapping.")
	assert_almost_eq(face.attached_mark().modulate.a, 0.5, 0.0001)
	assert_almost_eq(face.card().get_global_transform() * (face.card().size / 2.0), face.global_position + face.size / 2.0,
			Vector2(0.01, 0.01), "About the middle of its footprint.")
	face.show_turn(0.0)
	assert_eq(face.card().rotation_degrees, 90.0, "Told nothing else, an attached face lies all the way over.")
	assert_eq(face.attached_mark().modulate.a, 1.0)


func test_a_face_standing_up_again_from_being_attached_is_turned_that_far_and_shows_its_tap_symbol_as_it_stands() -> void:
	var look: CardLook = _look("ivory_tower")
	look.is_tapped = true
	var face: BattlefieldFace = _battlefield(look, 140.0)

	face.show_turn(0.0, 0.5)
	assert_eq(face.card().rotation_degrees, 45.0)
	assert_false(face.is_darkened())

	face.show_turn(1.0, 1.0)
	assert_eq(face.card().rotation_degrees, 90.0, "Tapped and lying down are the same quarter turn, never two.")
	assert_null(face.tap_symbol(), "No tap symbol while it lies behind a permanent.")
	face.show_turn(1.0, 0.5)
	assert_eq(face.tap_symbol().modulate.a, 0.25, "It shows as the face comes out.")


func test_the_attached_mark_is_white_inside_and_black_where_the_cards_border_runs_under_it() -> void:
	var mark: AttachedMark = AttachedMark.make(Vector2(154.0, 140.0), 28.0, 4, 6)
	add_child_autofree(mark)

	assert_eq(mark.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(AttachedMark.box_on(Vector2(154.0, 140.0), 28.0), Rect2(126.0, 0.0, 28.0, 28.0))
	var look: StyleBoxFlat = mark.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(look.bg_color, Color.WHITE)
	assert_eq(look.border_color, Color.BLACK)
	assert_eq([look.border_width_top, look.border_width_right], [4, 4], "The card's own border, along its top and right edges.")
	assert_eq([look.border_width_left, look.border_width_bottom], [AttachedMark.EDGE, AttachedMark.EDGE], "A thin edge on the other two.")
	assert_eq(look.corner_radius_top_right, 6, "The card's own rounded corner.")
	assert_eq(mark.plus_color(), Color.BLACK)
	assert_almost_eq(mark.plus_center(), AttachedMark.inside(28.0, 4).get_center(), Vector2(0.5, 0.5), "The plus is in the middle of the white.")


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


func test_a_summoning_sick_creature_is_darkened_a_little_with_the_spiral_over_the_middle_of_its_art() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_summoning_sick = true

	var face: BattlefieldFace = _battlefield(look, 140.0)

	var spiral: SicknessSpiral = face.sickness_spiral()
	var art: Rect2 = BattlefieldFace.art_box(140.0)
	assert_almost_eq(face.darkness(), BattlefieldFace.SICK_SHADE, 0.0001)
	assert_lt(BattlefieldFace.SICK_SHADE, BattlefieldFace.TAPPED_SHADE, "Less than a tapped one.")
	assert_false(face.is_darkened(), "Not as a tapped one is.")
	assert_null(face.tap_symbol())
	assert_not_null(spiral)
	assert_eq(spiral.get_parent(), face.card(), "It moves with the card.")
	assert_eq(spiral.get_index(), face.card().get_child_count() - 1, "Over everything on the face.")
	assert_almost_eq(spiral.position + spiral.size / 2.0, art.get_center(), Vector2(0.5, 0.5))
	assert_eq(spiral.size.x, SicknessSpiral.side_in(art.size))


func test_the_sick_shade_covers_the_card_under_the_spiral() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_summoning_sick = true

	var face: BattlefieldFace = _battlefield(look, 140.0)

	var shades: Array[Node] = face.card().find_children("*", "ColorRect", true, false)
	var sick: ColorRect = shades[1] as ColorRect
	assert_eq(shades.size(), 2, "The tapped shade and the sick one.")
	assert_true(sick.visible)
	assert_eq(sick.size, BattlefieldFace.size_for(140.0))
	assert_eq(Color(sick.color, 1.0), Color.BLACK)
	assert_almost_eq(sick.color.a, BattlefieldFace.SICK_SHADE, 0.0001)
	assert_eq(sick.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_a_creature_that_is_not_summoning_sick_and_a_sick_noncreature_show_nothing_of_it() -> void:
	var land: CardLook = _look("forest")
	land.is_summoning_sick = true

	for face: BattlefieldFace in [_battlefield(_look("grizzly_bears"), 140.0), _battlefield(land, 140.0)]:
		assert_null(face.sickness_spiral())
		assert_eq(face.darkness(), 0.0)


func test_a_tapped_summoning_sick_creature_is_as_dark_as_a_tapped_one_and_its_spiral_stays_upright() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_summoning_sick = true
	look.is_tapped = true

	var face: BattlefieldFace = _battlefield(look, 140.0)

	assert_almost_eq(face.darkness(), BattlefieldFace.TAPPED_SHADE, 0.0001, "The darker of the two, never both.")
	assert_almost_eq(face.sickness_spiral().get_global_transform().get_rotation(), 0.0, 0.0001, "Its light stays at the upper left.")
	assert_gt(face.sickness_spiral().get_index(), face.tap_symbol().get_parent().get_index(), "Over the tap symbol.")
	face.show_turn(0.25)
	assert_almost_eq(face.darkness(), BattlefieldFace.SICK_SHADE, 0.0001, "Part way to tapped it is no lighter than a sick one.")
	assert_almost_eq(face.sickness_spiral().get_global_transform().get_rotation(), 0.0, 0.0001)


func test_a_dimmed_summoning_sick_creature_keeps_its_spiral_over_the_gray() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_summoning_sick = true
	look.is_dimmed = true

	var face: BattlefieldFace = _battlefield(look, 140.0)

	assert_gt(face.sickness_spiral().get_index(), face.dim().get_index())


func test_a_summoning_sick_creature_drawn_attached_shows_no_spiral() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.is_summoning_sick = true

	assert_null(_attached(look, 140.0).sickness_spiral(), "Its art is hidden.")


func test_a_look_takes_its_summoning_sickness_from_the_view_and_has_none_as_printed() -> void:
	var seen: MmObjectView = MmObjectView.new()
	seen.name = "Grizzly Bears"

	assert_false(CardLook.of_view(seen).is_summoning_sick)
	seen.is_summoning_sick = true
	assert_true(CardLook.of_view(seen).is_summoning_sick)
	assert_true(CardLook.of_view(seen).copy().is_summoning_sick)
	assert_false(_look("grizzly_bears").is_summoning_sick)


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


func test_a_permanent_with_counters_shows_them_on_a_chip_in_its_arts_top_left_corner() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.counters = {MmCounter.Kind.PLUS_ONE_PLUS_ONE: 2}
	look.damage_marked = 1

	var face: BattlefieldFace = _battlefield(look, 140.0)

	var place: Rect2 = CounterChip.box_in(BattlefieldFace.art_box(140.0), BattlefieldFace.power_toughness_box(140.0))
	var chip: CounterChip = face.counter_chip()
	assert_eq([chip.kind, chip.amount], [MmCounter.Kind.PLUS_ONE_PLUS_ONE, 2])
	assert_almost_eq(chip.position, place.position, Vector2(0.001, 0.001))
	assert_almost_eq(chip.size, place.size, Vector2(0.001, 0.001))
	assert_eq(chip.get_parent(), face.card(), "It turns with the card when the permanent is tapped.")
	assert_eq(face.damage_chip().get_index(), chip.get_index() + 1, "Just under the Damage Chip, over everything else.")
	assert_false(Rect2(chip.position, chip.size).intersects(Rect2(face.damage_chip().position, face.damage_chip().size)))


func test_minus_counters_show_as_their_own_kind_and_a_noncreature_shows_counters_too() -> void:
	var bears: CardLook = _look("grizzly_bears")
	bears.counters = {MmCounter.Kind.MINUS_ONE_MINUS_ONE: 1}
	var land: CardLook = _look("forest")
	land.counters = {MmCounter.Kind.PLUS_ONE_PLUS_ONE: 3}

	var chip: CounterChip = _battlefield(bears, 140.0).counter_chip()

	assert_eq([chip.kind, chip.amount], [MmCounter.Kind.MINUS_ONE_MINUS_ONE, 1])
	assert_eq(_battlefield(land, 140.0).counter_chip().amount, 3)


func test_a_permanent_with_no_counters_has_no_counter_chip() -> void:
	var emptied: CardLook = _look("grizzly_bears")
	emptied.counters = {MmCounter.Kind.PLUS_ONE_PLUS_ONE: 0}

	assert_null(_battlefield(_look("grizzly_bears"), 140.0).counter_chip())
	assert_null(_battlefield(emptied, 140.0).counter_chip())


func test_a_look_takes_its_counters_from_the_view_and_has_none_as_printed() -> void:
	var view: MmObjectView = MmObjectView.new()
	view.counters = {MmCounter.Kind.MINUS_ONE_MINUS_ONE: 2}

	var look: CardLook = CardLook.of_view(view)
	view.counters[MmCounter.Kind.MINUS_ONE_MINUS_ONE] = 5

	assert_eq(look.counters, {MmCounter.Kind.MINUS_ONE_MINUS_ONE: 2}, "Its own copy.")
	assert_eq(_look("grizzly_bears").counters.size(), 0)


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


func test_a_type_line_of_every_creature_type_says_all_in_its_own_color() -> void:
	# ADR 0075: changeling's creature types are "(All)", not every one of them listed.
	var look: CardLook = _look("grizzly_bears")
	look.is_every_creature_type = true

	var face: CardFace = _card(look, 400.0)

	assert_eq(look.type_line(), "Creature — (All)", "Bear is a creature type, so it is part of the All.")
	assert_eq(face.type_line_text().shown_text(), "Creature — (All)")
	assert_eq(face.type_line_text().run_colors(), [Color.BLACK, CardLook.EVERY_CREATURE_TYPE_COLOR] as Array[Color])
	assert_ne(CardLook.EVERY_CREATURE_TYPE_COLOR, Color.BLACK)


func test_a_type_line_of_every_creature_type_keeps_its_other_subtypes() -> void:
	var look: CardLook = _look("grizzly_bears")
	look.card_types = [MmCardTypes.CardType.ARTIFACT, MmCardTypes.CardType.CREATURE]
	look.subtypes = ["Equipment", "Shapeshifter"]
	look.is_every_creature_type = true

	assert_eq(look.type_line(), "Artifact Creature — Equipment (All)")


func test_an_ordinary_type_line_is_one_black_run() -> void:
	var face: CardFace = _card(_look("grizzly_bears"), 400.0)

	assert_eq(face.type_line_text().shown_text(), "Creature — Bear")
	assert_eq(face.type_line_text().run_colors(), [Color.BLACK] as Array[Color])


func test_a_look_is_every_creature_type_as_printed_and_as_viewed() -> void:
	var view: MmObjectView = MmObjectView.new()
	view.is_every_creature_type = true

	assert_true(CardLook.of_characteristics(MmCharacteristics.printed(Scenario.changeling())).is_every_creature_type)
	assert_true(CardLook.of_view(view).is_every_creature_type)
	assert_false(_look("grizzly_bears").is_every_creature_type)


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


func _attached(look: CardLook, height: float) -> BattlefieldFace:
	var face: BattlefieldFace = BattlefieldFace.new()
	add_child_autofree(face)
	face.setup(look, height, true)
	return face


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func test_a_card_face_shows_no_keyword_chip_until_it_is_shown_in_a_graveyard() -> void:
	var face: CardFace = _card_face(_daydream(), 250.0)

	assert_eq(face.chips().size(), 0)


func test_a_card_face_in_a_graveyard_shows_its_flashback_chip_at_the_bottom_left_of_its_art() -> void:
	var face: CardFace = _card_face(_daydream(), 250.0)

	face.show_graveyard_chips()

	assert_eq(face.chips().size(), 1)
	assert_eq(face.chips()[0].icon, "flashback")
	var art: Rect2 = CardGeometry.on_card(CardGeometry.ART, face.size)
	var chip: Rect2 = face.chip_rects()[0]
	assert_true(art.encloses(chip), "The chip sits on the art.")
	assert_almost_eq(chip.position.x - art.position.x, art.end.y - chip.end.y, 0.01, "As far in from the left as up from the bottom.")
	assert_eq(fmod(chip.size.x, KeywordChips.PIXEL_STEP), 0.0, "Its icon stays crisp.")


func test_a_card_face_in_a_graveyard_with_no_flashback_shows_no_chip() -> void:
	var face: CardFace = _card_face(_look("serra_angel"), 250.0)

	face.show_graveyard_chips()

	assert_eq(face.chips().size(), 0)


func _card_face(look: CardLook, height: float) -> CardFace:
	var face: CardFace = CardFace.new()
	face.setup(look, height)
	add_child_autofree(face)
	return face


func _daydream() -> CardLook:
	return CardLook.of_definition(load("res://content/cards/secrets_of_strixhaven/daydream.tres") as MmCardDefinition)
