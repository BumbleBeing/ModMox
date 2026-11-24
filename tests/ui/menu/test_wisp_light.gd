extends GutTest
## The Wisp Light: when the Wisp comes near the main menu's window's top or either side, the
## Soldier Shadow turned to light lies just inside that edge, in the Wisp's color at half
## strength, on the window's own dither grid, longer the nearer the Wisp is. Never on the
## stepped corners or the bottom edge.

const WINDOW: Rect2 = Rect2(500, 300, 408, 460)
## The window's stepped corner and its rim: where its dither grid starts across.
const CORNER: int = WindowLook.CORNER
const SIZE: float = WispFlight.SIZE


func test_there_is_none_while_the_wisp_is_farther_off_than_its_reach() -> void:
	var far: float = WispLight.REACH + 1.0

	assert_eq(_blocks(_above(far)).size(), 0, "above the top")
	assert_eq(_blocks(_beside(-1, far)).size(), 0, "left of the window")
	assert_eq(_blocks(_beside(1, far)).size(), 0, "right of the window")


func test_it_lies_just_inside_the_top_centered_under_the_wisp() -> void:
	var wisp: Rect2 = _above(30.0, 40.0)
	var blocks: Array[Rect2] = _blocks(wisp)

	assert_gt(blocks.size(), 0)
	var middle: float = 0.0
	for block: Rect2 in blocks:
		assert_between(block.position.y, WINDOW.position.y, WINDOW.position.y + DitherShading.BLOCK * 3.0)
		middle += block.get_center().x
	assert_almost_eq(middle / blocks.size(), wisp.get_center().x, DitherShading.BLOCK * 1.0, "under the Wisp")


func test_it_lies_just_inside_either_side_level_with_the_wisp() -> void:
	for side: int in [-1, 1]:
		var wisp: Rect2 = _beside(side, 30.0, 50.0)
		var blocks: Array[Rect2] = _blocks(wisp)
		var edge: float = WINDOW.position.x if side < 0 else WINDOW.end.x
		var middle: float = 0.0

		assert_gt(blocks.size(), 0)
		for block: Rect2 in blocks:
			var inside: float = block.position.x - edge if side < 0 else edge - block.end.x
			assert_between(inside, 0.0, DitherShading.BLOCK * 4.0, "just inside the side")
			assert_eq(posmod(int(block.position.y - WINDOW.position.y), DitherShading.BLOCK), 0, "on the grid down")
			middle += block.get_center().y
		assert_almost_eq(middle / blocks.size(), wisp.get_center().y, DitherShading.BLOCK * 1.0, "level with it")


func test_it_is_longer_the_nearer_the_wisp_is() -> void:
	var near: Array[Rect2] = _blocks(_above(10.0))
	var farther: Array[Rect2] = _blocks(_above(60.0))

	assert_gt(near.size(), farther.size())
	assert_gt(farther.size(), 0)
	assert_lte(_extent(_blocks(_above(0.0))), WispLight.LONGEST + DitherShading.BLOCK, "three Wisps long at most")
	assert_almost_eq(_extent(_blocks(_above(0.0))), WispLight.LONGEST, DitherShading.BLOCK * 2.0)


func test_it_is_on_the_windows_dither_grid_four_blocks_deep_solid_then_checkered() -> void:
	var rows: Dictionary[int, Array] = {}
	for block: Rect2 in _blocks(_above(0.0)):
		assert_eq(block.size, Vector2.ONE * DitherShading.BLOCK)
		assert_eq(posmod(int(block.position.x - WINDOW.position.x) - CORNER, DitherShading.BLOCK), 0, "on the grid across")
		assert_eq(posmod(int(block.position.y - WINDOW.position.y), DitherShading.BLOCK), 0, "on the grid down")
		var row: int = int(block.position.y - WINDOW.position.y) / DitherShading.BLOCK
		if not rows.has(row):
			rows[row] = []
		rows[row].append(block.position.x)

	assert_eq(rows.keys().size(), 4, "four deep")
	var middle: Array = rows[0].filter(func(x: float) -> bool: return absf(x - _above(0.0).get_center().x) < 30.0)
	assert_eq(rows[1].filter(func(x: float) -> bool: return middle.has(x)).size(), middle.size(), "solid under the Wisp")
	for x: float in rows[2]:
		assert_does_not_have(rows[3], x, "checkered: the last row fills the gaps of the one above")
	assert_almost_eq(float(rows[2].size()), rows[0].size() / 2.0, rows[0].size() / 4.0, "dithered away")


func test_its_ends_are_dithered_away() -> void:
	var top: Array[float] = []
	for block: Rect2 in _blocks(_above(0.0)):
		if is_equal_approx(block.position.y, WINDOW.position.y):
			top.append(block.position.x)
	top.sort()

	var gaps: int = 0
	for at: int in top.size() - 1:
		if top[at + 1] - top[at] > DitherShading.BLOCK:
			gaps += 1
	assert_gt(gaps, 0, "the solid top row checkered at its ends")


func test_it_is_the_wisps_color_at_half_strength() -> void:
	var red: Color = SoldierAnimations.FLASH_COLORS["flash_red"]

	assert_eq(WispLight.color_of(red, 1.0), Color(red, 0.5))
	assert_eq(WispLight.color_of(red, 0.5), Color(red, 0.25), "fading in with the Wisp")


func test_near_a_corner_both_edges_light_but_never_the_corner_itself() -> void:
	var wisp: Rect2 = Rect2(WINDOW.position - Vector2.ONE * (SIZE + 6.0), Vector2.ONE * SIZE)
	var blocks: Array[Rect2] = _blocks(wisp)
	var on_top: int = 0
	var on_left: int = 0

	for block: Rect2 in blocks:
		if block.position.y < WINDOW.position.y + DitherShading.BLOCK * 4:
			on_top += 1
			assert_gte(block.position.x, WINDOW.position.x + CORNER, "past the corner")
		else:
			on_left += 1
			assert_gte(block.position.y, WINDOW.position.y + CORNER, "below the corner")
	assert_gt(on_top, 0)
	assert_gt(on_left, 0)


func test_it_stays_off_the_far_corners_too() -> void:
	var along_the_top: Array[Rect2] = _blocks(_above(0.0, WINDOW.size.x / 2))
	var down_the_right: Array[Rect2] = _blocks(_beside(1, 0.0, WINDOW.size.y / 2))

	assert_gt(along_the_top.size(), 0)
	assert_gt(down_the_right.size(), 0)
	for block: Rect2 in along_the_top:
		assert_lte(block.end.x, WINDOW.end.x - CORNER, "short of the top right corner")
	for block: Rect2 in down_the_right:
		assert_lte(block.end.y, WINDOW.end.y - CORNER, "short of the bottom right corner")


func test_it_never_lights_the_bottom_edge() -> void:
	var under: Rect2 = Rect2(Vector2(WINDOW.get_center().x - SIZE / 2, WINDOW.end.y + 6.0), Vector2.ONE * SIZE)

	assert_eq(_blocks(under).size(), 0)


func _blocks(wisp: Rect2) -> Array[Rect2]:
	return WispLight.blocks(wisp, WINDOW, CORNER)


## The Wisp [param gap] above the window's top, [param across] right of its middle.
func _above(gap: float, across: float = 0.0) -> Rect2:
	var middle: float = WINDOW.get_center().x + across
	return Rect2(Vector2(middle - SIZE / 2, WINDOW.position.y - gap - SIZE), Vector2.ONE * SIZE)


## The Wisp [param gap] beside the window on [param side] (-1 left, 1 right), [param down]
## below its middle.
func _beside(side: int, gap: float, down: float = 0.0) -> Rect2:
	var top: float = WINDOW.get_center().y + down - SIZE / 2
	var left: float = WINDOW.position.x - gap - SIZE if side < 0 else WINDOW.end.x + gap
	return Rect2(Vector2(left, top), Vector2.ONE * SIZE)


## How far across [param blocks] reach, from the first's left to the last's right.
func _extent(blocks: Array[Rect2]) -> float:
	var left: float = INF
	var right: float = -INF
	for block: Rect2 in blocks:
		left = minf(left, block.position.x)
		right = maxf(right, block.end.x)
	return right - left
