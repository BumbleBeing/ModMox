class_name BossDisc
extends RefCounted
## How a Boss is drawn on its Node and in the Stage Intro (milestone 17, signed off as
## prototypes/stage_map_screen): a clay disc with Dither Shading inside a red ring, the
## Boss's Portrait breathing in it. The disc is pixel art, one 32 x 32 picture scaled by a
## whole number to its size: the ring edged dark and shaded from top to bottom a row at a
## time, the clay dithered a pixel at a time. The light falls from above, so the ring casts
## a pixel of shadow down onto the clay, and the Portrait a short shadow of its own. The
## Portrait is sized so that neither it nor its shadow ever leaves the clay.
##
## The Portrait is drawn at a scale that fits the disc, not a whole multiple of its size,
## and grows and shrinks as it breathes: the one place pixel art is drawn so (the
## conventions' "Game-side code").

const CLAY: Color = Color8(220, 168, 140)
const RING: Color = Color8(217, 72, 59)
const EDGE: Color = Color8(20, 20, 26)
## The clay is Dither Shaded from this much lighter at the top to this much darker at the
## bottom, a pixel at a time; the ring is shaded a row at a time, not dithered.
const CLAY_LIGHTEN: float = 0.06
const CLAY_DARKEN: float = 0.25
const RING_LIGHTEN: float = 0.15
const RING_DARKEN: float = 0.35
## The Portrait's shadow falls this far for each pixel of the clay's radius, the ring's
## shadow RING_SHADOW of the picture's pixels; both are this dark.
const SHADOW_DROP: float = 0.05
const RING_SHADOW: int = 1
const SHADOW_DARKEN: float = 0.25
## The Boss breathes, growing and shrinking from its center by this much, once in this long.
const BREATH_SCALE: float = 0.04
const BREATH_SECONDS: float = 3.0
## The disc's picture is RING_PIXELS square. Its ring's red reaches RING_OUTER of its
## pixels from the center, RING_WIDE of them wide, with one pixel of the dark edge round it
## and the clay inside; so a disc of a given radius draws it scaled by radius / RING_OUTER.
const RING_PIXELS: int = 32
const RING_OUTER: float = 13.0
const RING_WIDE: float = 2.0

static var _made: Dictionary[String, Texture2D] = {}


## Draws on [param canvas] the Boss [param portrait] in its disc of [param radius] round
## [param center], breathing as it is [param seconds] into the breath, all tinted by
## [param tint].
static func draw(canvas: CanvasItem, center: Vector2, radius: float, portrait: Texture2D, seconds: float,
		tint: Color) -> void:
	var scale: int = ring_scale(radius)
	var disc: Texture2D = pixel_disc()
	var extent: Vector2 = disc.get_size() * scale
	canvas.draw_texture_rect(disc, Rect2((center - extent / 2.0).round(), extent), false, tint)
	if portrait == null:
		return
	# What shows of the clay below the ring's shadow, its stepped edge allowed for.
	var clay_radius: int = int((RING_OUTER - RING_WIDE - RING_SHADOW - 0.75) * scale)
	var drop: float = shadow_drop(clay_radius)
	var size: float = fit_scale(portrait, clay_radius - drop) * breath(seconds)
	extent = portrait.get_size()
	canvas.draw_set_transform(center + Vector2(0.0, drop), 0.0, Vector2.ONE * size)
	canvas.draw_texture_rect(portrait, Rect2(-extent / 2.0, extent), false, Color(0, 0, 0, SHADOW_DARKEN * tint.a))
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * size)
	canvas.draw_texture_rect(portrait, Rect2(-extent / 2.0, extent), false, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## How many screen pixels square each of the ring's pixels is on a disc of [param radius].
static func ring_scale(radius: float) -> int:
	return maxi(1, roundi(radius / RING_OUTER))


## How large the breathing Boss is [param seconds] into its breath: 1 at rest.
static func breath(seconds: float) -> float:
	return 1.0 + BREATH_SCALE * sin(TAU * seconds / BREATH_SECONDS)


## How far down the shadows fall on clay of [param radius].
static func shadow_drop(radius: int) -> float:
	return roundf(radius * SHADOW_DROP)


## The largest scale at which [param portrait], centered in a circle of [param radius] and
## at the top of its breath, keeps every pixel it draws inside the circle.
static func fit_scale(portrait: Texture2D, radius: float) -> float:
	var image: Image = portrait.get_image()
	var center: Vector2 = Vector2(image.get_size()) / 2.0
	var farthest: float = 0.0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < 0.1:
				continue
			for corner: Vector2 in [Vector2(x, y), Vector2(x + 1, y), Vector2(x, y + 1), Vector2(x + 1, y + 1)]:
				farthest = maxf(farthest, corner.distance_to(center))
	if farthest == 0.0:
		return 1.0
	return radius / (farthest * (1.0 + BREATH_SCALE))


## The disc's picture: RING_WIDE pixels of red, shaded from light at the top to dark at
## the bottom a row at a time and edged by a pixel of EDGE, round the clay, Dither Shaded a
## pixel at a time and darkened under the ring's shadow, every pixel the ring would cover
## were the clay moved down RING_SHADOW pixels. Made once.
static func pixel_disc() -> Texture2D:
	if _made.has("disc"):
		return _made["disc"]
	var image: Image = Image.create_empty(RING_PIXELS, RING_PIXELS, false, Image.FORMAT_RGBA8)
	var middle: Vector2 = Vector2.ONE * RING_PIXELS / 2.0
	var inside: float = RING_OUTER - RING_WIDE
	var top: Color = RING.lightened(RING_LIGHTEN)
	var bottom: Color = RING.darkened(RING_DARKEN)
	var first: float = middle.y - RING_OUTER
	for y: int in RING_PIXELS:
		var shade: Color = top.lerp(bottom, clampf((y + 0.5 - first) / (RING_OUTER * 2.0), 0.0, 1.0))
		for x: int in RING_PIXELS:
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			var distance: float = point.distance_to(middle)
			if distance <= inside:
				var clay: Color = _clay_at(x, y, middle.y - inside, inside * 2.0)
				if (point - Vector2(0, RING_SHADOW)).distance_to(middle) > inside:
					clay = clay.darkened(SHADOW_DARKEN)
				image.set_pixel(x, y, clay)
			elif distance <= RING_OUTER:
				image.set_pixel(x, y, shade)
			elif distance <= RING_OUTER + 1.0:
				image.set_pixel(x, y, EDGE)
	_made["disc"] = ImageTexture.create_from_image(image)
	return _made["disc"]


## The clay's color at the picture's pixel [param x], [param y], in a disc whose top row
## is [param first] and which is [param across] pixels tall: Dither Shading's bands, but a
## pixel at a time, as its blocks would be too coarse on so small a picture.
static func _clay_at(x: int, y: int, first: float, across: float) -> Color:
	var through: float = clampf((y + 0.5 - first) / across, 0.0, 1.0)
	var threshold: float = DitherShading.BAYER[(y % 2) * 2 + x % 2]
	var band: int = clampi(floori(through * (DitherShading.BANDS - 1) + threshold), 0, DitherShading.BANDS - 1)
	return CLAY.lightened(CLAY_LIGHTEN).lerp(CLAY.darkened(CLAY_DARKEN), float(band) / (DitherShading.BANDS - 1))
