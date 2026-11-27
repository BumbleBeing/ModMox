class_name ModIcon
extends TextureRect
## The Mod Icon (game glossary): a Mod's cog in its Rarity's color, SIZE pixels square, drawn
## pixel for pixel. A turning one steps through its Rarity's turning sheet, a quarter turn
## clockwise every LOOP_SECONDS as the Logo's cogs turn; a darkened one shows its Rarity's
## picture, darkened and still. tools/sprites/mod_icons.py draws both.

const STILL: String = "res://ui/sprites/mods/%s.png"
const TURNING: String = "res://ui/sprites/mods/%s_turning.png"
const SIZE: int = 32
const FRAMES: int = 24
const FRAMES_PER_SECOND: int = 8
const LOOP_SECONDS: float = float(FRAMES) / FRAMES_PER_SECOND
## How a cog that cannot be used is darkened.
const DARKENED: Color = Color(0.45, 0.45, 0.45)

var _rarity: Mod.Rarity = Mod.Rarity.COMMON
var _frames: Array[AtlasTexture] = []
var _seconds: float = 0.0


## The cog of [param rarity], turning.
static func turning(rarity: Mod.Rarity) -> ModIcon:
	var made: ModIcon = ModIcon.new()
	made._rarity = rarity
	var sheet: Texture2D = load(TURNING % file_name(rarity)) as Texture2D
	for index: int in FRAMES:
		var cut: AtlasTexture = AtlasTexture.new()
		cut.atlas = sheet
		cut.region = Rect2(0, index * SIZE, SIZE, SIZE)
		made._frames.append(cut)
	made.texture = made._frames[0]
	return made


## The cog of [param rarity], still, as the Satchel shows a Mod held (milestone 24).
static func still(rarity: Mod.Rarity) -> ModIcon:
	var made: ModIcon = ModIcon.new()
	made._rarity = rarity
	made.texture = load(STILL % file_name(rarity)) as Texture2D
	made.set_process(false)
	return made


## The cog of [param rarity], darkened and still.
static func darkened(rarity: Mod.Rarity) -> ModIcon:
	var made: ModIcon = ModIcon.new()
	made._rarity = rarity
	made.texture = load(STILL % file_name(rarity)) as Texture2D
	made.modulate = DARKENED
	made.set_process(false)
	return made


## The name the pictures of [param rarity] are filed under: "common", "rare" and so on.
static func file_name(rarity: Mod.Rarity) -> String:
	return (Mod.Rarity.find_key(rarity) as String).to_lower()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	custom_minimum_size = Vector2(SIZE, SIZE)


func rarity() -> Mod.Rarity:
	return _rarity


func is_turning() -> bool:
	return not _frames.is_empty()


## The frame a turning cog is showing.
func frame() -> int:
	return int(floor(_seconds * FRAMES_PER_SECOND)) % FRAMES


## Lets [param seconds] go by. A turning cog shows the frame its loop is then on; a darkened
## one stays as it is.
func advance(seconds: float) -> void:
	if not is_turning():
		return
	_seconds = fposmod(_seconds + seconds, LOOP_SECONDS)
	texture = _frames[frame()]


func _process(delta: float) -> void:
	advance(delta)
