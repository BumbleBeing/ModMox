class_name MenuSoldier
extends TextureRect
## The Menu Soldier on the main menu: draws the frame his Soldier Sequence is on, at a whole
## multiple of its size. What brings him his effects asks [method sequence] which comes next
## and when he flashes, and finds where he stands from this node's rectangle.

const SPRITE_SIZE: int = 32
const SCALE: int = 8

var _sequence: SoldierSequence
var _textures: Dictionary[String, Texture2D] = {}


## A soldier whose sequence chooses with [param random], or at random if none is given.
func _init(random: RandomNumberGenerator = null) -> void:
	# A new generator starts from a random seed of its own.
	_sequence = SoldierSequence.new(random if random != null else RandomNumberGenerator.new())
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * SPRITE_SIZE * SCALE
	# Every frame loaded now, so that none is late the first time it shows.
	for frame: String in SoldierAnimations.frames():
		_textures[frame] = load(SoldierAnimations.SPRITES % frame) as Texture2D
	texture = _textures[_sequence.frame()]


## The order he plays his animations in, and the hook for what brings him his effects.
func sequence() -> SoldierSequence:
	return _sequence


## Lets [param seconds] go by and shows the frame he is then on.
func advance(seconds: float) -> void:
	_sequence.advance(seconds)
	texture = _textures[_sequence.frame()]


func _process(delta: float) -> void:
	advance(delta)
