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

