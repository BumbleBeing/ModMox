class_name SicknessSpiral
extends TextureRect
## The Sickness Spiral (game glossary): the spiral that turns over the middle of the art of
## a summoning sick creature's Battlefield Face, once every LOOP_SECONDS.
##
## It is pixel art, 30 frames side by side in one sheet, drawn at a whole multiple of its
## size with hard edges, half see-through. Every spiral shows the frame of the same clock, the time since the
## game started, so one made by a redraw is where the one it replaces had got to, and all
## of them turn together. It keeps the same time at every Game Speed, as a Portrait's
## Breath does: it says what the creature is, and is no part of the game's pace.
##
## The sheet is exported from the file beside it whenever that is touched up:
##   aseprite -b ui/sprites/encounter/summoning_sickness.aseprite \
##       --sheet ui/sprites/encounter/summoning_sickness.png --sheet-type horizontal

const SHEET: String = "res://ui/sprites/encounter/summoning_sickness.png"
## A frame's width and height in the sheet.
const FRAME_PIXELS: int = 32
const FRAMES: int = 30
const LOOP_SECONDS: float = 3.0
## The spiral is at most this much of the art's shorter side.
const MOST_OF_ART: float = 0.9
## How solid the spiral is, so the art shows through it.
const ALPHA: float = 0.5

var _frame: int = -1


## Every frame of the spiral, side by side.
static func sheet() -> Texture2D:
	return load(SHEET) as Texture2D


## The frame shown [param seconds] into the game.
static func frame_at(seconds: float) -> int:
	return floori(fposmod(seconds, LOOP_SECONDS) / LOOP_SECONDS * FRAMES + 0.0001) % FRAMES


## Where [param frame_index] is in the sheet.
static func region_of(frame_index: int) -> Rect2:
	return Rect2(frame_index * FRAME_PIXELS, 0, FRAME_PIXELS, FRAME_PIXELS)


## How wide and tall the spiral is over art of [param art_size]: the largest whole multiple
## of its own size that is at most MOST_OF_ART of the art's shorter side, and never smaller
## than it was drawn.
static func side_in(art_size: Vector2) -> float:
	var most: float = minf(art_size.x, art_size.y) * MOST_OF_ART
	return maxf(1.0, floorf(most / FRAME_PIXELS + 0.0001)) * FRAME_PIXELS


## A spiral in the middle of [param art], a Battlefield Face's art box.
static func make(art: Rect2) -> SicknessSpiral:
	var spiral: SicknessSpiral = SicknessSpiral.new()
	var side: float = side_in(art.size)
	var frame_texture: AtlasTexture = AtlasTexture.new()
	frame_texture.atlas = sheet()
	spiral.texture = frame_texture
	spiral.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spiral.stretch_mode = TextureRect.STRETCH_SCALE
	spiral.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spiral.position = (art.get_center() - Vector2(side, side) / 2.0).round()
	spiral.size = Vector2(side, side)
	spiral.pivot_offset = spiral.size / 2.0
	spiral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spiral.modulate.a = ALPHA
	spiral.show_at(_now())
	return spiral


## The frame it shows.
func frame() -> int:
	return _frame


## Shows the frame of [param seconds] into the game.
func show_at(seconds: float) -> void:
	var now: int = frame_at(seconds)
	if now == _frame:
		return
	_frame = now
	(texture as AtlasTexture).region = region_of(now)


func _process(_delta: float) -> void:
	show_at(_now())


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
