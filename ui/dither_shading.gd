class_name DitherShading
extends RefCounted
## Dither Shading, the GUI's recurring look for a raised surface (see the conventions): a
## rough, pixelated gradient from a lighter tone at the top to a darker one at the bottom,
## in bands of square blocks dithered where they meet with a 2 × 2 Bayer pattern. A plate
## is painted for the surface's own height, so its blocks are never stretched; its middle
## columns tile, which keeps the dither even across any width. Whatever draws one sets
## TEXTURE_FILTER_NEAREST.

## The blocks are this many pixels square, in this many bands.
const BLOCK: int = 3
const BANDS: int = 5
const BAYER: Array[float] = [0.0, 0.5, 0.75, 0.25]


## A plate [param height] pixels tall shaded from [param top] down to [param bottom],
## rounded by [param radius], edged in [param edge] [param edge_width] pixels wide, with a
## lip of the edge's color [param lip] pixels deep along its bottom.
static func plate(top: Color, bottom: Color, edge: Color, radius: int, edge_width: int, lip: int, height: int) -> StyleBoxTexture:
	var corner: int = radius + maxi(edge_width, lip)
	var width: int = corner * 2 + BLOCK * 4
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			image.set_pixel(x, y, _pixel(x, y, width, height, corner, top, bottom, edge, radius, edge_width, lip))
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = corner
	made.texture_margin_right = corner
	made.texture_margin_top = corner
	made.texture_margin_bottom = corner
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return made


## A button's plate: [param fill] lightened at the top and darkened at the bottom, a dark
## edge and a lip that a pressed button sits down on.
static func button_plate(fill: Color, is_pressed: bool, height: int) -> StyleBoxTexture:
	var top: Color = fill.darkened(0.2) if is_pressed else fill.lightened(0.12)
	var bottom: Color = fill.lightened(0.02) if is_pressed else fill.darkened(0.25)
	var made: StyleBoxTexture = plate(top, bottom, fill.darkened(0.55), 6, 1, 1 if is_pressed else 4, height)
	made.content_margin_left = 10
	made.content_margin_right = 10
	made.content_margin_top = 10 if is_pressed else 7
	made.content_margin_bottom = 7
	return made


## The tone a pixel of the shaded face takes: one of the bands from [param top] to
## [param bottom], chosen block by block.
static func band_color(x: int, y: int, height: int, top: Color, bottom: Color) -> Color:
	var block_y: int = y / BLOCK
	var block_rows: int = maxi(1, ceili(float(height) / BLOCK))
	var through: float = float(block_y) / float(maxi(1, block_rows - 1))
	var threshold: float = BAYER[(block_y % 2) * 2 + posmod(x / BLOCK, 2)]
	var band: int = clampi(floori(through * (BANDS - 1) + threshold), 0, BANDS - 1)
	return top.lerp(bottom, float(band) / float(BANDS - 1))


static func _pixel(x: int, y: int, width: int, height: int, corner: int, top: Color, bottom: Color,
		edge: Color, radius: int, edge_width: int, lip: int) -> Color:
	var inside: float = _inside_distance(x, y, width, height, radius)
	if inside < 0.0:
		return Color(0, 0, 0, 0)
	if inside < edge_width or y >= height - lip:
		return edge
	return band_color(x - corner, y, height, top, bottom)


## How far the pixel at [param x], [param y] is inside a rounded rectangle, negative outside.
static func _inside_distance(x: int, y: int, width: int, height: int, radius: int) -> float:
	var point: Vector2 = Vector2(x + 0.5, y + 0.5)
	var in_corner: bool = (point.x < radius or point.x > width - radius) and (point.y < radius or point.y > height - radius)
	if in_corner:
		var nearest: Vector2 = Vector2(clampf(point.x, radius, width - radius), clampf(point.y, radius, height - radius))
		return radius - point.distance_to(nearest)
	return minf(minf(point.x, width - point.x), minf(point.y, height - point.y))
