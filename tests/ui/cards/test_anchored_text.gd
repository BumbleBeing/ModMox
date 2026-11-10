extends GutTest
## Text on a card is pinned to its box: it shrinks to fit (or is cut short with an
## ellipsis) and sits on a baseline worked out from the box and the font size alone, so it
## never drifts out of its box however the card is sized.

const LONG_NAME: String = "Merfolk of the Pearl Trident and Friends"


func test_a_title_stays_inside_its_box_at_every_card_size() -> void:
	for height: float in [150.0, 300.0, 700.0]:
		var box: Rect2 = CardGeometry.on_card(CardGeometry.TITLE, Vector2(height * CardGeometry.ASPECT, height))

		var text: AnchoredText = _text(box, LONG_NAME, AnchoredText.Fit.SHRINK)

		assert_lte(text.text_width(), box.size.x, "Fits the width at %d." % height)
		assert_lte(text.font_size, floori(box.size.y * 0.78), "Never taller than allowed at %d." % height)
		assert_between(text.baseline(), box.size.y * 0.5, box.size.y, "The baseline is in the box at %d." % height)


func test_the_baseline_scales_with_the_box() -> void:
	var small: AnchoredText = _text(Rect2(0, 0, 400, 20), "Bear", AnchoredText.Fit.SHRINK)
	var large: AnchoredText = _text(Rect2(0, 0, 800, 40), "Bear", AnchoredText.Fit.SHRINK)

	assert_almost_eq(large.baseline() / large.size.y, small.baseline() / small.size.y, 0.05)


func test_long_text_shrinks_to_fit_but_short_text_keeps_its_size() -> void:
	var box: Rect2 = Rect2(0, 0, 120, 20)

	var short: AnchoredText = _text(box, "Bear", AnchoredText.Fit.SHRINK)
	var long: AnchoredText = _text(box, LONG_NAME, AnchoredText.Fit.SHRINK)

	assert_eq(short.font_size, floori(20 * 0.78))
	assert_lt(long.font_size, short.font_size)


func test_a_name_too_long_for_its_box_is_cut_short_with_an_ellipsis() -> void:
	var box: Rect2 = Rect2(0, 0, 120, 20)

	var text: AnchoredText = _text(box, LONG_NAME, AnchoredText.Fit.ELLIPSIS)

	assert_true(text.shown_text().ends_with("…"))
	assert_lte(text.text_width(), box.size.x)
	assert_eq(text.font_size, floori(20 * 0.78), "Cut short, never shrunk.")


func test_a_name_that_fits_is_not_cut() -> void:
	var text: AnchoredText = _text(Rect2(0, 0, 400, 20), "Bear", AnchoredText.Fit.ELLIPSIS)

	assert_eq(text.shown_text(), "Bear")


func test_a_size_bonus_adds_to_the_font_size() -> void:
	var text: AnchoredText = AnchoredText.new()
	add_child_autofree(text)

	text.setup(Rect2(0, 0, 400, 20), ["Illus. Mark Poole"] as Array[String], [Color.WHITE] as Array[Color],
			CardFonts.body(), 0.78, HORIZONTAL_ALIGNMENT_LEFT, AnchoredText.Fit.ELLIPSIS, 2)

	assert_eq(text.font_size, floori(20 * 0.78) + 2)


func _text(box: Rect2, words: String, fit: AnchoredText.Fit) -> AnchoredText:
	var text: AnchoredText = AnchoredText.new()
	add_child_autofree(text)
	text.setup(box, [words] as Array[String], [Color.BLACK] as Array[Color], CardFonts.title(), 0.78,
			HORIZONTAL_ALIGNMENT_LEFT, fit)
	return text
