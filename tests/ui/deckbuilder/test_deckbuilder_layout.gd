extends GutTest
## Where the deckbuilder's parts sit at 1920 × 1080, and how a column fans its cards.

var _layout: DeckbuilderLayout


func before_each() -> void:
	_layout = DeckbuilderLayout.new(Vector2(1920, 1080))


func test_no_two_parts_overlap_and_all_are_on_the_screen() -> void:
	var parts: Array[Rect2] = [_layout.top_bar(), _layout.inspector(), _layout.filter_bar(), _layout.collection()]
	for column: int in WorkingDeck.COLUMN_COUNT:
		parts.append(_layout.column(column))
	var screen: Rect2 = Rect2(Vector2.ZERO, _layout.size)

	for index: int in parts.size():
		assert_true(screen.encloses(parts[index]), "Part %d is on the screen." % index)
		for other: int in range(index + 1, parts.size()):
			assert_false(parts[index].intersects(parts[other]), "Parts %d and %d do not overlap." % [index, other])


func test_the_eight_columns_are_equally_wide_and_fill_the_deck_strip() -> void:
	var strip: Rect2 = _layout.deck()

	assert_eq(_layout.column(0).position, strip.position)
	assert_almost_eq(_layout.column(WorkingDeck.LANDS_COLUMN).end.x, strip.end.x, 0.01)
	for column: int in WorkingDeck.COLUMN_COUNT:
		assert_almost_eq(_layout.column(column).size.x, _layout.column(0).size.x, 0.01)
		assert_eq(_layout.column(column).size.y, strip.size.y)


func test_the_inspector_is_as_wide_as_the_encounter_sidebar() -> void:
	assert_eq(_layout.inspector().size.x, EncounterLayout.SIDEBAR_WIDTH)


func test_a_fanned_card_shows_its_name_strip_and_the_last_shows_in_full() -> void:
	var card: float = _layout.column_card_height()

	assert_eq(_layout.fan_offset(0), 0.0)
	assert_almost_eq(_layout.fan_offset(3), 3.0 * (card * DeckbuilderLayout.FAN_SHOWN + DeckbuilderLayout.FAN_GAP), 0.01,
			"Each name strip shows, with a little air under it.")
	assert_true(DeckbuilderLayout.FAN_SHOWN > CardGeometry.TITLE.end.y, "The whole name box shows.")
	assert_eq(_layout.fan_height(0), 0.0)
	assert_almost_eq(_layout.fan_height(1), card, 0.01)
	assert_almost_eq(_layout.fan_height(17), _layout.fan_offset(16) + card, 0.01)


func test_a_column_card_fits_its_column() -> void:
	var width: float = _layout.column_card_height() * CardGeometry.ASPECT

	assert_true(width <= _layout.column(0).size.x - 2.0 * DeckbuilderLayout.COLUMN_PAD)


func test_the_collection_grid_wraps_into_rows_that_fit_the_pane() -> void:
	var across: int = _layout.collection_columns()
	var pane_room: float = _layout.collection().size.x - 2.0 * DeckbuilderLayout.PAD

	assert_gt(across, 1)
	assert_eq(_layout.collection_cell(0).position, Vector2.ZERO)
	assert_true(_layout.collection_cell(across - 1).end.x <= pane_room, "The last card of a row fits.")
	assert_eq(_layout.collection_cell(across).position.x, 0.0, "The next card starts a new row.")
	assert_gt(_layout.collection_cell(across).position.y, _layout.collection_cell(0).end.y)
	assert_eq(_layout.collection_grid_height(0), 0.0)
	assert_eq(_layout.collection_grid_height(across + 1), _layout.collection_cell(across).end.y)


func test_a_column_card_sits_in_the_middle_of_its_column() -> void:
	var column: Rect2 = _layout.column(2)
	var inside: float = column.size.x - 2.0 * DeckbuilderLayout.COLUMN_PAD
	var width: float = _layout.column_card_height() * CardGeometry.ASPECT

	assert_almost_eq(_layout.fan_left(), (inside - width) / 2.0, 0.01)


func test_zooming_the_collection_changes_how_many_cards_fit_across_and_not_the_pane() -> void:
	var pane: Rect2 = _layout.collection()
	var across: int = _layout.collection_columns()

	_layout.collection_card_height = DeckbuilderLayout.COLLECTION_CARD_SMALLEST

	assert_gt(_layout.collection_columns(), across)
	assert_almost_eq(_layout.collection_cell(0).size.y, DeckbuilderLayout.COLLECTION_CARD_SMALLEST, 0.01)
	assert_eq(_layout.collection(), pane)


func test_zooming_the_deck_widens_the_columns_past_the_strip() -> void:
	var fitted: float = _layout.column_card_height()
	assert_false(_layout.columns_overflow())
	assert_almost_eq(_layout.columns_width(), _layout.deck().size.x, 0.01)

	_layout.deck_zoom = 1.5

	assert_almost_eq(_layout.column_card_height(), fitted * 1.5, 0.01)
	assert_true(_layout.columns_overflow())
	assert_almost_eq(_layout.column(1).position.x - _layout.column(0).position.x,
			_layout.column_width() + DeckbuilderLayout.COLUMN_GAP, 0.01)
	assert_almost_eq(_layout.column(0).size.y, _layout.deck().size.y - DeckbuilderLayout.SCROLL_BAR, 0.01,
			"The columns leave room for the sideways scroll bar.")


func test_a_card_dropped_in_a_column_goes_above_the_nearest_name_strip() -> void:
	var step: float = _layout.fan_step()

	assert_eq(_layout.fan_place_at(0.0, 5), 0)
	assert_eq(_layout.fan_place_at(step * 0.4, 5), 0)
	assert_eq(_layout.fan_place_at(step * 0.6, 5), 1)
	assert_eq(_layout.fan_place_at(step * 3.1, 5), 3)
	assert_eq(_layout.fan_place_at(step * 40.0, 5), 5, "Under every card, it goes to the bottom.")
	assert_eq(_layout.fan_place_at(-30.0, 5), 0)



func test_by_default_the_divider_leaves_the_collection_one_and_a_half_rows_tall() -> void:
	var rows: float = DeckbuilderLayout.COLLECTION_ROWS_SHOWN
	var height: float = rows * (DeckbuilderLayout.COLLECTION_CARD_HEIGHT + DeckbuilderLayout.CARD_GAP) \
			- DeckbuilderLayout.CARD_GAP + 2.0 * DeckbuilderLayout.PAD

	assert_almost_eq(_layout.collection().size.y, height, 0.01)
	assert_almost_eq(_layout.collection_height, DeckbuilderLayout.DEFAULT_COLLECTION_HEIGHT, 0.01)
	assert_almost_eq(_layout.deck().position.y, _layout.collection().end.y + DeckbuilderLayout.GUTTER, 0.01)
	assert_almost_eq(_layout.deck().end.y, 1080.0 - DeckbuilderLayout.GUTTER, 0.01)


func test_moving_the_divider_gives_one_pane_the_height_the_other_loses() -> void:
	var collection: Rect2 = _layout.collection()
	var strip: Rect2 = _layout.deck()

	_layout.collection_height += 120.0

	assert_almost_eq(_layout.collection().size.y, collection.size.y + 120.0, 0.01)
	assert_eq(_layout.collection().position, collection.position)
	assert_almost_eq(_layout.deck().position.y, strip.position.y + 120.0, 0.01)
	assert_almost_eq(_layout.deck().size.y, strip.size.y - 120.0, 0.01)
	assert_almost_eq(_layout.column(3).size.y, _layout.deck().size.y, 0.01)
	test_no_two_parts_overlap_and_all_are_on_the_screen()


func test_the_divider_stops_at_a_row_of_the_collection_and_a_card_of_the_deck() -> void:
	_layout.collection_height = 0.0

	assert_almost_eq(_layout.collection().size.y, DeckbuilderLayout.COLLECTION_CARD_HEIGHT + 2.0 * DeckbuilderLayout.PAD,
			0.01, "One whole row at the default zoom.")

	_layout.collection_height = 5000.0

	var card: float = _layout.column_card_height()
	assert_almost_eq(_layout.deck().size.y, DeckbuilderLayout.COLUMN_HEADER + card + 2.0 * DeckbuilderLayout.COLUMN_PAD
			+ DeckbuilderLayout.SCROLL_BAR, 0.01, "Its header, one card at deck zoom 1 and the sideways scroll bar.")
	test_no_two_parts_overlap_and_all_are_on_the_screen()
	_layout.deck_zoom = DeckbuilderLayout.DECK_ZOOM_LARGEST
	_layout.collection_height = 5000.0
	assert_almost_eq(_layout.deck().size.y, DeckbuilderLayout.COLUMN_HEADER + card + 2.0 * DeckbuilderLayout.COLUMN_PAD
			+ DeckbuilderLayout.SCROLL_BAR, 0.01, "The limit does not follow the deck zoom.")


func test_no_card_changes_size_wherever_the_divider_is() -> void:
	var across: int = _layout.collection_columns()
	var cell: Rect2 = _layout.collection_cell(7)
	var card: float = _layout.column_card_height()
	var width: float = _layout.column_width()

	for height: float in [0.0, 500.0, 5000.0]:
		_layout.collection_height = height
		assert_eq(_layout.collection_columns(), across)
		assert_eq(_layout.collection_cell(7), cell)
		assert_almost_eq(_layout.column_card_height(), card, 0.01)
		assert_almost_eq(_layout.column_width(), width, 0.01)


func test_the_divider_is_the_gutter_and_is_grabbed_a_little_into_either_pane() -> void:
	_layout.collection_height = 450.0
	var divider: Rect2 = _layout.divider()
	var grab: Rect2 = _layout.divider_grab()

	assert_almost_eq(divider.position.y, _layout.collection().end.y, 0.01)
	assert_almost_eq(divider.end.y, _layout.deck().position.y, 0.01)
	assert_eq(divider.position.x, _layout.collection().position.x)
	assert_eq(divider.size.x, _layout.collection().size.x)
	assert_eq(grab, divider.grow_individual(0.0, DeckbuilderLayout.DIVIDER_REACH, 0.0, DeckbuilderLayout.DIVIDER_REACH))
	assert_gt(DeckbuilderLayout.DIVIDER_REACH, 0.0)


## The Collection's cells near the view: the rows it shows when scrolled [param top] pixels
## down, and half a view's rows above and below, so that a little scrolling finds its cards
## already made.
func test_the_collection_cells_near_the_view() -> void:
	var across: int = _layout.collection_columns()
	var row: float = _layout.collection_card_height + DeckbuilderLayout.CARD_GAP
	var view: float = row * 2.0

	assert_eq(_layout.collection_cells_near(0.0, view, 500), Vector2i(0, across * 3),
		"Two rows in view and one under them; none above the top.")
	assert_eq(_layout.collection_cells_near(row * 10.0, view, 500), Vector2i(across * 9, across * 13),
		"Rows 10 and 11 in view, with row 9 above and row 12 below.")
	assert_eq(_layout.collection_cells_near(row * 10.0, view, across * 11 + 2), Vector2i(across * 9, across * 11 + 2),
		"No further than the last card.")
	assert_eq(_layout.collection_cells_near(0.0, view, 0), Vector2i(0, 0))
	assert_eq(_layout.collection_cells_near(row * 10.0, view, 500, 0.0), Vector2i(across * 10, across * 12),
		"With no margin, only the rows in view.")
