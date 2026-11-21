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
##
## Run Won and Run Lost draw a Stage's Boss in a disc of its own (milestone 19, signed off
## as step 2 of prototypes/run_ends): filled with the Stage's ground color in place of the
## clay, shaded as the clay is, inside a ring of polished jewel in that hue (draw_jeweled()).

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
## A jeweled disc's ring (draw_jeweled()): its stone's least saturation and its brightness,
## where the light strikes it and where it comes through, in degrees round the disc (0 at
## the right, 90 at the bottom), how wide the sparkle and the glint are, and how much deeper
## the inner pixel lies, in the five tones.
const JEWEL_SATURATION: float = 0.7
const JEWEL_VALUE: float = 0.62
const JEWEL_LIGHT_AT: float = 225.0
const JEWEL_GLINT_AT: float = 45.0
const JEWEL_SPARKLE_DEGREES: float = 10.0
const JEWEL_GLINT_DEGREES: float = 12.0
const JEWEL_INNER_DEPTH: float = 0.7
## The disc's picture is RING_PIXELS square. Its ring's red reaches RING_OUTER of its
## pixels from the center, RING_WIDE of them wide, with one pixel of the dark edge round it
## and the clay inside; so a disc of a given radius draws it scaled by radius / RING_OUTER.
const RING_PIXELS: int = 32
const RING_OUTER: float = 13.0
const RING_WIDE: float = 2.0

static var _made: Dictionary[String, Texture2D] = {}


## Draws on [param canvas] the Boss [param portrait] in its disc of [param radius] round
## [param center], breathing as it is [param seconds] into the breath, all tinted by
## [param tint]. A [param portrait_scale] above 1 draws the Portrait that much larger than
## fits the clay, so that it may cross onto the ring.
static func draw(canvas: CanvasItem, center: Vector2, radius: float, portrait: Texture2D, seconds: float,
		tint: Color, portrait_scale: float = 1.0) -> void:
	_draw_on(canvas, pixel_disc(), center, radius, portrait, seconds, tint, portrait_scale)


## Draws as draw() does, the disc filled with [param ground] in place of the clay and ringed
## with a jewel in its hue (jeweled_disc()), untinted. A [param seconds] of 0 draws the
## Portrait at rest.
static func draw_jeweled(canvas: CanvasItem, center: Vector2, radius: float, portrait: Texture2D, seconds: float,
		ground: Color, portrait_scale: float = 1.0) -> void:
	_draw_on(canvas, jeweled_disc(ground), center, radius, portrait, seconds, Color.WHITE, portrait_scale)


static func _draw_on(canvas: CanvasItem, disc: Texture2D, center: Vector2, radius: float, portrait: Texture2D,
		seconds: float, tint: Color, portrait_scale: float) -> void:
	var scale: int = ring_scale(radius)
	var extent: Vector2 = disc.get_size() * scale
	canvas.draw_texture_rect(disc, Rect2((center - extent / 2.0).round(), extent), false, tint)
	if portrait == null:
		return
	# What shows of the clay below the ring's shadow, its stepped edge allowed for.
	var clay_radius: int = int((RING_OUTER - RING_WIDE - RING_SHADOW - 0.75) * scale)
	var drop: float = shadow_drop(clay_radius)
	var size: float = fit_scale(portrait, clay_radius - drop) * portrait_scale * breath(seconds)
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


## The disc's picture filled with [param ground] in place of the clay, shaded as the clay is
## and darkened under the ring's shadow, inside a ring of polished jewel in its hue: a stone
## of that hue at least JEWEL_SATURATION saturated and JEWEL_VALUE bright, shaded smoothly
## round the disc by how it faces the light from the top left, from the stone darkened to
## it lightened, the inner pixel a little deeper than the outer, a white sparkle where the
## light strikes and a glint on the inner edge on the far side. The dark edge stays. Made
## once for each color, on a copy of the plain disc's picture: a headless run's
## get_image() hands back the texture's own Image, so painting on it would repaint the
## Stage Map's Boss.
static func jeweled_disc(ground: Color) -> Texture2D:
	var key: String = "jewel/" + ground.to_html()
	if _made.has(key):
		return _made[key]
	var image: Image = pixel_disc().get_image().duplicate() as Image
	var middle: Vector2 = Vector2.ONE * RING_PIXELS / 2.0
	var inside: float = RING_OUTER - RING_WIDE
	var stone: Color = Color.from_hsv(ground.h, maxf(JEWEL_SATURATION, minf(1.0, ground.s * 1.6)), JEWEL_VALUE)
	var tones: Array[Color] = [stone.darkened(0.6), stone.darkened(0.32), stone, stone.lightened(0.3),
		stone.lightened(0.58)]
	for y: int in RING_PIXELS:
		for x: int in RING_PIXELS:
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			var distance: float = point.distance_to(middle)
			if distance > RING_OUTER:
				continue
			if distance > inside:
				image.set_pixel(x, y, _jewel_at(point - middle, distance > inside + 1.0, tones))
				continue
			var shade: Color = _clay_in(ground, x, y, middle.y - inside, inside * 2.0)
			if (point - Vector2(0, RING_SHADOW)).distance_to(middle) > inside:
				shade = shade.darkened(SHADOW_DARKEN)
			image.set_pixel(x, y, shade)
	_made[key] = ImageTexture.create_from_image(image)
	return _made[key]


## The jewel ring's color [param offset] from the disc's middle, from [param tones]
## (darkest to lightest); [param is_outer] for the ring's outer pixels.
static func _jewel_at(offset: Vector2, is_outer: bool, tones: Array[Color]) -> Color:
	var turn: float = fposmod(atan2(offset.y, offset.x), TAU)
	var light: float = deg_to_rad(JEWEL_LIGHT_AT)
	var through: float = (cos(turn - light) + 1.0) / 2.0 * 4.0 - (0.0 if is_outer else JEWEL_INNER_DEPTH)
	var low: int = clampi(floori(through), 0, 3)
	var color: Color = tones[low].lerp(tones[low + 1], clampf(through - low, 0.0, 1.0))
	var from_light: float = absf(angle_difference(turn, light))
	if is_outer and from_light < deg_to_rad(JEWEL_SPARKLE_DEGREES):
		return color.lerp(Color.WHITE, 1.0 - from_light / deg_to_rad(JEWEL_SPARKLE_DEGREES) * 0.6)
	var from_glint: float = absf(angle_difference(turn, deg_to_rad(JEWEL_GLINT_AT)))
	if not is_outer and from_glint < deg_to_rad(JEWEL_GLINT_DEGREES):
		return color.lerp(tones[4], 1.0 - from_glint / deg_to_rad(JEWEL_GLINT_DEGREES))
	return color


## The clay's color at the picture's pixel [param x], [param y], in a disc whose top row
## is [param first] and which is [param across] pixels tall: Dither Shading's bands, but a
## pixel at a time, as its blocks would be too coarse on so small a picture.
static func _clay_at(x: int, y: int, first: float, across: float) -> Color:
	return _clay_in(CLAY, x, y, first, across)


## As _clay_at(), the clay [param clay] in place of CLAY.
static func _clay_in(clay: Color, x: int, y: int, first: float, across: float) -> Color:
	var through: float = clampf((y + 0.5 - first) / across, 0.0, 1.0)
	var threshold: float = DitherShading.BAYER[(y % 2) * 2 + x % 2]
	var band: int = clampi(floori(through * (DitherShading.BANDS - 1) + threshold), 0, DitherShading.BANDS - 1)
	return clay.lightened(CLAY_LIGHTEN).lerp(clay.darkened(CLAY_DARKEN), float(band) / (DitherShading.BANDS - 1))
