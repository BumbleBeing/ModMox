class_name MenuSoldier
extends Control
## The Menu Soldier on the main menu: draws the frame his Soldier Sequence is on, at a whole
## multiple of its size, a raised frame that many of its pixels above his box. The Wisp,
## which brings him his effects, asks [method sequence] which comes next and when he flashes,
## and touches him at [method chest].

## Emitted when he shows a different frame, with its name.
signal frame_changed(frame: String)
## Emitted when his Soldier Shadow looks different: fading, or taking a flash's color.
signal shadow_changed

const SPRITE_SIZE: int = 32
const SCALE: int = 8
## Where the Wisp touches him, in his sprite's pixels: the middle of his tunic, above the
## belt, whatever frame he is showing.
const CHEST: Vector2 = Vector2(16, 19.5)

## The frame he is showing.
var texture: Texture2D

var _sequence: SoldierSequence
var _textures: Dictionary[String, Texture2D] = {}
## Where each frame touches the ground: its columns black on the row that lands on it
## (SoldierShadow).
var _contacts: Dictionary[String, Array] = {}
var _frame: String = SoldierAnimations.NEUTRAL
var _shadow: SoldierShadow


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
		var raised: int = SoldierAnimations.raise_of(frame)
		_contacts[frame] = SoldierShadow.contacts_of(_textures[frame].get_image(), raised)
	_frame = _sequence.frame()
	texture = _textures[_frame]
	_shadow = SoldierShadow.new(contacts())


## The order he plays his animations in, and the hook for the Wisp, which brings him his effects.
func sequence() -> SoldierSequence:
	return _sequence


## Where the Wisp touches him, on the screen.
func chest() -> Vector2:
	return get_global_rect().position + CHEST * SCALE


## The shadow he casts on what he stands on.
func shadow() -> SoldierShadow:
	return _shadow


## Where the frame he is showing is drawn, in his own coordinates: his box, or as many of its
## pixels higher as the frame is raised.
func drawn() -> Rect2:
	return Rect2(Vector2(0, -SoldierAnimations.raise_of(_frame) * SCALE), size)


## The columns of his sprite where the frame he is showing touches the ground.
func contacts() -> Array[int]:
	var found: Array[int] = []
	found.assign(_contacts[_frame])
	return found


## Lets [param seconds] go by and shows the frame he is then on, and his shadow as it then is.
func advance(seconds: float) -> void:
	_sequence.advance(seconds)
	if _sequence.frame() != _frame:
		_frame = _sequence.frame()
		texture = _textures[_frame]
		queue_redraw()
		frame_changed.emit(_frame)
	if _shadow.advance(seconds, contacts(), _frame):
		shadow_changed.emit()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	draw_texture_rect(texture, drawn(), false)
