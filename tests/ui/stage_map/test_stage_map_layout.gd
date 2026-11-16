extends GutTest
## Where the Stage Map draws things (milestone 17): cells a row 320 pixels tall and a column
## 192 wide, each Node within its own cell, and a view that frames the Hero's row and the
## two rows ahead under the Run Bar, stopping at both ends of the map.


## S1: the view frames the Hero's row and the two ahead, and stops at both ends.
func test_the_view_frames_the_heros_row_and_stops_at_both_ends_of_the_map() -> void:
	assert_eq(StageMapLayout.framed_row(1.0), 1.0)
	assert_eq(StageMapLayout.framed_row(4.5), 4.5)
	assert_eq(StageMapLayout.framed_row(9.0), 8.0, "The Boss's row stays at the top.")
	assert_eq(StageMapLayout.framed_row(10.0), 8.0)


## S1: the framed row and the two ahead are under the Run Bar and on the screen; the next
## is above it.
func test_the_framed_row_and_the_two_ahead_fill_the_screen_under_the_run_bar() -> void:
	for ahead: int in 3:
		var y: float = StageMapLayout.cell_center(4 + ahead, 5, 4.0).y
		assert_between(y, StageMapLayout.BAR_HEIGHT + StageMapLayout.ICON_RADIUS, StageMapLayout.SCREEN.y - StageMapLayout.ICON_RADIUS)
	assert_lt(StageMapLayout.cell_center(7, 5, 4.0).y, StageMapLayout.BAR_HEIGHT)


func test_all_nine_columns_fit_across_the_screen() -> void:
	assert_gt(StageMapLayout.cell_center(1, 1, 1.0).x - StageMapLayout.COLUMN_PITCH / 2.0, -1.0)
	assert_lt(StageMapLayout.cell_center(1, 9, 1.0).x + StageMapLayout.COLUMN_PITCH / 2.0, StageMapLayout.SCREEN.x + 1.0)


func test_a_node_stays_inside_its_cell_however_far_it_strays() -> void:
	var node: MapNode = MapNode.new()
	node.row = 3
	node.column = 2
	var center: Vector2 = StageMapLayout.cell_center(3, 2, 1.0)

	for offset: Vector2 in [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1)]:
		var spot: Vector2 = StageMapLayout.node_spot(node, offset, 1.0)
		assert_lte(absf(spot.x - center.x) + StageMapLayout.ICON_RADIUS, StageMapLayout.COLUMN_PITCH / 2.0)
		assert_lte(absf(spot.y - center.y) + StageMapLayout.ICON_RADIUS, StageMapLayout.ROW_PITCH / 2.0)
	assert_eq(StageMapLayout.node_spot(node, Vector2(1, -1), 1.0) - center, Vector2(40, -80))


func test_a_point_finds_the_node_drawn_under_it() -> void:
	var run: Run = Run.debug(7)
	var visit: StageVisit = run.stage_visit
	var start: MapNode = visit.node()
	var spot: Vector2 = StageMapLayout.node_spot(start, visit.offsets[start.id], 1.0)

	assert_eq(StageMapLayout.node_at(spot + Vector2(20, 0), visit, 1.0), start.id)
	assert_eq(StageMapLayout.node_at(spot + Vector2(0, 600), visit, 1.0), -1)


func test_a_longer_link_takes_longer_to_glide_and_the_game_speed_scales_it() -> void:
	var from: MapNode = MapNode.new()
	from.row = 3
	from.column = 5
	var near: MapNode = MapNode.new()
	near.row = 4
	near.column = 5
	var far: MapNode = MapNode.new()
	far.row = 5
	far.column = 6

	assert_eq(StageMapLayout.glide_seconds(from, near, GameSpeed.Speed.BLAZING), 0.8)
	assert_gt(StageMapLayout.glide_seconds(from, far, GameSpeed.Speed.BLAZING), 1.6)
	assert_almost_eq(StageMapLayout.glide_seconds(from, near, GameSpeed.Speed.NORMAL), 1.6, 0.0001)


## ADR 0038: the Map Backdrop meets the screen's bottom with the view at the Start, and
## still covers the screen with the view at its far end.
func test_the_map_backdrop_covers_the_screen_at_both_ends_of_the_scroll() -> void:
	var at_start: Rect2 = StageMapLayout.map_backdrop_rect(1.0)
	var at_end: Rect2 = StageMapLayout.map_backdrop_rect(StageMapLayout.framed_row(StageMap.ROWS))

	assert_eq(at_start.size, Vector2(StageMapLayout.MAP_BACKDROP_SIZE) * StageMapLayout.BACKDROP_PIXEL)
	assert_eq(at_start.size.x, StageMapLayout.SCREEN.x)
	assert_eq(at_start.end.y, StageMapLayout.SCREEN.y)
	assert_lte(at_end.position.y, 0.0)
	assert_gte(at_end.end.y, StageMapLayout.SCREEN.y)


## ADR 0038: it scrolls exactly with the Nodes.
func test_the_map_backdrop_scrolls_with_the_nodes() -> void:
	for scroll: float in [1.0, 3.5, 8.0]:
		assert_eq(StageMapLayout.map_backdrop_rect(scroll).position.y - StageMapLayout.cell_center(4, 5, scroll).y,
				StageMapLayout.map_backdrop_rect(1.0).position.y - StageMapLayout.cell_center(4, 5, 1.0).y)


## ADR 0038: a Node's halo is a 32 x 32 pixel circle, drawn whole pixels at a time, a tenth
## wider than the three 4-pixel bands it was.
func test_a_nodes_halo_is_a_32_pixel_circle_a_tenth_wider_than_its_bands() -> void:
	var radius: float = StageMapLayout.ICON_RADIUS

	assert_eq(StageMapLayout.HALO_PIXELS, 32)
	assert_eq(StageMapLayout.halo_scale(radius), 3, "(32 + 12) x 1.1 x 2 is nearest 3 x 32.")
	assert_eq(StageMapLayout.halo_scale(StageMapLayout.BOSS_RADIUS), 4)


## ADR 0038: it is slate at half opacity next to the Node, fainter outward, and clear
## outside the circle.
func test_a_nodes_halo_is_half_opaque_next_to_it_and_fades_outward() -> void:
	var radius: float = StageMapLayout.ICON_RADIUS
	var scale: int = StageMapLayout.halo_scale(radius)
	var last: float = 1.0
	var seen: Array[float] = []
	for x: int in range(16, 32):
		var alpha: float = StageMapLayout.halo_alpha(x, 16, radius, scale)
		assert_lte(alpha, last, "Never darker further out.")
		last = alpha
		if not seen.has(alpha):
			seen.append(alpha)

	assert_eq(seen, [0.5, 0.3, 0.15] as Array[float])
	assert_eq(StageMapLayout.halo_alpha(0, 0, radius, scale), 0.0, "Its corners are clear.")
