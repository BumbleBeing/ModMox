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
