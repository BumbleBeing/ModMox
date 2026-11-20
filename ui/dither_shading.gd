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
## How deep a button's lip is, raised and pressed.
const LIP: int = 4
const PRESSED_LIP: int = 1
## How much darker than its fill a clickable button's lip is: dark enough to show against
## the pane under it, so the button stands up off it.
const LIP_DARKEN: float = 0.75


## A plate [param height] pixels tall shaded from [param top] down to [param bottom],
## rounded by [param radius], edged in [param edge] [param edge_width] pixels wide, with a
## lip of the edge's color [param lip] pixels deep along its bottom.
## [param lip_color], when given, colors the lip in place of the edge's color.
static func plate(top: Color, bottom: Color, edge: Color, radius: int, edge_width: int, lip: int, height: int,
		lip_color: Variant = null) -> StyleBoxTexture:
	var corner: int = radius + maxi(edge_width, lip)
	var width: int = corner * 2 + BLOCK * 4
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			image.set_pixel(x, y, _pixel(x, y, width, height, corner, top, bottom, edge, radius, edge_width, lip,
				edge if lip_color == null else lip_color as Color))
	var made: StyleBoxTexture = StyleBoxTexture.new()
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = corner
	made.texture_margin_right = corner
	made.texture_margin_top = corner
	made.texture_margin_bottom = corner
	made.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return made


## A clickable button's plate: [param fill] lightened at the top and darkened at the
## bottom, a dark edge and a darker lip that a pressed button sits down on. Its text is
## centered on the face, above the lip: the bottom margin is deeper than the top by the
## lip's depth. Its corners are rounded by [param radius].
static func button_plate(fill: Color, is_pressed: bool, height: int, radius: int = 6) -> StyleBoxTexture:
	var top: Color = fill.darkened(0.2) if is_pressed else fill.lightened(0.12)
	var bottom: Color = fill.lightened(0.02) if is_pressed else fill.darkened(0.25)
	var lip: int = PRESSED_LIP if is_pressed else LIP
	var made: StyleBoxTexture = plate(top, bottom, fill.darkened(0.55), radius, 1, lip, height, fill.darkened(LIP_DARKEN))
	made.content_margin_left = 10
	made.content_margin_right = 10
	made.content_margin_top = 7
	made.content_margin_bottom = 7 + lip
	return made


## A button that cannot be clicked: shaded as a clickable one is but with no lip, so it
## lies flat on the pane, its text centered. Its corners are rounded by [param radius].
static func disabled_plate(fill: Color, height: int, radius: int = 6) -> StyleBoxTexture:
	var made: StyleBoxTexture = plate(fill.lightened(0.12), fill.darkened(0.25), fill.darkened(0.55), radius, 1, 0, height)
	made.content_margin_left = 10
	made.content_margin_right = 10
	made.content_margin_top = 7
	made.content_margin_bottom = 7
	return made


## A ring [param width] pixels thick in [param color] round the very shape [param plate] is
## painted in, lip and all, with nothing inside it: every pixel of the plate within
## [param width] of its outside. It is stretched as the plate is, so laid over a button
## drawn with that plate it follows its corners exactly.
static func ring_round(plate: StyleBoxTexture, width: int, color: Color) -> StyleBoxTexture:
	var shape: Image = plate.texture.get_image()
	var size: Vector2i = shape.get_size()
	var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			if shape.get_pixel(x, y).a > 0.0 and _is_near_outside(shape, x, y, width):
				image.set_pixel(x, y, color)
	var made: StyleBoxTexture = plate.duplicate() as StyleBoxTexture
	made.texture = ImageTexture.create_from_image(image)
	return made


## A white halo outside the very shape [param plate] is painted in, lip and all, and nothing
## over the plate itself: solid out to [param near] pixels from it, and [param soft] as
## strong from there out to [param far]. It is [param far] pixels bigger than the plate on
## every side and stretched as the plate is, so a panel that much bigger than a button drawn
## with that plate hugs its corners. Whatever draws it colors it.
static func halo_round(plate: StyleBoxTexture, near: int, far: int, soft: float) -> StyleBoxTexture:
	var shape: Image = plate.texture.get_image()
	var size: Vector2i = shape.get_size()
	# The shape has no hollows, so each column of it is one run of pixels.
	var tops: PackedInt32Array = PackedInt32Array()
	var bottoms: PackedInt32Array = PackedInt32Array()
	for x: int in size.x:
		var top: int = -1
		var bottom: int = -1
		for y: int in size.y:
			if shape.get_pixel(x, y).a > 0.0:
				if top < 0:
					top = y
				bottom = y
		tops.append(top)
		bottoms.append(bottom)
	var image: Image = Image.create_empty(size.x + far * 2, size.y + far * 2, false, Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var away: float = _distance_outside(tops, bottoms, x - far, y - far, far)
			if away > 0.0 and away <= far:
				image.set_pixel(x, y, Color(1, 1, 1, 1.0 if away <= near else soft))
	var made: StyleBoxTexture = plate.duplicate() as StyleBoxTexture
	made.texture = ImageTexture.create_from_image(image)
	made.texture_margin_left = plate.texture_margin_left + far
	made.texture_margin_right = plate.texture_margin_right + far
	made.texture_margin_top = plate.texture_margin_top + far
	made.texture_margin_bottom = plate.texture_margin_bottom + far
	return made


## How far the pixel at [param x], [param y] is from a shape whose columns run from
## [param tops] to [param bottoms]: 0 inside it, and more than [param reach] when it is
## further than that.
static func _distance_outside(tops: PackedInt32Array, bottoms: PackedInt32Array, x: int, y: int, reach: int) -> float:
	var nearest: float = reach + 1.0
	for column: int in range(maxi(0, x - reach), mini(tops.size(), x + reach + 1)):
		if tops[column] < 0:
			continue
		var down: int = 0
		if y < tops[column]:
			down = tops[column] - y
		elif y > bottoms[column]:
			down = y - bottoms[column]
		nearest = minf(nearest, Vector2(column - x, down).length())
	return nearest


## Whether a pixel outside [param shape], or past its edge, is within [param reach] of
## [param x], [param y].
static func _is_near_outside(shape: Image, x: int, y: int, reach: int) -> bool:
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			if dx * dx + dy * dy > reach * reach:
				continue
			var at: Vector2i = Vector2i(x + dx, y + dy)
			if at.x < 0 or at.y < 0 or at.x >= shape.get_width() or at.y >= shape.get_height() or shape.get_pixelv(at).a == 0.0:
				return true
	return false


## The tone a pixel of the shaded face takes: one of the bands from [param top] to
## [param bottom], chosen block by block.
static func band_color(x: int, y: int, height: int, top: Color, bottom: Color) -> Color:
	var block_y: int = y / BLOCK
	var block_rows: int = maxi(1, ceili(float(height) / BLOCK))
	var through: float = float(block_y) / float(maxi(1, block_rows - 1))
	var threshold: float = BAYER[(block_y % 2) * 2 + posmod(x / BLOCK, 2)]
	var band: int = clampi(floori(through * (BANDS - 1) + threshold), 0, BANDS - 1)
	return top.lerp(bottom, float(band) / float(BANDS - 1))


## The face is a rounded rectangle above the lip, and the lip is the same rectangle moved
## down by its depth, so the face's bottom corners curve as its top ones do with the lip
## showing beneath them.
static func _pixel(x: int, y: int, width: int, height: int, corner: int, top: Color, bottom: Color,
		edge: Color, radius: int, edge_width: int, lip: int, lip_color: Color) -> Color:
	var face_height: int = height - lip
	var inside: float = _inside_distance(x, y, width, face_height, radius)
	if inside < 0.0:
		var is_lip: bool = lip > 0 and _inside_distance(x, y - lip, width, face_height, radius) >= 0.0
		return lip_color if is_lip else Color(0, 0, 0, 0)
	if inside < edge_width:
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
