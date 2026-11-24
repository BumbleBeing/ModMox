class_name WispLight
extends RefCounted
## The Wisp Light: when the Wisp comes near the main menu's window's top or either side, the
## Soldier Shadow turned to light lies just inside that edge, in the Wisp's color at half
## strength. It is the window's own Dither Shading blocks, four deep as the shadow is, two
## solid and two dithered away; it is centered where the Wisp is level with the edge, longer
## the nearer the Wisp is, and its ends are dithered away too. It never lies on the window's
## stepped corners, and never on its bottom edge.

const STRENGTH: float = 0.5
## How near the Wisp's nearest side must come to an edge to light it, and how long the light
## is when it is right at the edge: three Wisps.
const REACH: float = 96.0
const LONGEST: float = WispFlight.SIZE * 3
## How much of each row of blocks is lit, from the edge in: the Soldier Shadow's.
const COVERAGE: Array[float] = SoldierShadow.COVERAGE
## How much of the light's length, at each end, is dithered away.
const ENDS: float = 1.0 / 3.0

enum Edge { TOP, LEFT, RIGHT }


## The light's blocks on the screen for the Wisp at [param wisp] near [param window], whose
## stepped corner and rim together reach [param corner] pixels in: its dither grid
## starts that far in from its left and right, and at its top.
static func blocks(wisp: Rect2, window: Rect2, corner: int) -> Array[Rect2]:
	var made: Array[Rect2] = []
	var middle: Vector2 = wisp.get_center()
	if middle.y < window.position.y:
		made.append_array(_along(Edge.TOP, window.position.y - wisp.end.y, middle.x, window, corner))
	if middle.x < window.position.x:
		made.append_array(_along(Edge.LEFT, window.position.x - wisp.end.x, middle.y, window, corner))
	if middle.x > window.end.x:
		made.append_array(_along(Edge.RIGHT, wisp.position.x - window.end.x, middle.y, window, corner))
	return made


## The color the light is drawn in for a Wisp of [param wisp_color], showing as strongly as
## [param opacity].
static func color_of(wisp_color: Color, opacity: float) -> Color:
	return Color(wisp_color, STRENGTH * opacity)


## The blocks along [param edge] for the Wisp [param gap] from it, its middle at
## [param level] along it.
static func _along(edge: Edge, gap: float, level: float, window: Rect2, corner: int) -> Array[Rect2]:
	var made: Array[Rect2] = []
	var length: float = LONGEST * (1.0 - maxf(gap, 0.0) / REACH)
	if length <= 0.0:
		return made
	var block: int = DitherShading.BLOCK
	var half: float = length / 2
	# The blocks along the edge, past the stepped corners: across the top, from the window's
	# dither grid, which starts past its left corner; down a side, from its top.
	var first: int
	var last: int
	var start: float
	if edge == Edge.TOP:
		start = window.position.x + corner
		first = 0
		last = floori((window.end.x - corner - start) / block) - 1
	else:
		start = window.position.y
		first = ceili(float(corner) / block)
		last = floori((window.size.y - corner) / block) - 1
	for along: int in range(first, last + 1):
		var from_middle: float = absf(start + (along + 0.5) * block - level)
		if from_middle > half:
			continue
		var share: float = 0.5 if from_middle > half * (1.0 - ENDS) else 1.0
		for depth: int in COVERAGE.size():
			var spot: Vector2i = _spot(edge, along, depth, window, corner)
			if DitherShading.BAYER[posmod(spot.y, 2) * 2 + posmod(spot.x, 2)] < COVERAGE[depth] * share:
				made.append(Rect2(_corner_of(edge, along, depth, window, corner), Vector2.ONE * block))
	return made


## The block [param along] the edge and [param depth] in from it, on the window's grid:
## across and down, for its place in the dither's pattern.
static func _spot(edge: Edge, along: int, depth: int, window: Rect2, corner: int) -> Vector2i:
	match edge:
		Edge.TOP:
			return Vector2i(along, depth)
		Edge.LEFT:
			return Vector2i(_first_inside(corner) + depth, along)
		_:
			return Vector2i(_last_inside(corner) - depth, along)


## Where that block's top left corner is on the screen. A side's blocks lie on the grid its
## own corner starts: past the left corner for the left side, short of the right corner for
## the right, so that each is flush with the inside of its edge.
static func _corner_of(edge: Edge, along: int, depth: int, window: Rect2, corner: int) -> Vector2:
	var block: int = DitherShading.BLOCK
	match edge:
		Edge.TOP:
			return Vector2(window.position.x + corner + along * block, window.position.y + depth * block)
		Edge.LEFT:
			return Vector2(window.position.x + corner + (_first_inside(corner) + depth) * block, window.position.y + along * block)
		_:
			return Vector2(window.end.x - corner + (_last_inside(corner) - depth) * block, window.position.y + along * block)


## The first block of the left corner's grid that lies wholly inside the window.
static func _first_inside(corner: int) -> int:
	return -floori(float(corner) / DitherShading.BLOCK)


## The last block of the right corner's grid that lies wholly inside the window.
static func _last_inside(corner: int) -> int:
	return floori(float(corner) / DitherShading.BLOCK) - 1
