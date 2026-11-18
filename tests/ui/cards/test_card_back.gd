extends GutTest
## A Card Back is the size and shape of a Card Face, edged in the same black border as thick
## all round as a Card Face's is at its sides and top, its picture filling what is inside
## without being stretched.


func test_the_black_border_is_as_wide_as_a_card_faces_sides() -> void:
	# Measured on the source frames: 78 px of black at each side of a 2010 px card.
	assert_almost_eq(CardGeometry.BORDER, 78.0 / 2010.0, 0.0001)


func test_a_card_back_is_a_black_rounded_card_the_size_of_a_card_face() -> void:
	for height: float in [140.0, 380.0]:
		var back: Panel = autofree(CardBack.make(height)) as Panel

		assert_eq(back.size, Vector2(height * CardGeometry.ASPECT, height))
		var style: StyleBoxFlat = back.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.bg_color, Color.BLACK)
		assert_eq(style.corner_radius_top_left, roundi(back.size.x * CardGeometry.CORNER))
		assert_eq(back.clip_children, CanvasItem.CLIP_CHILDREN_AND_DRAW)


func test_its_picture_is_inset_by_the_border_on_every_side() -> void:
	for height: float in [140.0, 380.0]:
		var back: Panel = autofree(CardBack.make(height)) as Panel
		var picture: TextureRect = back.get_child(0) as TextureRect
		var border: float = back.size.x * CardGeometry.BORDER

		assert_almost_eq(picture.position.x, border, 0.001, "Left.")
		assert_almost_eq(picture.position.y, border, 0.001, "Top.")
		assert_almost_eq(back.size.x - picture.position.x - picture.size.x, border, 0.001, "Right.")
		assert_almost_eq(back.size.y - picture.position.y - picture.size.y, border, 0.001, "Bottom.")


func test_its_picture_is_cropped_to_the_shape_it_fills_so_it_is_not_stretched() -> void:
	for height: float in [140.0, 380.0]:
		var back: Panel = autofree(CardBack.make(height)) as Panel
		var picture: TextureRect = back.get_child(0) as TextureRect
		var crop: Rect2 = (picture.texture as AtlasTexture).region

		assert_almost_eq(crop.size.x / crop.size.y, picture.size.x / picture.size.y, 0.001)


func test_the_crop_leaves_out_the_images_own_black_margin() -> void:
	var image_size: Vector2 = Vector2(1429.0, 2000.0)
	var margin: Rect2 = Rect2(image_size * CardBack.PICTURE.position, image_size * CardBack.PICTURE.size)

	var box: Vector2 = CardBack.picture_box(Vector2(140.0 * CardGeometry.ASPECT, 140.0)).size

	var crop: Rect2 = CardBack.crop(image_size, box)

	assert_true(margin.encloses(crop), "It takes nothing from the margin.")
	assert_almost_eq(crop.size.y, margin.size.y, 0.001, "It keeps the picture's whole height.")
	assert_almost_eq(crop.get_center().x, margin.get_center().x, 0.001, "It trims both sides alike.")
