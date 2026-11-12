extends GutTest
## The filter bar draws a Collection Filter: a toggle for each color, card type and mana
## value, a place kept for rarity, the sort order and how many cards are showing.

var _bar: FilterBar


func after_each() -> void:
	await wait_process_frames(2)


func test_it_has_a_toggle_for_every_filter_and_a_place_for_rarity() -> void:
	_show(CollectionFilter.new())

	for key: String in ["color:w", "color:u", "color:b", "color:r", "color:g", "multicolor", "colorless",
			"type:Creature", "type:Instant", "type:Sorcery", "type:Artifact", "type:Enchantment", "type:Land",
			"mana:0", "mana:1", "mana:2", "mana:3", "mana:4", "mana:5", "mana:6", "rarity", "sort"]:
		assert_not_null(_bar.toggle(key), key)
	assert_not_null(_bar.search_box())


func test_with_nothing_filtered_it_counts_every_card_and_clear_is_there_but_disabled() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	_show(filter)
	watch_signals(_bar)

	assert_eq(_bar.count_label().text, "111 cards")
	assert_true(_bar.toggle("clear").visible)
	assert_true(_is_clear_disabled())

	_bar.press("clear")

	assert_signal_emit_count(_bar, "changed", 0, "A disabled Clear does nothing.")


func test_with_a_filter_on_it_counts_what_shows_and_clear_can_be_pressed() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	filter.search = "bear"
	filter.colors = [MmCardTypes.CardColor.GREEN]

	_show(filter, 5)

	assert_eq(_bar.count_label().text, "5 of 111")
	assert_eq(_bar.search_box().text, "bear")
	assert_false(_is_clear_disabled())


func test_a_toggle_that_is_on_is_drawn_differently_from_one_that_is_off() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	filter.colors = [MmCardTypes.CardColor.RED]
	filter.mana_values = [6]

	_show(filter, 9)

	assert_eq(_icon_alpha("color:r"), 1.0)
	assert_eq(_icon_alpha("mana:6"), 1.0)
	assert_almost_eq(_icon_alpha("color:g"), FilterBar.OFF_ALPHA, 0.001)
	assert_almost_eq(_icon_alpha("multicolor"), FilterBar.OFF_ALPHA, 0.001)


func test_clicking_a_toggle_changes_the_filter_and_says_so() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	_show(filter)
	watch_signals(_bar)

	_bar.press("color:r")
	_bar.press("multicolor")
	_bar.press("type:Instant")
	_bar.press("mana:6")

	assert_eq(filter.colors, [MmCardTypes.CardColor.RED] as Array[MmCardTypes.CardColor])
	assert_true(filter.multicolor)
	assert_eq(filter.card_types, [MmCardTypes.CardType.INSTANT] as Array[MmCardTypes.CardType])
	assert_eq(filter.mana_values, [6] as Array[int])
	assert_signal_emit_count(_bar, "changed", 4)
	assert_eq(_icon_alpha("color:r"), 1.0)

	_bar.press("color:r")

	assert_eq(filter.colors.size(), 0, "A second click turns it off.")
	assert_almost_eq(_icon_alpha("color:r"), FilterBar.OFF_ALPHA, 0.001)


func test_typing_in_the_search_box_changes_the_filter() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	_show(filter)
	watch_signals(_bar)

	_bar.search_box().text = "knight"
	_bar.search_box().text_changed.emit("knight")

	assert_eq(filter.search, "knight")
	assert_signal_emit_count(_bar, "changed", 1)
	assert_false(_is_clear_disabled())


func test_choosing_a_sort_order_changes_the_filter() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	_show(filter)

	_bar.sort_box().select(CollectionFilter.SortKey.NAME)
	_bar.sort_box().item_selected.emit(CollectionFilter.SortKey.NAME)

	assert_eq(filter.sort_key, CollectionFilter.SortKey.NAME)
	assert_true(_is_clear_disabled(), "A sort order is not a filter.")


func test_clear_turns_everything_off_and_keeps_the_sort_order() -> void:
	var filter: CollectionFilter = CollectionFilter.new()
	filter.search = "bear"
	filter.colorless = true
	filter.sort_key = CollectionFilter.SortKey.TYPE
	_show(filter, 3)

	_bar.press("clear")

	assert_false(filter.is_active())
	assert_eq(filter.sort_key, CollectionFilter.SortKey.TYPE)
	assert_eq(_bar.search_box().text, "")
	assert_almost_eq(_icon_alpha("colorless"), FilterBar.OFF_ALPHA, 0.001)
	assert_true(_is_clear_disabled())


func _show(filter: CollectionFilter, shown: int = 111) -> void:
	_bar = FilterBar.new()
	add_child_autofree(_bar)
	_bar.setup(filter, shown, 111)


func _icon_alpha(key: String) -> float:
	return (_bar.toggle(key).get_child(0) as Control).modulate.a


func _is_clear_disabled() -> bool:
	return (_bar.toggle("clear") as Button).disabled
