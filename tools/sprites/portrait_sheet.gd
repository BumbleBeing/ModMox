class_name PortraitSheet
extends RefCounted
## The review sheet of a Portrait drawn after a Magic character (game glossary): its
## reference art (ReferenceArt) as tall as a Portrait at 6×, then the Portrait and the Pain
## Portrait at 6×, the size a player's panel draws them, then each at 2× and 1×. Each is on
## the panel's ground, so it is seen as the panel shows it.

const SCALES: Array[int] = [1, 2, 6]
const SIZE: int = 32
const PAD: int = 16
## The art is scaled to the height of a Portrait at 6×.
const ART_HEIGHT: int = SIZE * 6
## Behind everything else on the sheet.
const BACK: Color = Color8(20, 20, 26)


## The sheet of reference art [param art], [param portrait] and [param pain] (both 32 × 32),
## with [param ground] behind each Portrait.
static func compose(art: Image, portrait: Image, pain: Image, ground: Color) -> Image:
	var art_size: Vector2i = art.get_size()
	var sheet: Image = Image.create(sheet_size(art_size).x, sheet_size(art_size).y, false, Image.FORMAT_RGBA8)
	sheet.fill(BACK)
	var art_rect: Rect2i = art_rect(art_size)
	var scaled_art: Image = art.duplicate() as Image
	scaled_art.convert(Image.FORMAT_RGBA8)
	scaled_art.resize(art_rect.size.x, art_rect.size.y, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(scaled_art, Rect2i(Vector2i.ZERO, art_rect.size), art_rect.position)
	for scale: int in SCALES:
		_draw_portrait(sheet, portrait, portrait_rect(art_size, scale, false), ground)
		_draw_portrait(sheet, pain, portrait_rect(art_size, scale, true), ground)
	return sheet


## Where the art of [param art_size] is drawn.
static func art_rect(art_size: Vector2i) -> Rect2i:
	var width: int = roundi(float(art_size.x) * ART_HEIGHT / art_size.y)
	return Rect2i(PAD, PAD, width, ART_HEIGHT)


## Where the Portrait, or the Pain Portrait if [param pain], is drawn at [param scale].
static func portrait_rect(art_size: Vector2i, scale: int, pain: bool) -> Rect2i:
	var large: int = SIZE * 6
	var left: int = art_rect(art_size).end.x + PAD
	if scale == 6:
		return Rect2i(left + (large + PAD if pain else 0), PAD, large, large)
	var small_left: int = left + 2 * (large + PAD)
	var column: int = small_left + (SIZE * 2 + PAD if pain else 0)
	var top: int = PAD if scale == 2 else PAD + SIZE * 2 + PAD
	return Rect2i(column, top, SIZE * scale, SIZE * scale)


## The size of the sheet for art of [param art_size].
static func sheet_size(art_size: Vector2i) -> Vector2i:
	var right: int = portrait_rect(art_size, 2, true).end.x + PAD
	return Vector2i(right, PAD + ART_HEIGHT + PAD)


static func _draw_portrait(sheet: Image, picture: Image, rect: Rect2i, ground: Color) -> void:
	sheet.fill_rect(rect, ground)
	var scaled: Image = picture.duplicate() as Image
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(scaled, Rect2i(Vector2i.ZERO, rect.size), rect.position)
