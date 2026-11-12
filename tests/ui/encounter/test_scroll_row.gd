extends GutTest
## A ScrollRow's arrows can take the color of a Glow hidden past their end of the line.

const GREEN: Color = Color("#7be36a")


func test_arrows_are_plain_until_tinted_and_plain_again_when_cleared() -> void:
	var row: ScrollRow = ScrollRow.new(Rect2(0, 0, 400, 200), 900.0, 0.0)
	add_child_autofree(row)
	var plain: Color = (row.right_arrow().get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	assert_null(row.arrow_tint(row.left_arrow()))
	assert_null(row.arrow_tint(row.right_arrow()))

	row.tint_arrows(null, GREEN)

	assert_null(row.arrow_tint(row.left_arrow()))
	assert_eq(row.arrow_tint(row.right_arrow()), GREEN)
	var tinted: Color = (row.right_arrow().get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	assert_eq(Color(tinted, 1.0), GREEN, "The arrow itself is drawn in the Glow's color.")
	assert_eq((row.left_arrow().get_theme_stylebox("normal") as StyleBoxFlat).bg_color, plain)
	assert_gt((row.right_arrow().get_theme_stylebox("hover") as StyleBoxFlat).bg_color.a, tinted.a, "It still brightens on hover.")

	row.tint_arrows(GREEN, null)

	assert_eq(row.arrow_tint(row.left_arrow()), GREEN)
	assert_null(row.arrow_tint(row.right_arrow()))
	assert_eq((row.right_arrow().get_theme_stylebox("normal") as StyleBoxFlat).bg_color, plain)


func test_each_arrow_has_a_drawn_triangle_pointing_its_way_and_no_text() -> void:
	var row: ScrollRow = ScrollRow.new(Rect2(0, 0, 900, 200), 1400.0, 100.0)
	add_child_autofree(row)
	var size: Vector2 = row.left_arrow().size
	var left: PackedVector2Array = (row.left_arrow().get_child(0) as Polygon2D).polygon
	var right: PackedVector2Array = (row.right_arrow().get_child(0) as Polygon2D).polygon

	assert_eq(row.left_arrow().text, "", "A character from a fallback font is slow to lay out on every redraw.")
	assert_eq(row.right_arrow().text, "")
	assert_eq(left, ScrollRow.arrowhead(size, -1.0))
	assert_eq(right, ScrollRow.arrowhead(size, 1.0))
	assert_eq(left[0], size / 2.0 + Vector2(-ScrollRow.ARROWHEAD.x / 2.0, 0), "The left arrow's point is at its left")
	assert_eq(right[0], size / 2.0 + Vector2(ScrollRow.ARROWHEAD.x / 2.0, 0), "and the right arrow's at its right.")
	assert_eq(left[1], size / 2.0 + Vector2(ScrollRow.ARROWHEAD.x / 2.0, -ScrollRow.ARROWHEAD.y / 2.0))
	assert_eq(left[2], size / 2.0 + Vector2(ScrollRow.ARROWHEAD.x / 2.0, ScrollRow.ARROWHEAD.y / 2.0))
	assert_eq(right[1], size / 2.0 + Vector2(-ScrollRow.ARROWHEAD.x / 2.0, -ScrollRow.ARROWHEAD.y / 2.0))
	assert_eq(right[2], size / 2.0 + Vector2(-ScrollRow.ARROWHEAD.x / 2.0, ScrollRow.ARROWHEAD.y / 2.0))


func test_an_arrow_already_painted_a_color_is_not_painted_again() -> void:
	var row: ScrollRow = ScrollRow.new(Rect2(0, 0, 900, 200), 1400.0, 100.0)
	add_child_autofree(row)
	var plain: StyleBox = row.left_arrow().get_theme_stylebox("normal")

	row.tint_arrows(null, null)
	assert_eq(row.left_arrow().get_theme_stylebox("normal"), plain, "The same style, not a new one like it.")
	row.tint_arrows(Color.RED, null)
	var red: StyleBox = row.left_arrow().get_theme_stylebox("normal")
	assert_ne(red, plain)
	assert_eq(row.arrow_tint(row.left_arrow()), Color.RED)
	row.tint_arrows(Color.RED, null)
	assert_eq(row.left_arrow().get_theme_stylebox("normal"), red)
	row.tint_arrows(null, null)
	assert_ne(row.left_arrow().get_theme_stylebox("normal"), red, "Back to plain is a change.")
	assert_null(row.arrow_tint(row.left_arrow()))
