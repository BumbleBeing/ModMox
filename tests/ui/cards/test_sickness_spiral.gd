extends GutTest
## The Sickness Spiral turns over the art of a summoning sick creature: 30 frames of pixel
## art in 3 seconds, every spiral on the same frame, drawn at a whole multiple of its size.


func test_the_sheet_holds_every_frame_side_by_side() -> void:
	var sheet: Texture2D = SicknessSpiral.sheet()

	assert_eq(sheet.get_size(), Vector2(SicknessSpiral.FRAME_PIXELS * SicknessSpiral.FRAMES, SicknessSpiral.FRAME_PIXELS))
	assert_eq(SicknessSpiral.region_of(0), Rect2(0, 0, 32, 32))
	assert_eq(SicknessSpiral.region_of(29), Rect2(928, 0, 32, 32))


func test_it_turns_once_every_three_seconds_and_starts_again() -> void:
	assert_eq(SicknessSpiral.frame_at(0.0), 0)
	assert_eq(SicknessSpiral.frame_at(0.1), 1)
	assert_eq(SicknessSpiral.frame_at(1.55), 15)
	assert_eq(SicknessSpiral.frame_at(2.95), 29)
	assert_eq(SicknessSpiral.frame_at(3.0), 0, "The loop starts again.")
	assert_eq(SicknessSpiral.frame_at(7.25), 12, "And again, as long as the game runs.")


func test_it_is_drawn_at_the_largest_whole_multiple_of_its_size_that_leaves_the_art_showing() -> void:
	var most: float = SicknessSpiral.MOST_OF_ART

	assert_eq(SicknessSpiral.side_in(Vector2(200.0, 64.0 / most)), 64.0)
	assert_eq(SicknessSpiral.side_in(Vector2(200.0, 64.0 / most - 1.0)), 32.0, "Never a part of a pixel.")
	assert_eq(SicknessSpiral.side_in(Vector2(96.0 / most, 400.0)), 96.0, "The art's shorter side decides.")
	assert_eq(SicknessSpiral.side_in(Vector2(30.0, 20.0)), 32.0, "Never smaller than it was drawn.")


func test_it_sits_in_the_middle_of_the_art_half_see_through_with_hard_edged_pixels_and_takes_no_clicks() -> void:
	var art: Rect2 = Rect2(10.0, 30.0, 200.0, 140.0)

	var spiral: SicknessSpiral = SicknessSpiral.make(art)
	add_child_autofree(spiral)

	var side: float = SicknessSpiral.side_in(art.size)
	assert_eq(spiral.size, Vector2(side, side))
	assert_almost_eq(spiral.position + spiral.size / 2.0, art.get_center(), Vector2(0.5, 0.5))
	assert_eq(spiral.position, spiral.position.round(), "On whole pixels.")
	assert_eq(spiral.pivot_offset, spiral.size / 2.0, "It turns back about its own middle.")
	assert_eq(spiral.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(spiral.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(spiral.modulate.a, 0.5, "The art shows through it.")


func test_it_shows_the_frame_of_the_time_it_is_given() -> void:
	var spiral: SicknessSpiral = SicknessSpiral.make(Rect2(0.0, 0.0, 200.0, 140.0))
	add_child_autofree(spiral)

	spiral.show_at(0.0)
	assert_eq(spiral.frame(), 0)
	assert_eq((spiral.texture as AtlasTexture).region, SicknessSpiral.region_of(0))
	spiral.show_at(1.25)
	assert_eq(spiral.frame(), 12)
	assert_eq((spiral.texture as AtlasTexture).region, SicknessSpiral.region_of(12))
	assert_eq((spiral.texture as AtlasTexture).atlas, SicknessSpiral.sheet())


func test_two_spirals_made_at_different_times_show_the_same_frame() -> void:
	# The board is rebuilt from every snapshot, so a spiral that counted its own time would
	# start again at each redraw.
	var first: SicknessSpiral = SicknessSpiral.make(Rect2(0.0, 0.0, 200.0, 140.0))
	add_child_autofree(first)
	await wait_seconds(0.25)
	var second: SicknessSpiral = SicknessSpiral.make(Rect2(0.0, 0.0, 200.0, 140.0))
	add_child_autofree(second)
	await wait_process_frames(2)

	assert_eq(first.frame(), second.frame())
