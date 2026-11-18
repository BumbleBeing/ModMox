class_name PortraitSheet
extends RefCounted
## The review sheet of a Portrait drawn after a Magic character (game glossary): its
## reference art (ReferenceArt) as tall as a Portrait at 6×, then its pictures (the
## Portrait, the Pain Portrait and the Blink Portrait, or the first two while it has no
## Blink Portrait yet) side by side at 6×, the size a player's panel draws them, then each
## at 2× and 1×. Each is on the panel's ground, so it is seen as the panel shows it.

const SCALES: Array[int] = [1, 2, 6]
const SIZE: int = 32
const PAD: int = 16
## The art is scaled to the height of a Portrait at 6×.
const ART_HEIGHT: int = SIZE * 6
## Behind everything else on the sheet.
const BACK: Color = Color8(20, 20, 26)


## The sheet of reference art [param art] and [param pictures] (each 32 × 32, in order),
## with [param ground] behind each picture.
static func compose(art: Image, pictures: Array[Image], ground: Color) -> Image:
	var art_size: Vector2i = art.get_size()
	var size: Vector2i = sheet_size(art_size, pictures.size())
	var sheet: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(BACK)
	var art_rect: Rect2i = art_rect(art_size)
	var scaled_art: Image = art.duplicate() as Image
	scaled_art.convert(Image.FORMAT_RGBA8)
	scaled_art.resize(art_rect.size.x, art_rect.size.y, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(scaled_art, Rect2i(Vector2i.ZERO, art_rect.size), art_rect.position)
	for scale: int in SCALES:
		for index: int in pictures.size():
			_draw_picture(sheet, pictures[index], portrait_rect(art_size, pictures.size(), scale, index), ground)
	return sheet


## Where the art of [param art_size] is drawn.
static func art_rect(art_size: Vector2i) -> Rect2i:
	var width: int = roundi(float(art_size.x) * ART_HEIGHT / art_size.y)
	return Rect2i(PAD, PAD, width, ART_HEIGHT)


## Where picture [param index] of [param count] is drawn at [param scale].
static func portrait_rect(art_size: Vector2i, count: int, scale: int, index: int) -> Rect2i:
	var large: int = SIZE * 6
	var left: int = art_rect(art_size).end.x + PAD
	if scale == 6:
		return Rect2i(left + index * (large + PAD), PAD, large, large)
	var small: int = SIZE * 2
	var column: int = left + count * (large + PAD) + index * (small + PAD)
	var top: int = PAD if scale == 2 else PAD + small + PAD
	return Rect2i(column, top, SIZE * scale, SIZE * scale)


## The size of the sheet for art of [param art_size] and [param count] pictures.
static func sheet_size(art_size: Vector2i, count: int) -> Vector2i:
	var right: int = portrait_rect(art_size, count, 2, count - 1).end.x + PAD
	return Vector2i(right, PAD + ART_HEIGHT + PAD)


static func _draw_picture(sheet: Image, picture: Image, rect: Rect2i, ground: Color) -> void:
	sheet.fill_rect(rect, ground)
	var scaled: Image = picture.duplicate() as Image
	scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(scaled, Rect2i(Vector2i.ZERO, rect.size), rect.position)
