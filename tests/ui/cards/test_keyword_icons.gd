extends GutTest
## A Keyword Chip shows its keyword's Keyword Icon: a 16 × 16 pixel picture in white and one
## gray, drawn unsmoothed. A chip with no icon, and the "+N" chip, show letters instead.

const ALPHA: String = "res://content/cards/alpha/%s.tres"
const KEYWORDS: Array[String] = [
	"flying", "reach", "vigilance", "haste", "deathtouch", "defender", "first_strike",
	"double_strike", "trample", "indestructible", "protection",
]
const WHITE: Color = Color(1, 1, 1, 1)
const GRAY: Color = Color("#9aa3b5")


func test_every_keyword_has_an_icon() -> void:
	var abilities: Array[MmAbility] = [
		FlyingAbility.new(), ReachAbility.new(), VigilanceAbility.new(), HasteAbility.new(),
		DeathtouchAbility.new(), DefenderAbility.new(), FirstStrikeAbility.new(),
		DoubleStrikeAbility.new(), TrampleAbility.new(), IndestructibleAbility.new(),
		ProtectionAbility.new(),
	]

	var chips: Array[KeywordChip] = KeywordChips.chips_for(abilities)

	var icons: Array[String] = []
	for chip: KeywordChip in chips:
		icons.append(chip.icon)
		assert_not_null(KeywordChips.icon_texture(chip), "%s has an icon file." % chip.icon)
	assert_eq(icons, KEYWORDS)


func test_every_icon_is_16_pixels_square_in_white_one_gray_and_clear_without_mipmaps() -> void:
	for keyword: String in KEYWORDS:
		var chip: KeywordChip = KeywordChip.new()
		chip.icon = keyword

		var image: Image = KeywordChips.icon_texture(chip).get_image()

		assert_eq(image.get_size(), Vector2i(16, 16), keyword)
		assert_false(image.has_mipmaps(), "%s has no mipmaps." % keyword)
		var strays: int = 0
		for y: int in 16:
			for x: int in 16:
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a != 0.0 and not pixel.is_equal_approx(WHITE) and not pixel.is_equal_approx(GRAY):
					strays += 1
		assert_eq(strays, 0, "%s uses only white, the gray and clear." % keyword)


func test_a_chip_with_an_icon_draws_it_unsmoothed_and_no_letters() -> void:
	var chip: KeywordChip = KeywordChips.chips_for([FlyingAbility.new()] as Array[MmAbility])[0]

	var panel: Panel = autofree(CardShapes.chip(chip, Vector2.ZERO, 32.0)) as Panel

	var icon: TextureRect = _icon_of(panel)
	assert_not_null(icon)
	assert_eq(icon.texture, KeywordChips.icon_texture(chip))
	assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(icon.size, Vector2(32, 32))
	assert_null(_letters_of(panel))


func test_a_chip_without_an_icon_draws_its_letters() -> void:
	var chip: KeywordChip = KeywordChip.new()
	chip.letters = "X"
	chip.icon = "no_such_keyword"

	var panel: Panel = autofree(CardShapes.chip(chip, Vector2.ZERO, 32.0)) as Panel

	assert_null(_icon_of(panel))
	assert_not_null(_letters_of(panel))


func test_the_plus_n_chip_draws_letters() -> void:
	var chips: Array[KeywordChip] = KeywordChips.chips_for(
			[FlyingAbility.new(), VigilanceAbility.new(), HasteAbility.new()] as Array[MmAbility])

	var more: KeywordChip = KeywordChips.shown(chips, 2)[1]
	var panel: Panel = autofree(CardShapes.chip(more, Vector2.ZERO, 32.0)) as Panel

	assert_eq(more.letters, "+2")
	assert_null(_icon_of(panel))
	assert_not_null(_letters_of(panel))


func test_a_protection_chip_draws_the_shield_and_keeps_its_colored_dot() -> void:
	var knight: MmCardDefinition = load(ALPHA % "white_knight") as MmCardDefinition
	var chip: KeywordChip = KeywordChips.chips_for(CardLook.of_definition(knight).abilities)[1]

	var panel: Panel = autofree(CardShapes.chip(chip, Vector2.ZERO, 32.0)) as Panel

	assert_eq(chip.icon, "protection")
	assert_not_null(_icon_of(panel))
	var dot: Panel = panel.get_child(panel.get_child_count() - 1) as Panel
	assert_not_null(dot, "The dot is drawn last, over the icon.")
	var style: StyleBoxFlat = dot.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(style.bg_color, CardShapes.color_of(MmCardTypes.CardColor.BLACK))


func _icon_of(panel: Panel) -> TextureRect:
	for child: Node in panel.get_children():
		if child is TextureRect:
			return child as TextureRect
	return null


func _letters_of(panel: Panel) -> AnchoredText:
	for child: Node in panel.get_children():
		if child is AnchoredText:
			return child as AnchoredText
	return null
