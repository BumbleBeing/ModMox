extends RefCounted
## PROTOTYPE (milestone 24): the Satchel prototype's own sample icons, painted in code so
## that nothing is added to ui/sprites/ for a throwaway. Each Armor Icon and Potion Icon is
## 32 × 32 pixels in the palette's colors (tools/sprites/modmox.gpl), with the palette's
## darkest neutral as its outline. The real icons are drawn by hand, as text grids.

const SIZE: int = 32
const OUTLINE: Color = Color8(20, 20, 26)
## Each ramp runs darkest, dark, mid, light, lightest.
const IRON: Array[Color] = [Color8(42, 44, 56), Color8(69, 74, 92), Color8(102, 109, 130), Color8(154, 163, 181), Color8(195, 201, 214)]
const GOLD: Array[Color] = [Color8(56, 39, 25), Color8(97, 75, 43), Color8(143, 123, 69), Color8(189, 179, 113), Color8(230, 225, 173)]
const EARTH: Array[Color] = [Color8(56, 39, 34), Color8(97, 72, 58), Color8(143, 117, 90), Color8(189, 169, 134), Color8(230, 220, 189)]
const RUST: Array[Color] = [Color8(56, 28, 25), Color8(97, 55, 43), Color8(143, 96, 69), Color8(189, 151, 113), Color8(230, 209, 173)]
const RED: Array[Color] = [Color8(56, 25, 31), Color8(97, 43, 46), Color8(143, 74, 69), Color8(189, 128, 113), Color8(230, 192, 173)]
const GREEN: Array[Color] = [Color8(30, 56, 41), Color8(52, 97, 64), Color8(82, 143, 90), Color8(126, 189, 126), Color8(189, 230, 183)]
const TEAL: Array[Color] = [Color8(30, 51, 56), Color8(52, 94, 97), Color8(82, 143, 139), Color8(126, 189, 176), Color8(183, 230, 214)]
const BLUE: Array[Color] = [Color8(28, 32, 56), Color8(48, 61, 97), Color8(77, 103, 143), Color8(121, 157, 189), Color8(179, 213, 230)]
const VIOLET: Array[Color] = [Color8(37, 33, 56), Color8(70, 56, 97), Color8(113, 88, 143), Color8(166, 132, 189), Color8(218, 187, 230)]
const GLASS: Color = Color8(195, 201, 214)
const GLASS_LIGHT: Color = Color8(228, 231, 238)
const WHITE: Color = Color8(255, 255, 255)
const STAR_GOLD: Color = Color8(238, 196, 74)
const STAR_LIGHT: Color = Color8(250, 232, 150)
const BAR_RED: Color = Color8(217, 72, 59)
const BAR_RED_DARK: Color = Color8(143, 40, 36)
const STAR: Array[String] = [
	".....0.....",
	"....0L0....",
	"....0L0....",
	"00000Y00000",
	"0LLYYYYYYY0",
	".0LYYYYYY0.",
	"..0YYYYY0..",
	"..0YYYYY0..",
	".0YYY0YYY0.",
	".0Y00.00Y0.",
	".00.....00.",
]

enum Flask { ROUND, TALL, CONE }


static func helm(ramp: Array[Color], crest: Array[Color]) -> Texture2D:
	var image: Image = _blank()
	_ellipse(image, 15.5, 13.0, 10.0, 10.0, ramp[2], 0, 13)
	_rect(image, 6, 13, 25, 25, ramp[2])
	# The forehead band, the left light and the right shade.
	_over(image, 6, 11, 25, 12, ramp[3])
	_over(image, 8, 6, 9, 23, ramp[3])
	_over(image, 10, 5, 11, 7, ramp[4])
	_over(image, 22, 6, 25, 25, ramp[1])
	_over(image, 6, 24, 25, 25, ramp[0])
	# The opening: the eyes across, then down past the mouth.
	_rect(image, 9, 14, 22, 16, OUTLINE)
	_rect(image, 14, 16, 17, 25, OUTLINE)
	_rect(image, 8, 13, 8, 13, ramp[4])
	_rect(image, 23, 13, 23, 13, ramp[3])
	# The crest along the crown.
	_rect(image, 15, 2, 16, 10, crest[2])
	_rect(image, 15, 2, 15, 10, crest[3])
	_outline(image)
	return ImageTexture.create_from_image(image)


static func greaves(ramp: Array[Color], strap: Array[Color]) -> Texture2D:
	var image: Image = _blank()
	_trapezoid(image, 7, 28, 5.0, 14.0, 7.0, 12.0, ramp[2])
	_ellipse(image, 9.5, 6.5, 5.0, 4.0, ramp[3], 0, 31)
	_rect(image, 7, 4, 9, 4, ramp[4])
	_over(image, 9, 11, 10, 27, ramp[3])
	_over(image, 12, 11, 14, 28, ramp[1])
	_over(image, 4, 15, 15, 16, strap[1])
	_over(image, 4, 22, 15, 23, strap[1])
	_over(image, 5, 27, 14, 28, ramp[0])
	# The other leg is the first one mirrored.
	for y: int in SIZE:
		for x: int in SIZE / 2:
			image.set_pixel(SIZE - 1 - x, y, image.get_pixel(x, y))
	_outline(image)
	return ImageTexture.create_from_image(image)


static func boots(ramp: Array[Color], cuff: Array[Color]) -> Texture2D:
	var behind: Image = _boot(13, 3, [ramp[0], ramp[0], ramp[1], ramp[2], ramp[3]], cuff)
	var front: Image = _boot(3, 5, ramp, cuff)
	behind.blend_rect(front, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	return ImageTexture.create_from_image(behind)


static func potion(shape: Flask, liquid: Array[Color]) -> Texture2D:
	var image: Image = _blank()
	_rect(image, 13, 2, 18, 5, EARTH[2])
	_rect(image, 13, 2, 18, 2, EARTH[3])
	_rect(image, 17, 3, 18, 5, EARTH[1])
	match shape:
		Flask.ROUND:
			_rect(image, 13, 6, 18, 12, GLASS)
			_ellipse(image, 15.5, 20.0, 9.0, 8.5, GLASS, 0, 31)
			_ellipse(image, 15.5, 20.0, 8.0, 7.5, liquid[2], 17, 31)
			_ellipse(image, 15.5, 20.0, 8.0, 7.5, liquid[4], 17, 17)
			_ellipse(image, 15.5, 20.0, 8.0, 7.5, liquid[1], 25, 31)
			_over(image, 21, 18, 23, 24, liquid[1])
			_rect(image, 9, 19, 9, 22, liquid[4])
			_rect(image, 10, 18, 10, 18, liquid[4])
			_rect(image, 17, 21, 17, 21, liquid[3])
			_rect(image, 19, 23, 19, 23, liquid[3])
			_rect(image, 9, 14, 9, 15, WHITE)
		Flask.TALL:
			_rect(image, 13, 6, 18, 9, GLASS)
			_rect(image, 11, 10, 20, 28, GLASS)
			_rect(image, 12, 9, 19, 9, GLASS)
			_rect(image, 12, 15, 19, 27, liquid[2])
			_rect(image, 12, 15, 19, 15, liquid[4])
			_rect(image, 18, 16, 19, 27, liquid[1])
			_rect(image, 12, 26, 19, 27, liquid[1])
			_rect(image, 13, 17, 13, 24, liquid[4])
			_rect(image, 16, 20, 16, 20, liquid[3])
			_rect(image, 15, 23, 15, 23, liquid[3])
			_rect(image, 12, 11, 12, 13, WHITE)
			for corner: Vector2i in [Vector2i(11, 28), Vector2i(20, 28)]:
				image.set_pixelv(corner, Color(0, 0, 0, 0))
		Flask.CONE:
			_rect(image, 13, 6, 18, 11, GLASS)
			_trapezoid(image, 11, 27, 13.0, 18.0, 4.0, 27.0, GLASS)
			_rect(image, 4, 27, 27, 28, GLASS)
			_trapezoid(image, 18, 27, 8.4, 22.6, 5.5, 25.5, liquid[2])
			_trapezoid(image, 18, 18, 8.4, 22.6, 8.4, 22.6, liquid[4])
			_trapezoid(image, 25, 27, 6.2, 24.8, 5.5, 25.5, liquid[1])
			_over(image, 20, 19, 26, 27, liquid[1])
			_rect(image, 5, 27, 26, 27, liquid[1])
			_rect(image, 9, 21, 9, 24, liquid[4])
			_rect(image, 14, 22, 14, 22, liquid[3])
			_rect(image, 17, 24, 17, 24, liquid[3])
			_rect(image, 12, 14, 12, 15, WHITE)
	_rect(image, 12, 6, 19, 7, GLASS_LIGHT)
	_outline(image)
	return ImageTexture.create_from_image(image)


## The star on a Worn Armor's entry.
static func star() -> Texture2D:
	var image: Image = Image.create(11, 11, false, Image.FORMAT_RGBA8)
	for y: int in STAR.size():
		for x: int in STAR[y].length():
			match STAR[y][x]:
				"0":
					image.set_pixel(x, y, OUTLINE)
				"Y":
					image.set_pixel(x, y, STAR_GOLD)
				"L":
					image.set_pixel(x, y, STAR_LIGHT)
	return ImageTexture.create_from_image(image)


## The red X over a Barred Armor Slot.
static func barred() -> Texture2D:
	var image: Image = _blank()
	for y: int in range(4, 28):
		for x: int in range(4, 28):
			var on_down: int = absi(x - y)
			var on_up: int = absi(x - (SIZE - 1 - y))
			if mini(on_down, on_up) <= 1:
				image.set_pixel(x, y, BAR_RED)
			elif mini(on_down, on_up) == 2:
				image.set_pixel(x, y, BAR_RED_DARK)
	_outline(image)
	return ImageTexture.create_from_image(image)


## The faint outline an empty Armor Slot shows of [param icon]: its outline in
## [param color], and a breath of it over the rest.
static func ghost(icon: Texture2D, color: Color) -> Texture2D:
	var image: Image = icon.get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a == 0.0:
				continue
			image.set_pixel(x, y, Color(color, 0.6 if pixel.is_equal_approx(OUTLINE) else 0.12))
	return ImageTexture.create_from_image(image)


static func _boot(left: int, top: int, ramp: Array[Color], cuff: Array[Color]) -> Image:
	var image: Image = _blank()
	_rect(image, left + 1, top, left + 8, top + 17, ramp[2])
	_rect(image, left + 1, top + 15, left + 13, top + 21, ramp[2])
	_ellipse(image, left + 13.0, top + 18.5, 3.5, 3.5, ramp[2], 0, 31)
	_rect(image, left, top + 22, left + 17, top + 23, ramp[0])
	_rect(image, left, top + 22, left + 3, top + 24, ramp[0])
	_rect(image, left, top, left + 9, top + 3, cuff[3])
	_rect(image, left, top + 3, left + 9, top + 3, cuff[1])
	_rect(image, left + 2, top + 5, left + 3, top + 14, ramp[3])
	_rect(image, left + 7, top + 4, left + 8, top + 14, ramp[1])
	_rect(image, left + 2, top + 15, left + 8, top + 15, ramp[1])
	_rect(image, left + 10, top + 16, left + 13, top + 16, ramp[3])
	_rect(image, left + 1, top + 21, left + 16, top + 21, ramp[1])
	_outline(image)
	return image


static func _blank() -> Image:
	return Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)


## Fills the pixels from [param left], [param top] to [param right], [param bottom], both
## ends included.
static func _rect(image: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	for y: int in range(maxi(top, 0), mini(bottom, SIZE - 1) + 1):
		for x: int in range(maxi(left, 0), mini(right, SIZE - 1) + 1):
			image.set_pixel(x, y, color)


## As _rect, but only over pixels already painted, so shading keeps to the shape.
static func _over(image: Image, left: int, top: int, right: int, bottom: int, color: Color) -> void:
	for y: int in range(maxi(top, 0), mini(bottom, SIZE - 1) + 1):
		for x: int in range(maxi(left, 0), mini(right, SIZE - 1) + 1):
			if image.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, color)


## Fills an ellipse, only in the rows from [param first_row] to [param last_row].
static func _ellipse(image: Image, center_x: float, center_y: float, radius_x: float, radius_y: float, color: Color,
		first_row: int, last_row: int) -> void:
	for y: int in range(maxi(first_row, 0), mini(last_row, SIZE - 1) + 1):
		for x: int in SIZE:
			var across: float = (x - center_x) / radius_x
			var down: float = (y - center_y) / radius_y
			if across * across + down * down <= 1.0:
				image.set_pixel(x, y, color)


## Fills rows [param top] to [param bottom], its sides running straight from
## [param top_left] and [param top_right] to [param bottom_left] and [param bottom_right].
static func _trapezoid(image: Image, top: int, bottom: int, top_left: float, top_right: float, bottom_left: float,
		bottom_right: float, color: Color) -> void:
	for y: int in range(top, bottom + 1):
		var through: float = 0.0 if bottom == top else float(y - top) / float(bottom - top)
		_rect(image, roundi(lerpf(top_left, bottom_left, through)), y, roundi(lerpf(top_right, bottom_right, through)), y, color)


## Draws the outline round what is painted: every clear pixel beside a painted one.
static func _outline(image: Image) -> void:
	var edge: Array[Vector2i] = []
	for y: int in SIZE:
		for x: int in SIZE:
			if image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var beside: Vector2i = Vector2i(x, y) + step
				if beside.x >= 0 and beside.y >= 0 and beside.x < SIZE and beside.y < SIZE and image.get_pixelv(beside).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for point: Vector2i in edge:
		image.set_pixelv(point, OUTLINE)
