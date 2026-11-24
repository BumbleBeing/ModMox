class_name SoldierShadow
extends RefCounted
## The Soldier Shadow: where the bottom of the Menu Soldier's sprite is black, his soles or his
## spear's butt touch the main menu's window, and the window is shaded there, half black, in
## its own Dither Shading blocks: solid under him, then dithered away. A lifted foot casts none:
## its shadow fades out rapidly, and back in as the foot comes down. On the frame he flashes,
## the shadow takes the flash's color, and fades back to black as rapidly after.

const COLOR: Color = Color(0, 0, 0, 0.5)
## How much of each row of blocks is shaded, from the window's top down: dithered with the
## same 2 × 2 Bayer pattern as the window's face.
const COVERAGE: Array[float] = [1.0, 1.0, 0.5, 0.5]
## The sprite's row his soles are drawn on; the row below it is empty.
const SOLES_ROW: int = MenuSoldier.SPRITE_SIZE - 2
## The brightest a pixel may be and still be black, the palette's outline tone.
const BLACK: float = 0.15
## Seconds the shadow takes to fade fully in or out, and its color to fade back to black.
const FADE: float = 0.08

## How strong the shadow is under each column of his sprite, from 0 (none) to 1.
var _strengths: Array[float] = []
## The color of the last flash, and how much of it the shadow still has.
var _flash: Color = Color.BLACK
var _tint: float = 0.0


## A shadow already lying fully under [param contacts], in black.
func _init(contacts: Array[int]) -> void:
	_strengths.resize(MenuSoldier.SPRITE_SIZE)
	_strengths.fill(0.0)
	for column: int in contacts:
		_strengths[column] = 1.0


## The columns of [param image], a frame of his, where the row that lands on the ground is
## black: the soles row, or, for a frame drawn [param raised] pixels above his box, the row
## that many below it. The sprite's bottom row is empty, so a frame raised without its art
## lowered touches the ground nowhere.
static func contacts_of(image: Image, raised: int = 0) -> Array[int]:
	var contacts: Array[int] = []
	var row: int = SOLES_ROW + raised
	if row >= image.get_height():
		return contacts
	for x: int in image.get_width():
		var pixel: Color = image.get_pixel(x, row)
		if pixel.a > 0.5 and maxf(pixel.r, maxf(pixel.g, pixel.b)) < BLACK:
			contacts.append(x)
	return contacts


## Lets [param seconds] go by with him showing [param frame] and touching the ground at
## [param contacts]. Whether the shadow looks any different for it.
func advance(seconds: float, contacts: Array[int], frame: String) -> bool:
	var was: Array[float] = _strengths.duplicate()
	var was_hue: Color = _hue()
	var step: float = seconds / FADE
	for column: int in _strengths.size():
		_strengths[column] = move_toward(_strengths[column], 1.0 if contacts.has(column) else 0.0, step)
	if SoldierAnimations.FLASH_COLORS.has(frame):
		_flash = SoldierAnimations.FLASH_COLORS[frame]
		_tint = 1.0
	else:
		_tint = move_toward(_tint, 0.0, step)
	return _strengths != was or _hue() != was_hue


## The columns of his sprite with any shadow under them.
func columns() -> Array[int]:
	var shaded: Array[int] = []
	for column: int in _strengths.size():
		if _strengths[column] > 0.0:
			shaded.append(column)
	return shaded


## The color the shadow is drawn in under [param column] of his sprite.
func color_of(column: int) -> Color:
	return Color(_hue(), COLOR.a * _strengths[column])


## The shadow's blocks under [param contacts], for a sprite drawn [param scale] times its
## size with its left edge at [param left]: on the window's dither grid, which starts at
## [param grid_left] across and at [param top], the window's top, down.
static func blocks(contacts: Array[int], left: float, scale: int, grid_left: float, top: float) -> Array[Rect2]:
	var made: Array[Rect2] = []
	var block: int = DitherShading.BLOCK
	var first: int = floori((left - grid_left) / block)
	var last: int = ceili((left + MenuSoldier.SPRITE_SIZE * scale - grid_left) / block)
	for column: int in range(first, last):
		var x: float = grid_left + column * block
		if not contacts.has(floori((x + block / 2.0 - left) / scale)):
			continue
		for row: int in COVERAGE.size():
			if DitherShading.BAYER[(row % 2) * 2 + posmod(column, 2)] < COVERAGE[row]:
				made.append(Rect2(x, top + row * block, block, block))
	return made


## Black, or as much of the last flash's color as is left.
func _hue() -> Color:
	return Color.BLACK.lerp(_flash, _tint)
