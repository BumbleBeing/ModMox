extends GutTest
## The Soldier Shadow: where the bottom of the Menu Soldier's sprite is black, his soles or his
## spear touch the window, and it is shaded there, half black, in the window's own dither
## blocks: solid under him and dithered away below. It fades in and out rapidly as he lifts
## and sets down a foot or his spear, and takes each flash's color on the frame he flashes.

const SPRITE: String = "res://ui/sprites/menu/soldier_%s.png"
## The spear's butt and both boots, in the sprite's columns.
const STANDING: Array[int] = [4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]


func test_he_touches_the_window_wherever_his_soles_row_is_black() -> void:
	assert_eq_deep(SoldierShadow.contacts_of(_image("idle_0")), STANDING)


func test_a_lifted_foot_casts_no_shadow() -> void:
	var contacts: Array[int] = SoldierShadow.contacts_of(_image("haste_0"))

	assert_eq(contacts, [4, 5, 6, 15, 16, 17, 18, 19, 20] as Array[int], "the left boot is up")


func test_only_black_counts_not_a_colored_glow_beside_his_feet() -> void:
	assert_eq_deep(SoldierShadow.contacts_of(_image("protection_0"), 1), STANDING)


func test_a_frame_drawn_up_touches_the_ground_with_the_row_that_lands_on_it() -> void:
	assert_eq(SoldierShadow.contacts_of(_image("protection_1"), 1), STANDING,
			"lowered in its sprite: he still stands")
	assert_eq(SoldierShadow.contacts_of(_image("flying_1"), 1), [] as Array[int],
			"not lowered: he is off the ground")


func test_the_shadow_is_half_black() -> void:
	assert_eq(SoldierShadow.COLOR, Color(0, 0, 0, 0.5))


func test_it_fades_rapidly() -> void:
	assert_between(SoldierShadow.FADE, 0.01, 0.1, "seconds to fade fully in or out")


func test_a_new_shadow_lies_fully_under_where_he_stands_in_black() -> void:
	var shadow: SoldierShadow = SoldierShadow.new(STANDING)

	assert_eq_deep(shadow.columns(), STANDING)
	for column: int in STANDING:
		assert_eq(shadow.color_of(column), SoldierShadow.COLOR)


func test_a_lifted_foot_fades_out_rapidly() -> void:
	var shadow: SoldierShadow = SoldierShadow.new(STANDING)
	var lifted: Array[int] = SoldierShadow.contacts_of(_image("haste_0"))

	shadow.advance(SoldierShadow.FADE / 2, lifted, "haste_0")
	assert_almost_eq(shadow.color_of(10).a, 0.25, 0.001, "half faded under the lifted boot")
	assert_eq(shadow.color_of(15), SoldierShadow.COLOR, "the planted boot keeps its shadow")
	shadow.advance(SoldierShadow.FADE / 2, lifted, "haste_0")

	assert_does_not_have(shadow.columns(), 10, "gone")
	assert_eq(shadow.color_of(10).a, 0.0)


func test_a_foot_set_down_fades_in_rapidly() -> void:
	var lifted: Array[int] = SoldierShadow.contacts_of(_image("haste_0"))
	var shadow: SoldierShadow = SoldierShadow.new(lifted)

	shadow.advance(SoldierShadow.FADE / 4, STANDING, "idle_0")
	assert_almost_eq(shadow.color_of(10).a, 0.125, 0.001)
	shadow.advance(SoldierShadow.FADE, STANDING, "idle_0")

	assert_eq(shadow.color_of(10), SoldierShadow.COLOR, "fully in, and no further")


func test_it_takes_a_flashs_color_on_the_frame_he_flashes() -> void:
	var shadow: SoldierShadow = SoldierShadow.new(STANDING)

	shadow.advance(0.001, STANDING, "flash_red")

	var red: Color = SoldierAnimations.FLASH_COLORS["flash_red"]
	assert_eq(shadow.color_of(12), Color(red, 0.5), "at once, half see-through like the black")


func test_after_the_flash_its_color_fades_back_to_black_rapidly() -> void:
	var shadow: SoldierShadow = SoldierShadow.new(STANDING)
	shadow.advance(0.12, STANDING, "flash_green")

	shadow.advance(SoldierShadow.FADE / 2, STANDING, "deathtouch_0")
	var green: Color = SoldierAnimations.FLASH_COLORS["flash_green"]
	assert_eq(shadow.color_of(12), Color(Color.BLACK.lerp(green, 0.5), 0.5), "halfway back")
	shadow.advance(SoldierShadow.FADE / 2, STANDING, "deathtouch_0")

	assert_eq(shadow.color_of(12), SoldierShadow.COLOR)


func test_it_tells_whether_anything_changed_so_it_is_redrawn_only_then() -> void:
	var shadow: SoldierShadow = SoldierShadow.new(STANDING)

	assert_false(shadow.advance(0.02, STANDING, "idle_0"), "standing still")
	assert_true(shadow.advance(0.02, [4, 5, 6] as Array[int], "haste_0"), "a fade begins")
	assert_true(shadow.advance(0.001, [4, 5, 6] as Array[int], "flash_white"), "a flash")


func test_its_blocks_are_the_dithers_size_on_the_windows_grid() -> void:
	var blocks: Array[Rect2] = SoldierShadow.blocks(STANDING, 100.0, 8, 95.0, 40.0)

	assert_gt(blocks.size(), 0)
	for block: Rect2 in blocks:
		assert_eq(block.size, Vector2.ONE * DitherShading.BLOCK)
		assert_eq(posmod(int(block.position.x) - 95, DitherShading.BLOCK), 0, "on the grid across")
		assert_eq(posmod(int(block.position.y) - 40, DitherShading.BLOCK), 0, "on the grid down")
		assert_between(block.position.y, 40.0, 40.0 + DitherShading.BLOCK * (SoldierShadow.COVERAGE.size() - 1))


func test_it_lies_only_under_the_black_columns() -> void:
	var blocks: Array[Rect2] = SoldierShadow.blocks(STANDING, 100.0, 8, 95.0, 40.0)
	var columns: Dictionary[int, bool] = {}

	for block: Rect2 in blocks:
		var column: int = floori((block.get_center().x - 100.0) / 8)
		assert_has(STANDING, column, "the block at %s" % block.position)
		columns[column] = true

	assert_eq(columns.size(), STANDING.size(), "every black column is shaded")


func test_it_is_solid_under_him_then_dithered_away() -> void:
	var rows: Array[Array] = _columns_by_row(SoldierShadow.blocks(STANDING, 100.0, 8, 95.0, 40.0), 40.0)

	assert_eq(rows.size(), 4)
	assert_eq_deep(rows[1], rows[0])
	assert_almost_eq(float(rows[2].size()), rows[0].size() / 2.0, 1.0, "half of the solid row")
	assert_almost_eq(float(rows[3].size()), rows[0].size() / 2.0, 1.0)
	for x: float in rows[2]:
		assert_does_not_have(rows[3], x, "checkered: the last row fills the gaps of the one above")


## The left edge of every block in each row of [param blocks], the top row first.
func _columns_by_row(blocks: Array[Rect2], top: float) -> Array[Array]:
	var rows: Array[Array] = []
	for block: Rect2 in blocks:
		var row: int = int(block.position.y - top) / DitherShading.BLOCK
		while rows.size() <= row:
			rows.append([])
		rows[row].append(block.position.x)
	for row: Array in rows:
		row.sort()
	return rows


func _image(frame: String) -> Image:
	return (load(SPRITE % frame) as Texture2D).get_image()
