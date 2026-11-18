extends GutTest
## The review sheet of a Portrait drawn after a Magic character: its card's art beside the
## Portrait, the Pain Portrait and the Blink Portrait at 1×, 2× and 6×, each on the panel's
## ground. A Portrait without its Blink Portrait yet has a sheet of the other two.

## In steps of 1/255, so it reads back from an 8-bit image unchanged.
const GROUND: Color = Color8(40, 48, 60)
const ART: Vector2i = Vector2i(400, 300)


func test_the_art_is_scaled_to_the_height_of_a_portrait_at_6x() -> void:
	var sheet: Image = PortraitSheet.compose(_art(ART), _pictures(3), GROUND)

	var art: Rect2i = PortraitSheet.art_rect(ART)
	assert_eq(art.size, Vector2i(256, 192))
	assert_eq(sheet.get_pixelv(art.position + Vector2i(10, 10)), Color.YELLOW)


func test_every_picture_is_drawn_at_each_scale() -> void:
	var colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN]
	var sheet: Image = PortraitSheet.compose(_art(ART), _pictures(3), GROUND)

	for scale: int in PortraitSheet.SCALES:
		for index: int in 3:
			var rect: Rect2i = PortraitSheet.portrait_rect(ART, 3, scale, index)
			assert_eq(rect.size, Vector2i(32, 32) * scale)
			assert_eq(sheet.get_pixelv(rect.position + Vector2i(1, 1) * scale), colors[index],
					"picture %d at %d×" % [index, scale])


func test_a_transparent_pixel_shows_the_panels_ground() -> void:
	var sheet: Image = PortraitSheet.compose(_art(ART), _pictures(3), GROUND)

	var portrait: Rect2i = PortraitSheet.portrait_rect(ART, 3, 6, 0)
	assert_eq(sheet.get_pixelv(portrait.position), GROUND)


func test_a_sheet_of_two_pictures_is_narrower_and_draws_both() -> void:
	var sheet: Image = PortraitSheet.compose(_art(ART), _pictures(2), GROUND)

	assert_eq(sheet.get_size(), PortraitSheet.sheet_size(ART, 2))
	assert_lt(PortraitSheet.sheet_size(ART, 2).x, PortraitSheet.sheet_size(ART, 3).x)
	var pain: Rect2i = PortraitSheet.portrait_rect(ART, 2, 1, 1)
	assert_eq(sheet.get_pixelv(pain.position + Vector2i(1, 1)), Color.BLUE)


func test_nothing_on_the_sheet_overlaps() -> void:
	for count: int in [2, 3]:
		var rects: Array[Rect2i] = [PortraitSheet.art_rect(Vector2i(626, 457))]
		for scale: int in PortraitSheet.SCALES:
			for index: int in count:
				rects.append(PortraitSheet.portrait_rect(Vector2i(626, 457), count, scale, index))
		var size: Vector2i = PortraitSheet.sheet_size(Vector2i(626, 457), count)

		for i: int in rects.size():
			assert_true(Rect2i(Vector2i.ZERO, size).encloses(rects[i]), "rect %d of %d is on the sheet" % [i, count])
			for j: int in range(i + 1, rects.size()):
				assert_false(rects[i].intersects(rects[j]), "rects %d and %d of %d overlap" % [i, j, count])


func _art(size: Vector2i) -> Image:
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.YELLOW)
	return image


## [param count] 32 × 32 pictures, red, blue and green, each with its top-left pixel left
## transparent.
func _pictures(count: int) -> Array[Image]:
	var colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN]
	var pictures: Array[Image] = []
	for index: int in count:
		var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(colors[index])
		image.set_pixel(0, 0, Color(0, 0, 0, 0))
		pictures.append(image)
	return pictures
