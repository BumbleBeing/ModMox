class_name SatchelLook
extends RefCounted
## How the Satchel window looks (milestone 24, signed off as prototypes/satchel/): a
## leather-brown window in Dither Shading with a stitched line inside its edge, "Satchel" on a
## flap-shaped bar across its top, the Worn column and the page set into it in a darker
## leather, three tabs sharing the page's whole top, and each entry on parchment in dark ink,
## as the Spoils' gold panel is. Its sizes and colors, and the pictures it paints for itself,
## worked out here apart from the window's nodes. Each picture is painted once, pixel by
## pixel, and kept: the window, its flap and its tabs never change, and a parchment is kept
## for each height an entry is drawn at.

## The game is always drawn at this size (ADR 0035).
const SCREEN: Vector2 = Vector2(1920, 1080)
const DIM: Color = Color(0, 0, 0, 0.6)
const WINDOW_SIZE: Vector2 = Vector2(1200, 800)
const WINDOW_RADIUS: int = 24
## The window's leather, its near-black edge, and the darker leather of what is set into it:
## the Worn column and the page.
const LEATHER: Color = Color("#6b4a30")
const EDGE: Color = Color("#1c120b")
const SET_IN: Color = Color("#3f2a1b")
const SLOT_GROUND: Color = Color("#2c1d12")
const STITCH: Color = Color("#d9b98a")
const CREAM: Color = Color("#f0e6d2")
const CREAM_MUTED: Color = Color("#c9b89a")
const SET_IN_RADIUS: int = 14
## The flap across the top: as tall as FLAP_SIDE at its ends and FLAP_DROP more in the middle.
const FLAP: Color = Color("#7d5636")
const FLAP_SIDE: float = 58.0
const FLAP_DROP: float = 22.0
const FLAP_HEIGHT: int = 84
## The stitches: a dash of STITCH_DASH pixels in every STITCH_STEP, STITCH_INSET inside the edge.
const STITCH_DASH: float = 9.0
const STITCH_STEP: float = 16.0
const STITCH_INSET: float = 10.0
## The Spoils screen's parchment, for each entry.
const PAPER: Color = Color("#e9dcbc")
const PAPER_EDGE: Color = Color("#7a6243")
const PAPER_LIGHTEN: float = 0.08
const PAPER_DARKEN: float = 0.15
const PAPER_RADIUS: int = 14
const PAPER_EDGE_WIDTH: int = 2
const PAPER_PADDING: Vector2 = Vector2(16, 12)
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
## A 32 × 32 icon is drawn at three times its size, in an entry and in an Armor Slot, on a
## square one art pixel wider each way, as a Potion Icon's plate is.
const ICON_SCALE: int = 3
const ICON_SIDE: int = 32 * ICON_SCALE
const TILE_SIDE: int = ICON_SIDE + ICON_SCALE * 2
const PORTRAIT_SCALE: int = 5
const STAR_SCALE: int = 3
const WORN_RECT: Rect2 = Rect2(24, 104, 248, 672)
const WORN_GAP: int = 14
## The tabs share the page's whole top. The open one stands TAB_HEIGHT above the page, is the
## page's own color, and widens by TAB_FLARE at each foot where it runs into the page; the
## others are TAB_LOW shorter.
const TAB_HEIGHT: int = 48
const TAB_LOW: int = 6
const TAB_FLARE: int = 10
const TAB_RADIUS: int = 12
const PAGE_RECT: Rect2 = Rect2(296, 156, 880, 544)
const PAGE_PADDING: float = 12.0
const ENTRY_GAP: int = 12
## Room kept at the list's right for the scroll bar, whether or not it shows, so that every
## entry is one width.
const SCROLL_ROOM: int = 24
const SCROLL_WIDTH: int = 14
## An entry's width, and the room between its picture and its words: every entry is as wide
## as the list, so its words are given their width before it is laid out, and wrap there
## from the start (a parchment is painted for its height, and painting one for each height
## words pass through as they wrap narrower stalled the game for seconds).
const ENTRY_WIDTH: float = PAGE_RECT.size.x - PAGE_PADDING * 2.0 - SCROLL_ROOM
const ENTRY_SEPARATION: int = 16
const CLOSE_RECT: Rect2 = Rect2(1016, 716, 160, 60)
const CLOSE_FILL: Color = Color("#8a6238")
## How an entry that takes a click lightens under the cursor, and how one shown from its
## Armor Slot is lit for a moment.
const HOVER: Color = Color(1.12, 1.12, 1.12)
const LIGHT: Color = Color(1.3, 1.25, 1.05)
## At Blazing, scaled by the Game Speed: the glide to an entry shown from its Armor Slot, and
## how long it stays lit.
const GLIDE_SECONDS: float = 0.2
const LIGHT_SECONDS: float = 0.6
const STAR: String = "res://ui/sprites/satchel/worn_star.png"
## The faint outline an empty Armor Slot shows, by the slot's name in lower case: the template
## its Armor Icons are drawn in (tools/sprites/armor_templates/).
const SLOT_OUTLINES: String = "res://ui/sprites/armor_slots/%s.png"


## How many pictures have been painted, and each one kept: the flap, the window's plate,
## each tab face by its shape, and each parchment by its height.
static var _painted: int = 0
static var _flap: Texture2D = null
static var _window: StyleBoxTexture = null
static var _tabs: Dictionary[String, Texture2D] = {}
static var _papers: Dictionary[int, StyleBoxTexture] = {}
static var _stitches: PackedVector2Array = PackedVector2Array()


## How many pictures the Satchel has painted for itself since forget_painted().
static func painted_count() -> int:
	return _painted


## Every height a parchment has been painted for since forget_painted().
static func painted_paper_heights() -> Array[int]:
	return _papers.keys()


## Forgets what has been painted, for a test to start from nothing.
static func forget_painted() -> void:
	_painted = 0
	_flap = null
	_window = null
	_tabs.clear()
	_papers.clear()
	_stitches = PackedVector2Array()


## Paints, ahead of time, every picture the window draws whatever it holds: its plate, its flap,
## its stitches, each tab's face, open and not, and Close's Steel Frame, which SteelFrame keeps. The screen the Satchel opens over calls it
## as it begins, behind the Scene Fade's black, as CardWarmup is called, so that opening the
## Satchel paints only its entries' parchment. Once a game, since what is painted is kept.
static func warm() -> void:
	window_style()
	flap_texture()
	stitches()
	var spans: Array[Vector2i] = tab_spans(SatchelEntries.PAGES.size(), PAGE_RECT.size.x - 2.0)
	for index: int in spans.size():
		for is_open: bool in [true, false]:
			tab_texture(spans[index].y, TAB_HEIGHT if is_open else TAB_HEIGHT - TAB_LOW, is_open, index > 0,
				index < spans.size() - 1)
	for state: String in ButtonShading.STATES:
		SteelFrame.roomy_plate(CLOSE_FILL, state, int(CLOSE_RECT.size.y))


## How wide an entry's words are: the entry's width less its padding and its picture.
static func words_width() -> float:
	return ENTRY_WIDTH - PAPER_PADDING.x * 2.0 - TILE_SIDE - ENTRY_SEPARATION


## Where the window stands: in the middle of the screen.
static func window_position() -> Vector2:
	return ((SCREEN - WINDOW_SIZE) / 2.0).floor()


## The outline an empty [param slot] shows.
static func slot_outline(slot: Armor.Slot) -> Texture2D:
	return load(SLOT_OUTLINES % Armor.slot_name(slot).to_lower()) as Texture2D


## Where each of [param count] tabs stands across [param across] pixels: its left and its
## width. Each shares its 2-pixel edge with the next.
static func tab_spans(count: int, across: float) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	for index: int in count:
		var left: int = roundi(index * across / count)
		spans.append(Vector2i(left, roundi((index + 1) * across / count) + 2 - left))
	return spans


## The flap: leather in Dither Shading, straight at its ends and bellying down in the middle,
## with a dark lower edge and a line of stitches just inside it.
static func flap_texture() -> Texture2D:
	if _flap != null:
		return _flap
	_painted += 1
	var width: int = int(WINDOW_SIZE.x) - 4
	var corner: int = WINDOW_RADIUS - 2
	var image: Image = Image.create(width, FLAP_HEIGHT, false, Image.FORMAT_RGBA8)
	var top: Color = FLAP.lightened(0.12)
	var bottom: Color = FLAP.darkened(0.22)
	for x: int in width:
		var across: float = (x - width / 2.0) / (width / 2.0)
		var foot: float = FLAP_SIDE + FLAP_DROP * (1.0 - across * across)
		var from_side: int = mini(x, width - 1 - x)
		for y: int in FLAP_HEIGHT:
			if y > foot:
				continue
			# The window's own top corners.
			if from_side < corner and y < corner and Vector2(corner - from_side, corner - y).length() > corner:
				continue
			var color: Color = DitherShading.band_color(x, y, FLAP_HEIGHT, top, bottom)
			if y > foot - 2.0:
				color = EDGE
			elif absf(y - (foot - STITCH_INSET)) <= 1.0 and fmod(x, STITCH_STEP) < STITCH_DASH and from_side > 12:
				color = STITCH
			image.set_pixel(x, y, color)
	_flap = ImageTexture.create_from_image(image)
	return _flap


## A tab's face, TAB_FLARE wider than the tab at each side. The open one is the page's own
## flat color with no edge along its foot, and widens there in a curve on each side that
## [param flares_left] and [param flares_right] allow (an end tab runs straight down into the
## page's side). Another tab is darker leather in Dither Shading, edged all round.
static func tab_texture(width: int, height: int, is_open: bool, flares_left: bool, flares_right: bool) -> Texture2D:
	var key: String = "%d/%d/%s/%s/%s" % [width, height, is_open, flares_left, flares_right]
	if _tabs.has(key):
		return _tabs[key]
	_painted += 1
	var image: Image = Image.create(width + TAB_FLARE * 2, height + 2, false, Image.FORMAT_RGBA8)
	var top: Color = LEATHER.darkened(0.1)
	var bottom: Color = LEATHER.darkened(0.42)
	# The tab's shape, worked out once for each pixel and for a border of two round the image,
	# so that whether a pixel is on its edge is read from its neighbors' places in it.
	var border: int = 2
	var across: int = image.get_width() + border * 2
	var inside: PackedByteArray = PackedByteArray()
	inside.resize(across * (image.get_height() + border * 2))
	for y: int in range(-border, image.get_height() + border):
		for x: int in range(-border, image.get_width() + border):
			if is_in_tab(x, y, width, height, is_open, flares_left, flares_right):
				inside[(y + border) * across + x + border] = 1
	# A pixel is on the edge when one two away across or down, or one diagonally next to it, is
	# outside the tab.
	var near: PackedInt32Array = PackedInt32Array([-2, 2, -2 * across, 2 * across, -across - 1, -across + 1,
			across - 1, across + 1])
	for y: int in image.get_height():
		for x: int in image.get_width():
			var at: int = (y + border) * across + x + border
			if inside[at] == 0:
				continue
			var color: Color = SET_IN if is_open else DitherShading.band_color(x, y, height, top, bottom)
			for step: int in near:
				if inside[at + step] == 0:
					color = EDGE
					break
			image.set_pixel(x, y, color)
	_tabs[key] = ImageTexture.create_from_image(image)
	return _tabs[key]


## Whether the pixel at [param x], [param y] of a tab's face is part of the tab.
static func is_in_tab(x: int, y: int, width: int, height: int, is_open: bool, flares_left: bool,
		flares_right: bool) -> bool:
	var left: int = TAB_FLARE
	var right: int = TAB_FLARE + width
	if y < 0:
		return false
	if y >= height:
		# Below its foot the open tab is the page, as wide as its feet.
		return is_open and x >= (0 if flares_left else left) and x < (right + TAB_FLARE if flares_right else right)
	if x >= left and x < right:
		if y < TAB_RADIUS and x < left + TAB_RADIUS:
			return Vector2(x + 0.5 - (left + TAB_RADIUS), y + 0.5 - TAB_RADIUS).length() <= TAB_RADIUS
		if y < TAB_RADIUS and x >= right - TAB_RADIUS:
			return Vector2(x + 0.5 - (right - TAB_RADIUS), y + 0.5 - TAB_RADIUS).length() <= TAB_RADIUS
		return true
	if not is_open or y < height - TAB_FLARE:
		return false
	# A foot: what is left of a square when a circle is cut from its outer top corner.
	if x < left:
		return flares_left and x >= 0 and Vector2(x + 0.5, y + 0.5 - (height - TAB_FLARE)).length() >= TAB_FLARE
	return flares_right and x < right + TAB_FLARE \
			and Vector2(x + 0.5 - (right + TAB_FLARE), y + 0.5 - (height - TAB_FLARE)).length() >= TAB_FLARE


## Where each stitch down the window's sides and along its foot is drawn, a little inside its
## edge: the top left of a 2 × 2 square.
static func stitches() -> PackedVector2Array:
	if not _stitches.is_empty():
		return _stitches
	var corner: float = WINDOW_RADIUS - STITCH_INSET
	var left: float = STITCH_INSET
	var right: float = WINDOW_SIZE.x - STITCH_INSET
	var foot: float = WINDOW_SIZE.y - STITCH_INSET
	var path: PackedVector2Array = PackedVector2Array([Vector2(left, FLAP_SIDE + 12.0), Vector2(left, foot - corner)])
	for step: int in range(1, 9):
		var angle: float = PI - step * (PI / 2.0) / 8.0
		path.append(Vector2(left + corner + cos(angle) * corner, foot - corner + sin(angle) * corner))
	path.append(Vector2(right - corner, foot))
	for step: int in range(1, 9):
		var angle: float = PI / 2.0 - step * (PI / 2.0) / 8.0
		path.append(Vector2(right - corner + cos(angle) * corner, foot - corner + sin(angle) * corner))
	path.append(Vector2(right, FLAP_SIDE + 12.0))
	var dots: PackedVector2Array = PackedVector2Array()
	var walked: float = 0.0
	for index: int in path.size() - 1:
		var length: float = path[index].distance_to(path[index + 1])
		var along: float = 0.0
		while along < length:
			if fmod(walked + along, STITCH_STEP) < STITCH_DASH:
				dots.append(path[index].lerp(path[index + 1], along / length).floor() - Vector2(1, 1))
			along += 1.0
		walked += length
	_stitches = dots
	return dots


## The window's own plate: its leather in Dither Shading inside its dark edge.
static func window_style() -> StyleBoxTexture:
	if _window == null:
		_painted += 1
		_window = DitherShading.plate(LEATHER.lightened(0.06), LEATHER.darkened(0.3), EDGE, WINDOW_RADIUS, 2, 0,
				int(WINDOW_SIZE.y))
	return _window


## A parchment panel [param height] pixels tall, shaded with Dither Shading over its height,
## or as short as its corners allow.
static func paper_style(height: int) -> StyleBoxTexture:
	height = maxi(height, PAPER_RADIUS * 2 + 1)
	if _papers.has(height):
		return _papers[height]
	_painted += 1
	var made: StyleBoxTexture = DitherShading.plate(PAPER.lightened(PAPER_LIGHTEN), PAPER.darkened(PAPER_DARKEN),
			PAPER_EDGE, PAPER_RADIUS - PAPER_EDGE_WIDTH, PAPER_EDGE_WIDTH, 0, height)
	made.content_margin_left = PAPER_PADDING.x
	made.content_margin_right = PAPER_PADDING.x
	made.content_margin_top = PAPER_PADDING.y
	made.content_margin_bottom = PAPER_PADDING.y
	_papers[height] = made
	return made


## The flat, dark-edged ground of something set into the leather.
static func set_in_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = flat(fill, radius)
	style.set_border_width_all(2)
	style.border_color = EDGE
	return style


static func flat(fill: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style


## The soft shadow the window casts on the dimmed screen.
static func shadow_style() -> StyleBoxFlat:
	var cast: StyleBoxFlat = flat(Color(0, 0, 0, 0), WINDOW_RADIUS)
	cast.shadow_color = Color(0, 0, 0, 0.55)
	cast.shadow_size = 24
	cast.shadow_offset = Vector2(0, 10)
	return cast
