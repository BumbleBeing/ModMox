class_name MenuLogo
extends TextureRect
## The Logo at the head of the main menu's window: the word ModMox in blocky pixels, its two
## o's the Mod Icon's cog, Rare's turning clockwise and Mythic's against it, a quarter turn
## every loop. Draws the frame the loop is on, at a whole multiple of its size.
## tools/sprites/logo.py draws the frames, one under another, in SHEET, which is as wide as
## the word.

const SHEET: Texture2D = preload("res://ui/sprites/menu/logo.png")
## One frame's height, in pixels: a character's.
const FRAME_HEIGHT: int = 32
const FRAMES: int = 24
const FRAMES_PER_SECOND: int = 8
## How long the loop takes: FRAMES at FRAMES_PER_SECOND.
const LOOP_SECONDS: float = float(FRAMES) / FRAMES_PER_SECOND
const SCALE: int = 2

var _frames: Array[AtlasTexture] = []
var _seconds: float = 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	var frame_size: Vector2 = Vector2(SHEET.get_width(), FRAME_HEIGHT)
	custom_minimum_size = frame_size * SCALE
	for index: int in FRAMES:
		var cut: AtlasTexture = AtlasTexture.new()
		cut.atlas = SHEET
		cut.region = Rect2(Vector2(0, index * FRAME_HEIGHT), frame_size)
		_frames.append(cut)
	texture = _frames[0]


## The frame the loop is on [param seconds] after it starts.
static func frame_at(seconds: float) -> int:
	return int(floor(fposmod(seconds, LOOP_SECONDS) * FRAMES_PER_SECOND)) % FRAMES


## The frame it is showing.
func frame() -> int:
	return frame_at(_seconds)


## Lets [param seconds] go by and shows the frame the loop is then on.
func advance(seconds: float) -> void:
	_seconds = fposmod(_seconds + seconds, LOOP_SECONDS)
	texture = _frames[frame()]


func _process(delta: float) -> void:
	advance(delta)
