extends GutTest
## Every Region of the Encounter Screen is worked out from the screen's size, so the layout
## can be checked without a window.

const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(2560, 1080), Vector2(1920, 1440)]
## Everything right of the sidebar on a 1920 x 1080 screen.
const OPENING_AREA: Rect2 = Rect2(340, 0, 1580, 1080)


func test_no_two_regions_overlap_at_any_supported_size() -> void:
	# 1280 × 720 is 1920 × 1080 scaled down (A205), so it lays out exactly like it.
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		for first: int in EncounterLayout.LEAVES.size():
			for second: int in range(first + 1, EncounterLayout.LEAVES.size()):
				var one: String = EncounterLayout.LEAVES[first]
				var other: String = EncounterLayout.LEAVES[second]
				assert_false(regions[one].intersects(regions[other]), "%s and %s overlap at %s." % [one, other, screen])


func test_every_region_is_on_the_screen() -> void:
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		for region: String in regions:
			assert_true(Rect2(Vector2.ZERO, screen).encloses(regions[region]), "%s is off the screen at %s." % [region, screen])


func test_the_hold_panel_is_opposite_the_info_panel_at_the_top_left_of_the_battlefield() -> void:
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		var hold: Rect2 = regions["hold"]
		assert_eq(hold.position.x, regions["info"].position.x, "Under one another at %s." % screen)
		assert_eq(hold.size.x, regions["info"].size.x)
		assert_almost_eq(hold.position.y, EncounterLayout.INFO_PAD, 0.01, "At the top of the screen.")
		assert_lt(hold.end.y, regions["villain_lands"].position.y, "Above the Villain's lands.")
		assert_true(EncounterLayout.LEAVES.has("hold"), "Nothing may overlap it.")
		# The Villain's hand keeps to the middle between it and as far in from the other side.
		assert_almost_eq(regions["villain_hand"].position.x, regions["hero_hand"].position.x, 0.01)
		assert_almost_eq(regions["villain_hand"].size.x, regions["hero_hand"].size.x, 0.01)


func test_extra_width_goes_to_the_battlefield() -> void:
	var normal: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))
	var wide: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(2560, 1080))

	assert_eq(wide["hero_lands"].size.x - normal["hero_lands"].size.x, 640.0)
	assert_eq(wide["sidebar"].size.x, normal["sidebar"].size.x)
	assert_eq(wide["piles"].size.x, normal["piles"].size.x)
	assert_eq(wide["piles"].end.x, 2560.0, "The piles stay on the right edge.")


func test_the_rows_run_villain_hand_to_hero_hand_from_the_top() -> void:
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))
	var order: Array[String] = ["villain_hand", "villain_lands", "villain_nonlands", "hero_nonlands", "hero_lands", "hero_hand"]

	for index: int in order.size() - 1:
		assert_lt(regions[order[index]].end.y, regions[order[index + 1]].position.y + 0.01, order[index])
	assert_eq(regions["hero_hand"].end.y, 1080.0)


func test_the_heros_piles_run_library_graveyard_exile_from_the_top_and_the_villains_mirror_them() -> void:
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))

	assert_lt(regions["hero_library"].end.y, regions["hero_graveyard"].position.y + 0.01)
	assert_lt(regions["hero_graveyard"].end.y, regions["hero_exile"].position.y + 0.01)
	assert_lt(regions["villain_exile"].end.y, regions["villain_graveyard"].position.y + 0.01)
	assert_lt(regions["villain_graveyard"].end.y, regions["villain_library"].position.y + 0.01)
	for who: String in ["hero", "villain"]:
		assert_eq(regions[who + "_exile"].size, regions[who + "_library"].size, "Every pile is the same size.")
	assert_lt(regions["villain_library"].end.y, regions["hero_library"].position.y, "The Villain's piles end above the Hero's.")
	assert_gt(regions["hero_library"].size.y, 150.0, "With the buttons gone from this column, the piles are bigger.")
	assert_false(regions.has("status"), "Nothing sits between the two sets of piles any more (A294).")


func test_the_six_piles_fill_the_right_column_with_equal_spacing() -> void:
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		var keys: Array[String] = [
			"villain_exile", "villain_graveyard", "villain_library", "hero_library", "hero_graveyard", "hero_exile",
		]
		var gap: float = regions[keys[0]].position.y
		assert_gt(gap, 0.0)
		for index: int in range(1, keys.size()):
			assert_almost_eq(regions[keys[index]].position.y - regions[keys[index - 1]].end.y, gap, 0.01, keys[index])
		assert_almost_eq(screen.y - regions["hero_exile"].end.y, gap, 0.01, "The same space under the last pile.")


func test_the_info_panel_sits_at_the_left_end_of_the_hands_strip() -> void:
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		var info: Rect2 = regions["info"]

		assert_eq(info.size.x, EncounterLayout.INFO_WIDTH)
		assert_eq(info.position.x, regions["hero_lands"].position.x, "Flush with the left of the battlefield.")
		assert_gt(info.position.y, regions["hero_lands"].end.y, "Under the Hero's lands.")
		assert_lt(info.end.x, regions["hero_hand"].position.x, "The hand starts to its right.")


func test_the_hand_is_centered_on_the_battlefield_between_bounds_that_clear_the_info_panel() -> void:
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		var hand: Rect2 = regions["hero_hand"]
		var field: Rect2 = regions["hero_lands"]

		assert_almost_eq(hand.get_center().x, field.get_center().x, 0.01, "Centered whatever the width.")
		assert_almost_eq(hand.position.x - field.position.x, field.end.x - hand.end.x, 0.01, "As far in on each side.")
		assert_almost_eq(hand.position.x - regions["info"].end.x, EncounterLayout.GUTTER, 0.01)


func test_a_hand_of_any_size_rests_inside_its_bounds() -> void:
	var hand: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_hand"]
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)

	for count: int in [1, 2, 7, 12, 25, 40]:
		var rest: Array[Vector2] = EncounterLayout.hand_rest(count, hand, card)
		assert_gt(rest[0].x, hand.position.x - 0.01, "%d cards start inside." % count)
		assert_lt(rest[count - 1].x + card.x, hand.end.x + 0.01, "%d cards end inside." % count)
		if count > 2:
			assert_almost_eq(rest[1].x - rest[0].x, rest[count - 1].x - rest[count - 2].x, 0.01, "Evenly spread.")


func test_parting_a_full_hand_never_pushes_a_card_past_its_bounds() -> void:
	var hand: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_hand"]
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(25, hand, card)
	var is_ever_shifted: bool = false

	for index: int in rest.size():
		var cursor: Vector2 = rest[index] + Vector2(card.x * 0.4, 40.0)
		var free: Array[Vector2] = EncounterLayout.hand_spread(rest, card, cursor)
		var held: Array[Vector2] = EncounterLayout.hand_spread_within(rest, card, cursor, hand)
		for place: Vector2 in held:
			assert_gt(place.x, hand.position.x - 0.01)
			assert_lt(place.x + card.x, hand.end.x + 0.01)
		is_ever_shifted = is_ever_shifted or free[rest.size() - 1].x > hand.end.x - card.x

	assert_true(is_ever_shifted, "Unbounded, the last card would have left the bounds.")
	assert_eq(EncounterLayout.hand_spread_within(rest, card, Vector2.ZERO, hand), rest, "Away from the hand it rests.")
	assert_eq(EncounterLayout.hand_spread_within([] as Array[Vector2], card, Vector2.ZERO, hand).size(), 0)


func test_the_card_under_the_cursor_still_shows_whole_at_the_right_end_of_a_bounded_hand() -> void:
	var hand: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_hand"]
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(25, hand, card)
	var cursor: Vector2 = rest[23] + Vector2(10.0, 40.0)

	var held: Array[Vector2] = EncounterLayout.hand_spread_within(rest, card, cursor, hand)

	assert_almost_eq(held[24].x, hand.end.x - card.x, 0.01, "The last card is held at the edge.")
	assert_gt(held[24].x - held[23].x, (rest[24].x - rest[23].x) * 2.0, "The hand moved back to make the room.")


func test_a_bounded_hand_parted_near_its_left_end_squeezes_evenly_and_hides_no_card() -> void:
	var hand: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_hand"]
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(25, hand, card)
	var cursor: Vector2 = rest[3] + Vector2(10.0, 40.0)

	var free: Array[Vector2] = EncounterLayout.hand_spread(rest, card, cursor)
	var held: Array[Vector2] = EncounterLayout.hand_spread_within(rest, card, cursor, hand)

	assert_true(free[0].x < hand.position.x or free[24].x + card.x > hand.end.x, "Unbounded, a card would have left the bounds.")
	for index: int in range(1, 25):
		assert_gt(held[index].x, held[index - 1].x + 1.0, "Card %d is not hidden behind the one before it." % index)
	assert_gt(held[0].x, hand.position.x - 0.01)
	assert_almost_eq(held[24].x, hand.end.x - card.x, 0.01, "The far end is squeezed up to the bound.")
	assert_almost_eq(held[4].x - held[3].x, free[4].x - free[3].x, 0.01, "The card under the cursor shows as whole as it would unbounded.")
	assert_almost_eq((held[2].x - held[1].x) / (free[2].x - free[1].x), (held[1].x - held[0].x) / (free[1].x - free[0].x), 0.001,
		"Those before it are all squeezed by the same amount.")
	assert_almost_eq(held[20].x - held[19].x, held[10].x - held[9].x, 0.01, "And so are those after it.")
	for index: int in 25:
		assert_eq(held[index].y, free[index].y, "Only sideways: a card rises as it would unbounded.")


func test_a_hand_with_room_to_part_is_not_changed_by_its_bounds() -> void:
	var hand: Rect2 = EncounterLayout.regions(Vector2(2560, 1080))["hero_hand"]
	var card: Vector2 = Vector2(EncounterLayout.HAND_CARD_HEIGHT * CardGeometry.ASPECT, EncounterLayout.HAND_CARD_HEIGHT)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(4, hand, card)
	var cursor: Vector2 = rest[1] + Vector2(10.0, 40.0)

	var free: Array[Vector2] = EncounterLayout.hand_spread(rest, card, cursor)
	var held: Array[Vector2] = EncounterLayout.hand_spread_within(rest, card, cursor, hand)

	for index: int in 4:
		assert_almost_eq(held[index].x, free[index].x, 0.01, "Card %d." % index)
	assert_eq(EncounterLayout.hand_spread_within([rest[0]] as Array[Vector2], card, rest[0] + Vector2(10, 40), hand).size(), 1,
		"One card has nothing to part from.")


func test_lands_of_one_name_stand_together_in_the_order_their_names_arrived() -> void:
	assert_eq(EncounterLayout.land_order(["Mountain", "Island", "Mountain"] as Array[String]), [0, 2, 1] as Array[int],
		"The second Mountain goes just right of the first, so it is the middle land.")
	assert_eq(EncounterLayout.land_order(["Island", "Mountain", "Island", "Forest", "Mountain"] as Array[String]),
		[0, 2, 1, 4, 3] as Array[int])
	assert_eq(EncounterLayout.land_order(["Forest", "Forest"] as Array[String]), [0, 1] as Array[int])
	assert_eq(EncounterLayout.land_order([] as Array[String]), [] as Array[int])


func test_the_option_menu_opens_at_the_click_showing_at_most_three_rows() -> void:
	var field: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["battlefield"]
	var at: Vector2 = field.position + Vector2(300, 200)
	var row: float = EncounterLayout.MENU_ROW + EncounterLayout.MENU_GAP

	var two: Rect2 = EncounterLayout.menu_rect(at, 2, field)
	var three: Rect2 = EncounterLayout.menu_rect(at, 3, field)
	var four: Rect2 = EncounterLayout.menu_rect(at, 4, field)

	assert_eq(two.position, at, "It opens where the card was clicked.")
	assert_almost_eq(three.size.y - two.size.y, row, 0.01, "A third row makes it taller.")
	assert_eq(four.size, three.size, "A fourth does not: it scrolls (A286).")
	assert_eq(EncounterLayout.menu_rect(at, 9, field).size, three.size)
	assert_eq(two.size.x, EncounterLayout.MENU_WIDTH)


func test_the_option_menu_stays_inside_the_battlefield() -> void:
	var field: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["battlefield"]

	for at: Vector2 in [field.end, field.position, Vector2(field.end.x, field.position.y), field.end + Vector2(500, 500),
			field.position - Vector2(500, 500)]:
		assert_true(field.encloses(EncounterLayout.menu_rect(at, 4, field)), "Clicked at %s." % at)


func test_a_face_past_either_end_of_a_line_or_behind_an_arrow_is_hidden() -> void:
	assert_eq(EncounterLayout.hidden_past(-40.0, 600.0, 26.0), -1)
	assert_eq(EncounterLayout.hidden_past(20.0, 600.0, 26.0), -1, "Behind the left arrow.")
	assert_eq(EncounterLayout.hidden_past(26.0, 600.0, 26.0), 0)
	assert_eq(EncounterLayout.hidden_past(300.0, 600.0, 26.0), 0)
	assert_eq(EncounterLayout.hidden_past(574.0, 600.0, 26.0), 0)
	assert_eq(EncounterLayout.hidden_past(580.0, 600.0, 26.0), 1, "Behind the right arrow.")
	assert_eq(EncounterLayout.hidden_past(900.0, 600.0, 26.0), 1)


func test_creatures_in_combat_stand_first_in_id_order_and_the_rest_keep_their_places() -> void:
	var ids: Array[int] = [14, 9, 30, 11, 5]

	assert_eq(EncounterLayout.combat_order(ids, [false, false, true, false, true] as Array[bool]), [4, 2, 0, 1, 3] as Array[int],
		"5 and 30 are fighting, lowest ID first; 14, 9 and 11 stay as they stood.")
	assert_eq(EncounterLayout.combat_order(ids, [false, false, false, false, false] as Array[bool]), [0, 1, 2, 3, 4] as Array[int],
		"With nobody in combat nothing moves.")
	assert_eq(EncounterLayout.combat_order(ids, [true, true, true, true, true] as Array[bool]), [4, 1, 3, 0, 2] as Array[int])
	assert_eq(EncounterLayout.combat_order([] as Array[int], [] as Array[bool]), [] as Array[int])


func test_blockers_stand_in_the_order_of_the_attackers_they_block_so_no_two_lines_cross() -> void:
	var ids: Array[int] = [5, 3, 9, 7]
	var all_fighting: Array[bool] = [true, true, true, false]
	var none: int = EncounterLayout.NOT_BLOCKING

	assert_eq(EncounterLayout.combat_order(ids, all_fighting, [20, 30, 10, none] as Array[int]), [2, 0, 1, 3] as Array[int],
		"Attackers stand in ID order, so 9 blocking 10 goes first, then 5 blocking 20, then 3 blocking 30.")
	assert_eq(EncounterLayout.combat_order(ids, all_fighting, [20, 20, 10, none] as Array[int]), [2, 1, 0, 3] as Array[int],
		"Two blocking the same attacker stand together, lowest ID first.")
	assert_eq(EncounterLayout.combat_order(ids, all_fighting, [] as Array[int]), [1, 0, 2, 3] as Array[int],
		"Without blocks to go by, ID order.")


func test_a_block_line_ends_on_the_edge_of_a_face_toward_the_lane() -> void:
	var face: Rect2 = Rect2(400, 500, 200, 180)

	var hero: Vector2 = EncounterLayout.block_line_end(face, true, 0, 999.0)
	var villain: Vector2 = EncounterLayout.block_line_end(face, false, 0, 999.0)

	assert_eq(hero.x, 500.0, "The middle of the face.")
	assert_lt(hero.y, face.position.y, "Just above the Hero's creature, toward the middle of the board.")
	assert_almost_eq(face.position.y - hero.y, EncounterLayout.BLOCK_LINE_GAP, 0.01)
	assert_gt(villain.y, face.end.y, "Just below the Villain's.")


func test_a_block_line_to_a_creature_out_of_sight_ends_on_the_arrow_toward_it() -> void:
	var face: Rect2 = Rect2(2400, 500, 200, 180)

	var right: Vector2 = EncounterLayout.block_line_end(face, true, 1, 1725.0)
	var left: Vector2 = EncounterLayout.block_line_end(face, false, -1, 365.0)

	assert_eq(right.x, 1725.0, "The arrow's middle, not the face that cannot be seen (A327).")
	assert_lt(right.y, face.position.y, "At the same height as any other line's end.")
	assert_eq(left.x, 365.0)


func test_an_arrowhead_points_at_the_end_of_its_line() -> void:
	var up: PackedVector2Array = EncounterLayout.arrowhead(Vector2(100, 300), Vector2(100, 200))

	assert_eq(up.size(), 3)
	assert_lt(up[0].y, 200.0 + 0.01, "The tip is at the far end,")
	assert_almost_eq(up[1].y, 200.0 + EncounterLayout.ARROWHEAD.x, 0.01, "and the other two corners are back along the line,")
	assert_almost_eq(absf(up[1].x - up[2].x), EncounterLayout.ARROWHEAD.y * 2.0, 0.01, "one to each side.")
	var sideways: PackedVector2Array = EncounterLayout.arrowhead(Vector2(100, 200), Vector2(300, 200))
	assert_gt(sideways[0].x, sideways[1].x, "It turns with the line.")


func test_a_damage_stepper_sits_centered_over_the_art() -> void:
	var face: Vector2 = Vector2(199, 181)

	var box: Rect2 = EncounterLayout.stepper_rect(face)

	assert_eq(box.size, EncounterLayout.STEPPER)
	assert_almost_eq(box.get_center().x, face.x / 2.0, 0.01)
	assert_gt(box.position.y, face.y * 0.2, "Under the name.")
	assert_lt(box.end.y, face.y * 0.7, "Above the power and toughness.")


func test_the_pause_menu_is_centered_on_the_battlefield_and_grows_with_its_buttons() -> void:
	var field: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["battlefield"]

	var four: Rect2 = EncounterLayout.pause_rect(4, field)
	var two: Rect2 = EncounterLayout.pause_rect(2, field)

	assert_almost_eq(four.get_center().x, field.get_center().x, 0.01)
	assert_almost_eq(four.get_center().y, field.get_center().y, 0.01)
	assert_almost_eq(four.size.y - two.size.y, EncounterLayout.PAUSE_ROW * 2.0, 0.01)
	assert_true(field.encloses(four))


func test_a_players_panel_has_a_square_portrait_with_life_in_its_corner() -> void:
	var panel_rect: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_panel"]

	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(panel_rect)

	assert_eq(parts["portrait"].size.x, parts["portrait"].size.y)
	assert_true(parts["portrait"].encloses(parts["life"]))
	assert_almost_eq(parts["life"].end.x, parts["portrait"].end.x - 5.0, 0.01)
	assert_almost_eq(parts["life"].end.y, parts["portrait"].end.y - 5.0, 0.01)
	assert_lt(parts["name"].end.y, parts["portrait"].position.y + 0.01, "The name is above the portrait.")


func test_the_mana_buttons_and_emblems_button_span_the_portraits_width_under_it() -> void:
	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(Rect2(10, 10, 320, 525))
	var portrait: Rect2 = parts["portrait"]

	assert_almost_eq(parts["mana_0"].position.x, portrait.position.x, 0.01)
	assert_almost_eq(parts["mana_5"].end.x, portrait.end.x, 0.01)
	assert_gt(parts["mana_0"].position.y, portrait.end.y)
	assert_almost_eq(parts["emblems"].size.x, portrait.size.x, 0.01)
	assert_gt(parts["emblems"].position.y, parts["mana_0"].end.y)
	for type: int in 5:
		assert_lt(parts["mana_%d" % type].end.x, parts["mana_%d" % (type + 1)].position.x, "WUBRGC, left to right.")


func test_all_twelve_steps_run_down_the_right_side_of_a_panel() -> void:
	var panel_rect: Rect2 = Rect2(10, 10, 320, 525)

	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(panel_rect)

	for step: int in 12:
		var button: Rect2 = parts["step_%d" % step]
		assert_true(panel_rect.encloses(button), "Step %d is inside the panel." % step)
		assert_almost_eq(button.end.x, panel_rect.end.x - EncounterLayout.PANEL_PAD, 0.01)
		assert_gt(button.position.x, parts["portrait"].end.x, "Steps never cover the portrait.")
		if step > 0:
			assert_gt(button.position.y, parts["step_%d" % (step - 1)].end.y)


func test_a_row_centers_its_permanents_on_one_line() -> void:
	var row_rect: Rect2 = Rect2(352, 472, 1386, 200)

	var footprints: Array[Rect2] = EncounterLayout.row([false, false, false] as Array[bool], row_rect)

	var height: float = EncounterLayout.row_face_height([false, false, false] as Array[bool], row_rect)
	assert_eq(footprints.size(), 3)
	assert_eq(footprints[0].size, BattlefieldFace.size_for(height))
	assert_almost_eq(footprints[0].position.x - row_rect.position.x, row_rect.end.x - footprints[2].end.x, 0.01)
	assert_almost_eq(footprints[1].position.x - footprints[0].end.x, EncounterLayout.ROW_GAP, 0.01)
	assert_true(row_rect.encloses(footprints[0]))


func test_a_tapped_permanent_takes_its_sideways_footprint_and_still_fits_the_row() -> void:
	var row_rect: Rect2 = Rect2(352, 684, 1386, 140)

	var footprints: Array[Rect2] = EncounterLayout.row([false, true] as Array[bool], row_rect)

	assert_eq(footprints[1].size, Vector2(footprints[0].size.y, footprints[0].size.x), "Sideways.")
	assert_true(row_rect.encloses(footprints[1]), "A tapped face is taller than an untapped one, and still fits.")


func test_a_crowded_row_shrinks_its_faces_to_stay_on_one_line() -> void:
	var row_rect: Rect2 = Rect2(352, 472, 1386, 200)
	var many: Array[bool] = []
	for index: int in 20:
		many.append(false)

	var footprints: Array[Rect2] = EncounterLayout.row(many, row_rect)

	assert_lt(EncounterLayout.row_face_height(many, row_rect), EncounterLayout.row_face_height([false] as Array[bool], row_rect))
	assert_gt(footprints[0].position.x, row_rect.position.x - 0.01)
	assert_lt(footprints[19].end.x, row_rect.end.x + 0.01)
	assert_eq(footprints[0].position.y, footprints[19].position.y, "One line.")


func test_an_empty_row_has_nothing_in_it() -> void:
	assert_eq(EncounterLayout.row([] as Array[bool], Rect2(0, 0, 500, 200)).size(), 0)


func test_the_hand_rests_fanned_and_overlapping() -> void:
	var hand_rect: Rect2 = Rect2(352, 836, 1386, 244)
	var card: Vector2 = Vector2(178, 250)

	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, hand_rect, card)

	assert_almost_eq(rest[1].x - rest[0].x, card.x * EncounterLayout.HAND_SHOWN, 0.01, "Each card shows part of its width.")
	assert_almost_eq(rest[0].x - hand_rect.position.x, hand_rect.end.x - (rest[6].x + card.x), 0.01, "Centered.")
	assert_lt(rest[3].y, rest[0].y, "The middle card sits highest.")
	assert_eq(rest[0].y, rest[6].y)
	assert_eq(EncounterLayout.fan_angle(3, 7), 0.0)
	assert_eq(EncounterLayout.fan_angle(0, 7), -EncounterLayout.fan_angle(6, 7))


func test_a_big_hand_squeezes_to_fit_its_region() -> void:
	var hand_rect: Rect2 = Rect2(352, 836, 600, 244)
	var card: Vector2 = Vector2(178, 250)

	var rest: Array[Vector2] = EncounterLayout.hand_rest(20, hand_rect, card)

	assert_gt(rest[0].x, hand_rect.position.x - 0.01)
	assert_lt(rest[19].x + card.x, hand_rect.end.x + 0.01)


func test_the_villains_hand_is_fanned_from_the_top_edge() -> void:
	var hand_rect: Rect2 = Rect2(352, 0, 1386, 80)
	var card: Vector2 = Vector2(107, 150)

	var places: Array[Vector2] = EncounterLayout.villain_hand(5, hand_rect, card)

	assert_gt(places[2].y, places[0].y, "The middle card hangs lowest, mirroring the Hero's hand.")
	assert_almost_eq(places[2].y + card.y, hand_rect.end.y, 0.01)
	assert_eq(places[0].y, places[4].y)


func test_the_hand_stays_at_rest_while_the_cursor_is_away() -> void:
	var card: Vector2 = Vector2(178, 250)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, Rect2(352, 836, 1386, 244), card)

	assert_eq(EncounterLayout.hand_spread(rest, card, Vector2(1000, 300)), rest)
	assert_false(EncounterLayout.is_cursor_over_hand(rest, card, Vector2(1000, 300)))
	assert_false(EncounterLayout.is_cursor_over_hand([] as Array[Vector2], card, Vector2(1000, 900)))


func test_the_hand_parts_so_the_card_under_the_cursor_shows_whole() -> void:
	var card: Vector2 = Vector2(178, 250)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, Rect2(352, 836, 1386, 244), card)
	var step: float = rest[1].x - rest[0].x
	var cursor: Vector2 = Vector2(rest[3].x + step / 2.0, 950)

	var spread: Array[Vector2] = EncounterLayout.hand_spread(rest, card, cursor)

	assert_almost_eq(EncounterLayout.hand_cursor_place(rest, card, cursor), 3.0, 0.001)
	assert_almost_eq(spread[3].x, rest[3].x, 0.01, "The card under the cursor does not move sideways.")
	assert_gt(spread[4].x - spread[3].x, card.x * 0.9, "The next card moves clear of it.")
	assert_lt(spread[2].x, rest[2].x, "Cards to the left make a little room.")
	assert_gt(spread[6].x, rest[6].x)


func test_cards_near_the_cursor_rise_by_no_more_than_an_eighth_of_their_height() -> void:
	var card: Vector2 = Vector2(178, 250)
	var rest: Array[Vector2] = EncounterLayout.hand_rest(7, Rect2(352, 836, 1386, 244), card)
	var cursor: Vector2 = Vector2(rest[3].x + (rest[1].x - rest[0].x) / 2.0, 950)

	var spread: Array[Vector2] = EncounterLayout.hand_spread(rest, card, cursor)

	assert_almost_eq(rest[3].y - spread[3].y, card.y / 8.0, 0.01, "The card under the cursor rises the most.")
	for index: int in rest.size():
		assert_lt(rest[index].y - spread[index].y, card.y / 8.0 + 0.01)
	assert_gt(rest[4].y - spread[4].y, 0.0, "Its neighbor rises a little.")
	assert_eq(spread[0].y, rest[0].y, "A card far away does not rise.")


func test_with_no_other_permanents_the_creatures_have_the_whole_row() -> void:
	var row_rect: Rect2 = Rect2(352, 472, 1386, 200)

	var groups: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, [] as Array[bool], true)

	assert_eq(groups["creatures"], row_rect)
	assert_eq(groups["others"].size, Vector2.ZERO)


func test_other_permanents_sit_to_the_right_of_creatures_smaller_and_set_back() -> void:
	var row_rect: Rect2 = Rect2(352, 472, 1386, 200)

	var hero: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, [false, false] as Array[bool], true)
	var villain: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, [false, false] as Array[bool], false)

	assert_almost_eq(hero["others"].position.x, hero["creatures"].end.x, 0.01, "To the creatures' right.")
	assert_almost_eq(hero["others"].end.x, row_rect.end.x, 0.01)
	assert_almost_eq(hero["others"].size.y, row_rect.size.y * EncounterLayout.OTHERS_SCALE, 0.01)
	assert_almost_eq(hero["others"].end.y, row_rect.end.y, 0.01, "Set back toward the Hero's edge, which is down.")
	assert_almost_eq(villain["others"].position.y, row_rect.position.y, 0.01, "And toward the Villain's edge, which is up.")
	assert_lt(EncounterLayout.others_height(row_rect), EncounterLayout.creature_height(row_rect))
	assert_true(row_rect.encloses(hero["others"]))
	assert_true(row_rect.encloses(villain["others"]))


func test_other_permanents_take_the_width_they_need_but_never_more_than_a_third() -> void:
	var row_rect: Rect2 = Rect2(352, 472, 1386, 200)
	var heights: Array[float] = [EncounterLayout.others_height(row_rect), EncounterLayout.others_height(row_rect)]
	var many: Array[bool] = []
	for index: int in 12:
		many.append(false)

	var two: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, [false, false] as Array[bool], true)
	var crowd: Dictionary[String, Rect2] = EncounterLayout.nonland_groups(row_rect, many, true)

	assert_almost_eq(two["others"].size.x, EncounterLayout.line_width([false, false] as Array[bool], heights), 0.01)
	assert_almost_eq(crowd["others"].size.x, row_rect.size.x / 3.0, 0.01)
	assert_almost_eq(crowd["creatures"].size.x, row_rect.size.x * 2.0 / 3.0, 0.01)


func test_a_line_keeps_each_face_its_own_size_and_centers_it_from_top_to_bottom() -> void:
	var heights: Array[float] = [180.0, 144.0, 180.0]

	var footprints: Array[Rect2] = EncounterLayout.line([false, false, true] as Array[bool], heights, 200.0)

	assert_eq(footprints[0].position, Vector2(EncounterLayout.LINE_PAD, 10.0))
	assert_eq(footprints[1].size, BattlefieldFace.size_for(144.0), "A smaller face is not stretched.")
	assert_almost_eq(footprints[1].position.y, 28.0, 0.01)
	assert_almost_eq(footprints[1].position.x - footprints[0].end.x, EncounterLayout.ROW_GAP, 0.01)
	assert_eq(footprints[2].size, Vector2(180.0, BattlefieldFace.size_for(180.0).x), "A tapped face stands sideways.")
	assert_almost_eq(EncounterLayout.line_width([false, false, true] as Array[bool], heights),
		footprints[2].end.x + EncounterLayout.LINE_PAD, 0.01)
	assert_eq(EncounterLayout.line_width([] as Array[bool], [] as Array[float]), 0.0)


func test_a_line_that_fits_is_centered_and_one_that_does_not_scrolls_between_its_ends() -> void:
	assert_eq(EncounterLayout.max_scroll(600.0, 1000.0), 0.0)
	assert_eq(EncounterLayout.line_start(600.0, 1000.0, 0.0), 200.0, "Centered.")
	assert_eq(EncounterLayout.line_start(600.0, 1000.0, 300.0), 200.0, "A line that fits does not scroll.")
	assert_eq(EncounterLayout.max_scroll(1500.0, 1000.0), 500.0)
	assert_eq(EncounterLayout.line_start(1500.0, 1000.0, 0.0), 0.0)
	assert_eq(EncounterLayout.line_start(1500.0, 1000.0, 200.0), -200.0)
	assert_eq(EncounterLayout.line_start(1500.0, 1000.0, 9000.0), -500.0, "It stops at its right end.")
	assert_eq(EncounterLayout.line_start(1500.0, 1000.0, -50.0), 0.0, "And at its left.")


func test_creatures_out_of_a_combat_are_a_fifth_smaller_and_those_in_it_step_toward_the_middle() -> void:
	assert_eq(EncounterLayout.bystander_scale(true, false), 0.8)
	assert_eq(EncounterLayout.bystander_scale(true, true), 1.0)
	assert_eq(EncounterLayout.bystander_scale(false, false), 1.0, "Outside combat every creature is full size.")
	assert_eq(EncounterLayout.combat_step(true), -40.0, "The Hero's step up the screen.")
	assert_eq(EncounterLayout.combat_step(false), 40.0)
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))
	assert_gt(regions["hero_nonlands"].position.y - regions["villain_nonlands"].end.y, EncounterLayout.COMBAT_STEP * 2.0 - 0.01,
		"Both sides can step forward without meeting.")


func test_the_controls_have_their_own_section_under_the_emblems_button() -> void:
	var panel_rect: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_panel"]

	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(panel_rect)

	assert_gt(parts["potions"].position.y, parts["emblems"].end.y, "The Potions button is under the Emblems button")
	assert_eq(parts["potions"].size, parts["emblems"].size, "and the same size.")
	assert_gt(parts["controls"].position.y, parts["potions"].end.y)
	assert_almost_eq(parts["controls"].end.y, panel_rect.end.y - EncounterLayout.PANEL_PAD, 0.01, "The section fills what is left of the panel.")
	assert_false(parts.has("pass"), "The Pass Button is not in the panel (A489).")
	assert_true(panel_rect.encloses(parts["controls"]))
	assert_almost_eq(parts["controls"].size.x, parts["portrait"].size.x, 0.01)
	assert_lt(parts["controls"].end.x, parts["step_0"].position.x, "Clear of the step buttons.")
	var order: Array[String] = ["undo", "yield"]
	for index: int in order.size():
		assert_true(parts["controls"].encloses(parts[order[index]]), "%s is inside the section." % order[index])
		if index > 0:
			assert_gt(parts[order[index]].position.y, parts[order[index - 1]].end.y, "%s is under %s." % [order[index], order[index - 1]])
	assert_almost_eq(parts["yield"].size.y, parts["undo"].size.y, 0.01, "The two share it evenly.")
	assert_almost_eq(parts["undo"].position.y, parts["controls"].position.y + EncounterLayout.CONTROLS_PAD, 0.01,
		"They fill the section from its top")
	assert_almost_eq(parts["yield"].end.y, parts["controls"].end.y - EncounterLayout.CONTROLS_PAD, 0.01, "to its bottom.")


func test_the_heros_hand_is_cut_off_a_quarter_of_a_card_below_the_screen() -> void:
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))

	assert_almost_eq(regions["hero_hand"].size.y, EncounterLayout.HAND_CARD_HEIGHT * 0.75, 8.0)
	assert_gt(regions["hero_hand"].size.y / EncounterLayout.HAND_CARD_HEIGHT, CardGeometry.TYPE_LINE.end.y,
		"The type line still shows.")


func test_the_heros_rows_sit_low_with_the_hand_and_open_a_lane_across_the_middle() -> void:
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))
	var lane: float = regions["hero_nonlands"].position.y - regions["villain_nonlands"].end.y

	assert_almost_eq(lane, 28.0 + EncounterLayout.HAND_CARD_HEIGHT * EncounterLayout.HAND_HIDDEN, 0.01)
	assert_gt(lane, EncounterLayout.COMBAT_STEP * 2.0, "Attackers and blockers step forward and still do not touch.")
	assert_almost_eq(regions["villain_lands"].position.y - regions["villain_hand"].end.y, 12.0, 0.01,
		"The Villain's rows stay up by their hand.")
	assert_almost_eq(regions["hero_hand"].position.y - regions["hero_lands"].end.y, 12.0, 0.01,
		"The Hero's rows stay down by theirs.")
	assert_true(regions["battlefield"].encloses(regions["villain_lands"]))
	assert_true(regions["battlefield"].encloses(regions["hero_lands"]))


func test_a_hand_with_no_gap_rests_as_it_always_does() -> void:
	var hand: Rect2 = EncounterLayout.regions(SIZES[0])["hero_hand"]
	var card: Vector2 = Vector2(180, 250)

	assert_eq(EncounterLayout.hand_row(5, -1, hand, card), EncounterLayout.hand_rest(5, hand, card))
	var angles: Array[float] = EncounterLayout.hand_row_angles(5, -1)
	assert_eq(angles.size(), 5)
	for index: int in 5:
		assert_eq(angles[index], EncounterLayout.fan_angle(index, 5))


func test_a_hand_leaves_a_gap_where_a_held_card_would_be_put_down() -> void:
	var hand: Rect2 = EncounterLayout.regions(SIZES[0])["hero_hand"]
	var card: Vector2 = Vector2(180, 250)
	var six: Array[Vector2] = EncounterLayout.hand_rest(6, hand, card)

	var middle: Array[Vector2] = EncounterLayout.hand_row(5, 2, hand, card)
	var left: Array[Vector2] = EncounterLayout.hand_row(5, 0, hand, card)
	var right: Array[Vector2] = EncounterLayout.hand_row(5, 5, hand, card)
	var past: Array[Vector2] = EncounterLayout.hand_row(5, 9, hand, card)

	assert_eq(middle, [six[0], six[1], six[3], six[4], six[5]] as Array[Vector2], "The third of six places is left empty.")
	assert_eq(left, six.slice(1))
	assert_eq(right, six.slice(0, 5))
	assert_eq(past, right, "A gap past the end is the end.")
	assert_eq(EncounterLayout.hand_row_angles(5, 2), [EncounterLayout.fan_angle(0, 6), EncounterLayout.fan_angle(1, 6),
			EncounterLayout.fan_angle(3, 6), EncounterLayout.fan_angle(4, 6), EncounterLayout.fan_angle(5, 6)] as Array[float])
	assert_eq(EncounterLayout.hand_row_angles(5, 0), [EncounterLayout.fan_angle(1, 6), EncounterLayout.fan_angle(2, 6),
			EncounterLayout.fan_angle(3, 6), EncounterLayout.fan_angle(4, 6), EncounterLayout.fan_angle(5, 6)] as Array[float],
			"A gap at the left end is still a gap.")
	assert_eq(EncounterLayout.hand_row_angles(5, 9).size(), 5)
	assert_eq(EncounterLayout.hand_row_angles(5, 9)[4], EncounterLayout.fan_angle(4, 6))
	assert_eq(EncounterLayout.hand_row(0, 0, hand, card).size(), 0, "An empty hand has nothing to move aside.")


func test_a_held_card_goes_down_at_the_place_nearest_the_cursor() -> void:
	var hand: Rect2 = EncounterLayout.regions(SIZES[0])["hero_hand"]
	var card: Vector2 = Vector2(180, 250)
	var six: Array[Vector2] = EncounterLayout.hand_rest(6, hand, card)

	for index: int in 6:
		assert_eq(EncounterLayout.hand_gap(5, hand, card, six[index] + Vector2(card.x / 2.0, 40)), index, "Over place %d." % index)
	var step: float = six[1].x - six[0].x
	assert_eq(EncounterLayout.hand_gap(5, hand, card, six[2] + Vector2(card.x / 2.0 + step * 0.4, 0)), 2)
	assert_eq(EncounterLayout.hand_gap(5, hand, card, six[2] + Vector2(card.x / 2.0 + step * 0.6, 0)), 3)
	assert_eq(EncounterLayout.hand_gap(5, hand, card, Vector2(0, 900)), 0, "Left of the hand is its left end.")
	assert_eq(EncounterLayout.hand_gap(5, hand, card, Vector2(5000, 900)), 5, "Right of it, its right end.")
	assert_eq(EncounterLayout.hand_gap(0, hand, card, Vector2(900, 900)), 0, "An empty hand has one place.")


func test_above_the_hands_strip_is_where_a_card_is_played_and_the_left_panels_are_off_limits() -> void:
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(SIZES[0])
	var strip_top: float = regions["hero_hand"].position.y

	assert_true(EncounterLayout.is_above_hand(Vector2(900, strip_top - 1.0), regions))
	assert_false(EncounterLayout.is_above_hand(Vector2(900, strip_top), regions), "The strip itself is the hand.")
	assert_false(EncounterLayout.is_above_hand(regions["info"].get_center(), regions), "The Info Panel is in the strip (A382).")
	assert_true(EncounterLayout.is_above_hand(regions["hero_graveyard"].position, regions), "The piles are above it too (A372).")
	assert_true(EncounterLayout.is_over_panels(Vector2(regions["sidebar"].end.x - 1.0, 500), regions))
	assert_false(EncounterLayout.is_over_panels(Vector2(regions["sidebar"].end.x, 500), regions))
	assert_true(EncounterLayout.is_over_panels(regions["hero_panel"].get_center(), regions))
	assert_false(EncounterLayout.is_over_panels(regions["info"].get_center(), regions))


func test_easing_covers_in_one_slow_frame_what_the_frames_it_replaced_would_have() -> void:
	assert_almost_eq(EncounterLayout.ease_weight(0.3, 1.0 / 60.0), 0.3, 0.0001)
	assert_almost_eq(EncounterLayout.ease_weight(0.3, 2.0 / 60.0), 0.51, 0.0001, "Two frames' worth: 0.3, then 0.3 of what is left.")
	assert_almost_eq(EncounterLayout.ease_weight(0.3, 3.0 / 60.0), 0.657, 0.0001)
	assert_eq(EncounterLayout.ease_weight(0.3, 0.0), 0.0)
	assert_almost_eq(EncounterLayout.ease_weight(0.5, 1.0 / 120.0), 1.0 - sqrt(0.5), 0.0001, "And half a frame's worth at twice the rate.")
	assert_lt(EncounterLayout.ease_weight(0.3, 10.0), 1.0001)


func test_an_opening_hand_of_up_to_eight_is_one_row_and_of_nine_or_more_is_two() -> void:
	for count: int in range(1, 9):
		assert_eq(EncounterLayout.opening_hand_rows(count), 1)
	for count: int in [9, 10, 12]:
		assert_eq(EncounterLayout.opening_hand_rows(count), 2)
	var ten: Array[Rect2] = EncounterLayout.opening_hand_cards(10, 10, OPENING_AREA)
	assert_almost_eq(ten[2].position.x, ten[7].position.x, 0.01, "Five in the upper row, and five under them.")
	assert_gt(ten[7].position.y, ten[2].end.y)
	var nine: Array[Rect2] = EncounterLayout.opening_hand_cards(9, 9, OPENING_AREA)
	assert_lt(nine[4].position.y, nine[5].position.y - nine[0].size.y, "The odd card goes in the upper row.")
	assert_almost_eq(nine[5].position.y, nine[8].position.y, 0.01)


func test_an_opening_hand_is_fanned_like_the_hand_in_play() -> void:
	var cards: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 7, OPENING_AREA)
	var turns: Array[float] = EncounterLayout.opening_hand_turns(7, 7)

	assert_eq(turns.size(), 7)
	assert_eq(turns[3], 0.0, "The middle card stands upright.")
	for index: int in 6:
		assert_almost_eq(turns[index + 1] - turns[index], EncounterLayout.OPENING_FAN_ANGLE, 0.0001, "Each turned a little more than the last.")
	assert_almost_eq(turns[0], -turns[6], 0.0001, "Evenly to both sides.")
	assert_lt(turns[0], 0.0, "The left ones lean left.")
	assert_almost_eq(cards[0].position.y, cards[6].position.y, 0.01)
	assert_gt(cards[0].position.y, cards[1].position.y, "And the further out, the lower: they lie along an arc.")
	assert_gt(cards[1].position.y, cards[2].position.y)
	assert_gt(cards[2].position.y, cards[3].position.y)
	assert_eq(EncounterLayout.opening_hand_turns(7, 0), [] as Array[float])
	assert_eq(EncounterLayout.opening_hand_turns(7, 1), [0.0] as Array[float], "One card left stands upright.")


func test_the_cards_of_an_opening_hand_overlap_most_at_the_bottom_corners_and_little_at_the_top() -> void:
	for count: int in [2, 5, 7, 8, 10]:
		var cards: Array[Rect2] = EncounterLayout.opening_hand_cards(count, count, OPENING_AREA)
		var turns: Array[float] = EncounterLayout.opening_hand_turns(count, count)
		var width: float = cards[0].size.x
		assert_almost_eq(cards[1].position.x - cards[0].position.x, width * EncounterLayout.OPENING_STEP, 0.01, "%d cards" % count)
		# The bottom right corner of one and the bottom left corner of the next cross.
		var corner: Vector2 = _corners(cards[0], turns[0])[2]
		var next_corner: Vector2 = _corners(cards[1], turns[1])[3]
		assert_gt(corner.x, next_corner.x, "%d cards: the bottoms overlap" % count)
		assert_lt(corner.x - next_corner.x, width * 0.2, "%d cards: by under a fifth of a card" % count)
		var top: Vector2 = _corners(cards[0], turns[0])[1]
		var next_top: Vector2 = _corners(cards[1], turns[1])[0]
		assert_lt(top.x - next_top.x, corner.x - next_corner.x, "%d cards: the tops overlap less than the bottoms" % count)
		assert_lt(top.x - next_top.x, width * 0.1, "%d cards: and by under a tenth, so each name can be read" % count)


func test_a_fanned_opening_hand_stays_inside_the_area_with_every_card_the_same_size() -> void:
	for count: int in range(1, 13):
		var cards: Array[Rect2] = EncounterLayout.opening_hand_cards(count, count, OPENING_AREA)
		var turns: Array[float] = EncounterLayout.opening_hand_turns(count, count)
		assert_eq(cards.size(), count)
		assert_eq(turns.size(), count)
		for index: int in count:
			assert_almost_eq(cards[index].size.x / cards[index].size.y, CardGeometry.ASPECT, 0.001)
			assert_eq(cards[index].size, cards[0].size)
			for corner: Vector2 in _corners(cards[index], turns[index]):
				assert_true(OPENING_AREA.has_point(corner), "%d cards: card %d is inside, turned as it is." % [count, index])


func test_opening_hand_cards_can_be_read() -> void:
	assert_almost_eq(EncounterLayout.opening_hand_cards(7, 7, OPENING_AREA)[0].size.x, 229.51, 0.01, "Seven fill the width.")
	assert_almost_eq(EncounterLayout.opening_hand_cards(5, 5, OPENING_AREA)[0].size.x, 250.0, 0.01, "Never wider than this.")
	for count: int in range(1, 11):
		var height: float = EncounterLayout.opening_hand_cards(count, count, OPENING_AREA)[0].size.y
		assert_gt(height, 245.0, "%d cards are about as tall as a card in the hand's strip, or taller." % count)


func test_an_opening_hand_row_is_centered_and_closes_up_when_cards_leave_it() -> void:
	var all: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 7, OPENING_AREA)
	var fewer: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 4, OPENING_AREA)
	var middle: float = OPENING_AREA.get_center().x

	assert_almost_eq((all[0].position.x + all[6].end.x) / 2.0, middle, 0.01)
	assert_eq(fewer.size(), 4)
	assert_eq(fewer[0].size, all[0].size, "The cards that stay keep their size.")
	assert_almost_eq((fewer[0].position.x + fewer[3].end.x) / 2.0, middle, 0.01)
	assert_almost_eq(fewer[1].position.x - fewer[0].position.x, all[1].position.x - all[0].position.x, 0.01)
	assert_almost_eq(EncounterLayout.opening_hand_turns(7, 4)[0], -1.5 * EncounterLayout.OPENING_FAN_ANGLE, 0.0001, "And fan as four.")
	assert_eq(EncounterLayout.opening_hand_cards(7, 0, OPENING_AREA).size(), 0)
	var split: Array[Rect2] = EncounterLayout.opening_hand_cards(10, 7, OPENING_AREA)
	assert_gt(split[5].position.y, split[2].end.y, "Seven of ten still fill the upper row of five first.")
	assert_almost_eq(EncounterLayout.opening_hand_turns(10, 7)[5], -0.5 * EncounterLayout.OPENING_FAN_ANGLE, 0.0001, "The two below fan as two.")


func test_each_row_of_an_opening_hand_is_centered_on_its_own_cards() -> void:
	var middle: float = OPENING_AREA.get_center().x

	var seven_of_ten: Array[Rect2] = EncounterLayout.opening_hand_cards(10, 7, OPENING_AREA)
	assert_almost_eq((seven_of_ten[0].position.x + seven_of_ten[4].end.x) / 2.0, middle, 0.01, "Five above.")
	assert_almost_eq((seven_of_ten[5].position.x + seven_of_ten[6].end.x) / 2.0, middle, 0.01, "Two below, centered as two.")
	var nine: Array[Rect2] = EncounterLayout.opening_hand_cards(9, 9, OPENING_AREA)
	assert_almost_eq((nine[5].position.x + nine[8].end.x) / 2.0, middle, 0.01, "Four below.")


func test_the_rows_of_an_opening_hand_sit_a_little_above_the_middle_of_the_screen() -> void:
	var line: float = OPENING_AREA.position.y + OPENING_AREA.size.y * EncounterLayout.OPENING_MIDDLE
	for count: int in [1, 7, 8, 9, 10]:
		var box: Rect2 = _fan_box(count)
		assert_almost_eq(box.get_center().y, line, 14.0, "%d cards: what is drawn is about centered on it." % count)
	var ten: Array[Rect2] = EncounterLayout.opening_hand_cards(10, 10, OPENING_AREA)
	var turns: Array[float] = EncounterLayout.opening_hand_turns(10, 10)
	var lowest_above: float = _corners(ten[0], turns[0])[3].y
	assert_gt(ten[7].position.y, lowest_above, "The lower row starts under the lowest corner of the upper one.")


func test_the_opening_hands_words_and_buttons_stand_clear_of_the_cards() -> void:
	for count: int in [0, 1, 7, 8, 9, 10]:
		var parts: Dictionary[String, Rect2] = EncounterLayout.opening_hand(count, OPENING_AREA)
		var box: Rect2 = _fan_box(count)
		for key: String in ["heading", "under_heading", "buttons", "villain"]:
			assert_true(OPENING_AREA.encloses(parts[key]), "%d cards: %s is inside." % [count, key])
			if count > 0:
				assert_false(box.intersects(parts[key]), "%d cards: %s is clear of the cards, turned as they are." % [count, key])
		assert_lt(parts["heading"].end.y, parts["under_heading"].end.y)
		assert_lt(parts["buttons"].end.y, parts["villain"].position.y + 1.0)
	var none: Dictionary[String, Rect2] = EncounterLayout.opening_hand(0, OPENING_AREA)
	assert_gt(none["middle"].position.y, none["under_heading"].end.y, "With no cards the two choices stand in the middle.")
	assert_lt(none["middle"].end.y, none["buttons"].position.y)


func test_the_opening_hand_scales_with_the_screens_height() -> void:
	var small: Rect2 = Rect2(170, 0, 790, 540)

	var cards: Array[Rect2] = EncounterLayout.opening_hand_cards(7, 7, small)

	assert_almost_eq(cards[0].size.x, 114.75, 0.01, "Half the screen, half the card.")
	for corner: Vector2 in _corners(cards[6], EncounterLayout.opening_hand_turns(7, 7)[6]):
		assert_true(small.has_point(corner))


## The corners of a card drawn in [param rect] and turned by [param turn] about the middle
## of its bottom edge: top left, top right, bottom right, bottom left.
func _corners(rect: Rect2, turn: float) -> Array[Vector2]:
	var pivot: Vector2 = rect.position + Vector2(rect.size.x / 2.0, rect.size.y)
	var found: Array[Vector2] = []
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		found.append(pivot + (corner - pivot).rotated(turn))
	return found


## The box around everything drawn of an opening hand of [param count] cards.
func _fan_box(count: int) -> Rect2:
	var cards: Array[Rect2] = EncounterLayout.opening_hand_cards(count, count, OPENING_AREA)
	var turns: Array[float] = EncounterLayout.opening_hand_turns(count, count)
	if cards.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(_corners(cards[0], turns[0])[0], Vector2.ZERO)
	for index: int in count:
		for corner: Vector2 in _corners(cards[index], turns[index]):
			box = box.expand(corner)
	return box


func test_a_pile_is_found_by_its_zone_and_its_player() -> void:
	var regions: Dictionary[String, Rect2] = EncounterLayout.regions(Vector2(1920, 1080))

	for zone_kind: MmZone.Kind in [MmZone.Kind.LIBRARY, MmZone.Kind.GRAVEYARD, MmZone.Kind.EXILE]:
		for is_hero: bool in [true, false]:
			assert_true(regions.has(EncounterLayout.pile_key(zone_kind, is_hero)))
	assert_eq(EncounterLayout.pile_key(MmZone.Kind.GRAVEYARD, true), "hero_graveyard")
	assert_eq(EncounterLayout.pile_key(MmZone.Kind.LIBRARY, false), "villain_library")


func test_the_portrait_is_six_times_a_portraits_pixels_and_the_step_column_is_narrower() -> void:
	var panel_rect: Rect2 = EncounterLayout.regions(Vector2(1920, 1080))["hero_panel"]

	var parts: Dictionary[String, Rect2] = EncounterLayout.panel(panel_rect)

	assert_eq(parts["portrait"].size, Vector2(192, 192), "32 pixels drawn six times over (A483).")
	assert_eq(parts["life"].size, Vector2(69, 50))
	for step: int in 12:
		assert_eq(parts["step_%d" % step].size.x, 98.0)
		assert_true(panel_rect.encloses(parts["step_%d" % step]))


func test_the_pass_button_is_over_the_info_panel_and_as_wide() -> void:
	for screen: Vector2 in SIZES:
		var regions: Dictionary[String, Rect2] = EncounterLayout.regions(screen)
		var button: Rect2 = regions["pass"]
		var info: Rect2 = regions["info"]

		assert_eq(button.position.x, info.position.x, "The same left edge at %s." % screen)
		assert_eq(button.size.x, info.size.x)
		assert_eq(button.size.y, EncounterLayout.PASS_HEIGHT)
		assert_almost_eq(info.position.y - button.end.y, EncounterLayout.PASS_GAP, 0.01, "Directly above it.")
		assert_gt(button.position.y, regions["hero_lands"].end.y, "Clear of the Hero's lands.")
		assert_almost_eq(info.end.y, screen.y - EncounterLayout.INFO_PAD, 0.01, "The Info Panel still ends where it did.")
