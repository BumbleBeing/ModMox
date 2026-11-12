extends GutTest
## Arrows from a spell to the spell it targets, down the left of the Stack Window (A355).


func test_with_no_arrows_it_takes_no_room() -> void:
	var arrows: StackArrows = StackArrows.new()
	add_child_autofree(arrows)

	arrows.show_arrows([])

	assert_eq(arrows.arrow_count(), 0)
	assert_eq(arrows.custom_minimum_size.x, 0.0)
	assert_eq(StackArrows.width_for(0), 0.0)


func test_it_is_wide_enough_for_its_deepest_arrow() -> void:
	assert_gt(StackArrows.width_for(1), StackArrows.bow(0))
	assert_gt(StackArrows.width_for(2), StackArrows.bow(1))
	assert_gt(StackArrows.width_for(2), StackArrows.width_for(1))


func test_each_arrow_bows_out_further_than_the_one_before() -> void:
	assert_gt(StackArrows.bow(0), 0.0)
	assert_gt(StackArrows.bow(1), StackArrows.bow(0))
	assert_gt(StackArrows.bow(2), StackArrows.bow(1))


func test_an_arrow_runs_from_its_spell_to_its_target_in_its_spells_color() -> void:
	var arrows: StackArrows = StackArrows.new()
	add_child_autofree(arrows)
	var top: Control = _entry(0)
	var bottom: Control = _entry(140)

	arrows.show_arrows([[top, bottom, Color.RED]])
	arrows.size = Vector2(arrows.custom_minimum_size.x, 200)

	assert_eq(arrows.arrow_count(), 1)
	assert_eq(arrows.arrow_color(0), Color.RED)
	assert_eq(arrows.custom_minimum_size.x, StackArrows.width_for(1))
	assert_eq(arrows.arrow_from(0).x, arrows.size.x, "It leaves from the entries' left side.")
	assert_eq(arrows.arrow_to(0).x, arrows.size.x)
	assert_true(arrows.arrow_from(0).y > 0.0 and arrows.arrow_from(0).y < 60.0, "Within the top entry.")
	assert_true(arrows.arrow_to(0).y > 140.0 and arrows.arrow_to(0).y < 200.0, "Within the bottom entry.")


func test_an_arrow_in_and_an_arrow_out_of_one_entry_do_not_meet() -> void:
	var arrows: StackArrows = StackArrows.new()
	add_child_autofree(arrows)
	var top: Control = _entry(0)
	var middle: Control = _entry(70)
	var bottom: Control = _entry(140)

	arrows.show_arrows([[top, middle, Color.RED], [middle, bottom, Color.BLUE]])

	assert_ne(arrows.arrow_to(0).y, arrows.arrow_from(1).y)
	assert_lt(arrows.arrow_to(0).y, arrows.arrow_from(1).y, "The one arriving ends above the one leaving.")


func _entry(top: float) -> Control:
	var entry: Control = Control.new()
	entry.position = Vector2(0, top)
	entry.size = Vector2(200, 60)
	add_child_autofree(entry)
	return entry
