class_name BossDisc
extends RefCounted
## How a Boss is drawn on its Node and in the Stage Intro (milestone 17, signed off as
## prototypes/stage_map_screen): a clay disc with Dither Shading inside a red ring shaded
## smoothly from top to bottom, the Boss's Portrait breathing in it. The light falls from
## above, so the ring and the Portrait each cast a short shadow down onto the clay. The
## Portrait is sized so that neither it nor its shadow ever leaves the disc.
##
## The Portrait is drawn at a scale that fits the disc, not a whole multiple of its size,
## and grows and shrinks as it breathes: the one place pixel art is drawn so (the
## conventions' "Game-side code").

const CLAY: Color = Color8(220, 168, 140)
const RING: Color = Color8(217, 72, 59)
const EDGE: Color = Color8(20, 20, 26)
## The clay is Dither Shaded from this much lighter at the top to this much darker at the
## bottom; the ring is shaded smoothly, not dithered.
const CLAY_LIGHTEN: float = 0.06
const CLAY_DARKEN: float = 0.25
const RING_LIGHTEN: float = 0.15
const RING_DARKEN: float = 0.35
## Shadows fall this far for each pixel of the clay's radius, and are this dark.
const SHADOW_DROP: float = 0.05
const SHADOW_DARKEN: float = 0.25
## The Boss breathes, growing and shrinking from its center by this much, once in this long.
const BREATH_SCALE: float = 0.04
const BREATH_SECONDS: float = 3.0
## The dark edge reaches beyond the ring by this share of its radius, but never less than
## the least: 2 pixels on the Node, 3 in the Stage Intro.
const EDGE_SHARE: float = 0.03
const LEAST_EDGE: float = 2.0

static var _made: Dictionary[String, Texture2D] = {}


## Draws on [param canvas] the Boss [param portrait] in its disc of [param radius] round
## [param center], with a ring [param ring_width] wide, breathing as it is
## [param seconds] into the breath, all tinted by [param tint].
static func draw(canvas: CanvasItem, center: Vector2, radius: float, ring_width: float, portrait: Texture2D,
		seconds: float, tint: Color) -> void:
	canvas.draw_circle(center, radius + maxf(LEAST_EDGE, roundf(radius * EDGE_SHARE)), EDGE * tint)
	var ring: Texture2D = shaded_ring(int(radius))
	canvas.draw_texture(ring, center - ring.get_size() / 2.0, tint)
	var clay_radius: int = int(radius - ring_width)
	var clay: Texture2D = dithered_clay(clay_radius)
	canvas.draw_texture(clay, center - clay.get_size() / 2.0, tint)
	if portrait == null:
		return
	var drop: float = shadow_drop(clay_radius)
	var size: float = fit_scale(portrait, clay_radius - drop) * breath(seconds)
	var extent: Vector2 = portrait.get_size()
	canvas.draw_set_transform(center + Vector2(0.0, drop), 0.0, Vector2.ONE * size)
	canvas.draw_texture_rect(portrait, Rect2(-extent / 2.0, extent), false, Color(0, 0, 0, SHADOW_DARKEN * tint.a))
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * size)
	canvas.draw_texture_rect(portrait, Rect2(-extent / 2.0, extent), false, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


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


## The clay disc of [param radius]: Dither Shaded, with the ring's shadow across its top,
## every pixel the ring would cover were the clay moved down by the shadow's drop. Made
## once for each size.
static func dithered_clay(radius: int) -> Texture2D:
	var key: String = "clay:%d" % radius
	if _made.has(key):
		return _made[key]
	var across: int = radius * 2
	var image: Image = Image.create_empty(across, across, false, Image.FORMAT_RGBA8)
	var middle: Vector2 = Vector2(radius, radius)
	var drop: Vector2 = Vector2(0.0, shadow_drop(radius))
	for y: int in across:
		for x: int in across:
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			if point.distance_to(middle) > radius:
				continue
			var color: Color = DitherShading.band_color(x, y, across, CLAY.lightened(CLAY_LIGHTEN), CLAY.darkened(CLAY_DARKEN))
			if (point - drop).distance_to(middle) > radius:
				color = color.darkened(SHADOW_DARKEN)
			image.set_pixel(x, y, color)
	_made[key] = ImageTexture.create_from_image(image)
	return _made[key]


## The red disc of [param radius], shaded smoothly from top to bottom: what shows of it
## round the clay is the ring. Made once for each size.
static func shaded_ring(radius: int) -> Texture2D:
	var key: String = "ring:%d" % radius
	if _made.has(key):
		return _made[key]
	var across: int = radius * 2
	var image: Image = Image.create_empty(across, across, false, Image.FORMAT_RGBA8)
	var middle: Vector2 = Vector2(radius, radius)
	var top: Color = RING.lightened(RING_LIGHTEN)
	var bottom: Color = RING.darkened(RING_DARKEN)
	for y: int in across:
		for x: int in across:
			if Vector2(x + 0.5, y + 0.5).distance_to(middle) <= radius:
				image.set_pixel(x, y, top.lerp(bottom, (y + 0.5) / across))
	_made[key] = ImageTexture.create_from_image(image)
	return _made[key]
