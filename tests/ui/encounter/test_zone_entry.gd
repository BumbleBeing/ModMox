extends GutTest
## One thing in a Zone Window. An Emblem's or a Potion's entry shows each ability on a line
## of its own, a Spent one gray and marked "(used)", and one that can be used glows green,
## brightens under the cursor and takes a click (ADR 0032, A520 and A537).


func test_lines_are_each_cut_and_a_spent_one_is_gray_and_marked_used() -> void:
	var entry: ZoneEntry = _entry()

	entry.show_lines(["{R}: Zap.", "{0}: Draw."], [1])

	assert_eq(entry.line_texts(), ["{R}: Zap.", "{0}: Draw. (used)"] as Array[String])
	assert_false(entry.is_line_spent(0))
	assert_true(entry.is_line_spent(1))
	assert_eq(entry.detail_text(), "{R}: Zap. · {0}: Draw.")
	assert_true(entry.is_detail_cut())
	var drawn: Array[Label] = _line_labels(entry)
	assert_eq(drawn.size(), 2)
	assert_eq(drawn[1].text, "{0}: Draw. (used)")
	assert_eq(drawn[1].get_theme_color("font_color"), ZoneEntry.USED_COLOR)
	assert_eq(drawn[1].text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)


func test_showing_lines_again_replaces_them() -> void:
	var entry: ZoneEntry = _entry()
	entry.show_lines(["One.", "Two."])

	entry.show_lines(["Three."])

	assert_eq(entry.line_texts(), ["Three."] as Array[String])
	assert_eq(_line_labels(entry).size(), 1)


func test_an_entry_takes_no_click_until_it_is_made_usable() -> void:
	var entry: ZoneEntry = _entry()

	assert_false(entry.is_usable())
	assert_null(entry.click_catcher())
	assert_eq(entry.border_color(), PlayerPanel.GOLD)


func test_a_usable_entry_glows_green_brightens_under_the_cursor_and_is_clicked() -> void:
	var entry: ZoneEntry = _entry()
	var clicks: Array[int] = []

	var catcher: ClickCatcher = entry.make_usable()
	catcher.clicked.connect(func() -> void: clicks.append(1))

	assert_true(entry.is_usable())
	assert_eq(entry.border_color(), DecisionClicks.color_of(DecisionClicks.Kind.PLAY), "A card that can be played, not an ability (A537).")
	assert_eq(catcher.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	catcher.mouse_entered.emit()
	assert_eq(entry.modulate, ClickCatcher.BRIGHT, "As a card in hand does.")
	catcher.mouse_exited.emit()
	assert_eq(entry.modulate, Color.WHITE)
	catcher.clicked.emit()
	assert_eq(clicks.size(), 1)


func test_a_potions_art_or_a_gray_square_takes_the_arts_place() -> void:
	var potion: ZoneEntry = _entry()
	var emblem: ZoneEntry = _entry()

	potion.show_picture(PotionArt.new("big_gulp", ZoneEntry.ART_SIZE, true))
	emblem.show_no_art()

	assert_true(potion.picture() is PotionArt)
	assert_true((potion.picture() as PotionArt).is_small())
	assert_eq(potion.picture().get_index(), 0, "Still at the left.")
	assert_eq((emblem.picture() as ColorRect).color, ZoneEntry.NO_ART_COLOR)
	assert_eq(emblem.picture().custom_minimum_size, Vector2(ZoneEntry.ART_SIZE, ZoneEntry.ART_SIZE))


func _entry() -> ZoneEntry:
	var entry: ZoneEntry = ZoneEntry.new("", "Boon", "", PlayerPanel.GOLD)
	add_child_autofree(entry)
	return entry


func _line_labels(entry: ZoneEntry) -> Array[Label]:
	var labels: Array[Label] = []
	for label: Node in entry.find_children("*", "Label", true, false):
		if (label as Label).text.contains("."):
			labels.append(label as Label)
	return labels
