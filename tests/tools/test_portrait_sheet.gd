extends GutTest
## The review sheet of a Portrait drawn after a Magic character: its card's art beside the
## Portrait and the Pain Portrait at 1×, 2× and 6×, each on the panel's ground.

## In steps of 1/255, so it reads back from an 8-bit image unchanged.
const GROUND: Color = Color8(40, 48, 60)


func test_the_art_is_scaled_to_the_height_of_a_portrait_at_6x() -> void:
	var sheet: Image = PortraitSheet.compose(_art(400, 300), _portrait(Color.RED), _portrait(Color.BLUE), GROUND)

	var art: Rect2i = PortraitSheet.art_rect(Vector2i(400, 300))
	assert_eq(art.size, Vector2i(256, 192))
	assert_eq(sheet.get_pixelv(art.position + Vector2i(10, 10)), Color.YELLOW)


func test_both_portraits_are_drawn_at_each_scale() -> void:
	var sheet: Image = PortraitSheet.compose(_art(400, 300), _portrait(Color.RED), _portrait(Color.BLUE), GROUND)

	for scale: int in PortraitSheet.SCALES:
		var portrait: Rect2i = PortraitSheet.portrait_rect(Vector2i(400, 300), scale, false)
		var pain: Rect2i = PortraitSheet.portrait_rect(Vector2i(400, 300), scale, true)
		assert_eq(portrait.size, Vector2i(32, 32) * scale)
		assert_eq(pain.size, Vector2i(32, 32) * scale)
		assert_eq(sheet.get_pixelv(portrait.position + Vector2i(1, 1) * scale), Color.RED, "portrait at %d×" % scale)
		assert_eq(sheet.get_pixelv(pain.position + Vector2i(1, 1) * scale), Color.BLUE, "pain at %d×" % scale)


func test_a_transparent_pixel_shows_the_panels_ground() -> void:
	var sheet: Image = PortraitSheet.compose(_art(400, 300), _portrait(Color.RED), _portrait(Color.BLUE), GROUND)

	var portrait: Rect2i = PortraitSheet.portrait_rect(Vector2i(400, 300), 6, false)
	assert_eq(sheet.get_pixelv(portrait.position), GROUND)


func test_nothing_on_the_sheet_overlaps() -> void:
	var rects: Array[Rect2i] = [PortraitSheet.art_rect(Vector2i(626, 457))]
	for scale: int in PortraitSheet.SCALES:
		rects.append(PortraitSheet.portrait_rect(Vector2i(626, 457), scale, false))
		rects.append(PortraitSheet.portrait_rect(Vector2i(626, 457), scale, true))
	var size: Vector2i = PortraitSheet.sheet_size(Vector2i(626, 457))

	for i: int in rects.size():
		assert_true(Rect2i(Vector2i.ZERO, size).encloses(rects[i]), "rect %d is on the sheet" % i)
		for j: int in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "rects %d and %d overlap" % [i, j])


func _art(width: int, height: int) -> Image:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.YELLOW)
	return image


## A 32 × 32 portrait of [param color] with its top-left pixel left transparent.
func _portrait(color: Color) -> Image:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.set_pixel(0, 0, Color(0, 0, 0, 0))
	return image
