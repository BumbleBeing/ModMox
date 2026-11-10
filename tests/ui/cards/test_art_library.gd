extends GutTest
## Card art is looked up by the Card Definition's file name in content/art/, with its credits
## and focus point in one manifest (A233). A crop keeps the focus point centered unless that
## would show past the art's edge.


func test_a_card_with_art_uses_its_image_and_credits_its_artist() -> void:
	var library: ArtLibrary = ArtLibrary.new()

	assert_not_null(library.texture("grizzly_bears"))
	assert_eq(library.artist("grizzly_bears"), "Jeff A. Menges")


func test_a_card_without_art_has_no_image_and_no_artist() -> void:
	var library: ArtLibrary = ArtLibrary.new()

	assert_null(library.texture("no_such_card"))
	assert_eq(library.artist("no_such_card"), "")


func test_the_focus_point_defaults_to_the_middle() -> void:
	assert_eq(ArtLibrary.new().focus("no_such_card"), Vector2(0.5, 0.5))


func test_a_crop_covers_the_box_keeping_the_art_in_proportion() -> void:
	# Wide art in a square box: the full height, and as much width as keeps it square.
	var crop: Rect2 = ArtLibrary.crop(Vector2(200, 100), Vector2(50, 50), Vector2(0.5, 0.5))

	assert_eq(crop.size, Vector2(0.5, 1.0))
	assert_eq(crop.position, Vector2(0.25, 0.0), "Centered on the focus point.")


func test_a_crop_follows_the_focus_point() -> void:
	var crop: Rect2 = ArtLibrary.crop(Vector2(200, 100), Vector2(50, 50), Vector2(0.4, 0.5))

	assert_almost_eq(crop.get_center().x, 0.4, 0.0001)


func test_a_crop_stops_at_the_arts_edge() -> void:
	var left: Rect2 = ArtLibrary.crop(Vector2(200, 100), Vector2(50, 50), Vector2(0.0, 0.5))
	var right: Rect2 = ArtLibrary.crop(Vector2(200, 100), Vector2(50, 50), Vector2(1.0, 0.5))

	assert_eq(left.position.x, 0.0)
	assert_eq(right.end.x, 1.0)


func test_tall_art_in_a_wide_box_crops_its_height() -> void:
	var crop: Rect2 = ArtLibrary.crop(Vector2(100, 200), Vector2(100, 50), Vector2(0.5, 0.2))

	assert_eq(crop.size, Vector2(1.0, 0.25))
	assert_almost_eq(crop.position.y, 0.075, 0.0001)
