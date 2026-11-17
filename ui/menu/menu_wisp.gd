class_name MenuWisp
extends Control
## The Wisp on the main menu: draws itself where its WispFlight is, at a whole multiple of
## its sprite's size, on whole pixels. It fades in as the menu opens, and after each touch
## its next color's sprite fades in over the last one's. Each color flickers through all
## of its frames. It takes no clicks.

## Emitted each frame once it has moved, so that its Wisp Light can be drawn again.
signal moved

const SPRITE_SIZE: int = 6
const SCALE: int = MenuSoldier.SCALE
## A flash color's frames: wisp_white_0, wisp_white_1 and so on, as many as there are, built
## from tools/sprites/wisp_sprites.txt.
const SPRITES: String = "res://ui/sprites/menu/wisp_%s_%d.png"
## How long each frame of its flicker shows, in seconds.
const HOLD: float = 0.15

var _flight: WispFlight
var _soldier: MenuSoldier
var _window: Control
## Each flash frame's sprites for the Wisp.
var _frames: Dictionary[String, Array] = {}
var _clock: float = 0.0


## A Wisp that brings [param soldier] his effects, flying round [param window], making its
## random choices with [param random], or at random if none is given.
func _init(soldier: MenuSoldier, window: Control, random: RandomNumberGenerator = null) -> void:
	_soldier = soldier
	_window = window
	# A new generator starts from a random seed of its own.
	_flight = WispFlight.new(soldier.sequence(), random if random != null else RandomNumberGenerator.new())
	# After the soldier's, so that it reads his sequence as it is this frame.
	process_priority = soldier.process_priority + 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2.ONE * SPRITE_SIZE * SCALE
	visible = false
	for flash: String in SoldierAnimations.FLASH_COLORS:
		_frames[flash] = textures_of(flash)


## The Wisp's sprites for the flash frame [param flash], in the order they flicker through.
static func textures_of(flash: String) -> Array[Texture2D]:
	var found: Array[Texture2D] = []
	var color: String = flash.trim_prefix("flash_")
	while ResourceLoader.exists(SPRITES % [color, found.size()]):
		found.append(load(SPRITES % [color, found.size()]) as Texture2D)
	return found


## Which of [param count] frames shows [param seconds] after it first appeared.
static func frame_at(seconds: float, count: int) -> int:
	return posmod(floori(seconds / HOLD), maxi(count, 1))


## Where it flies, and in what color.
func flight() -> WispFlight:
	return _flight


## Where it is drawn now, on the screen.
func drawn_rect() -> Rect2:
	return Rect2((_flight.position() - size / 2).round(), size)


func _process(delta: float) -> void:
	_clock += delta
	_flight.set_ground(_soldier.chest(), _window.get_global_rect(), (get_parent() as Control).get_global_rect())
	visible = _flight.is_flying()
	if not visible:
		return
	global_position = drawn_rect().position
	queue_redraw()
	moved.emit()


func _draw() -> void:
	var shown: float = _flight.opacity()
	_draw_frame(_flight.flash_from(), shown)
	var turned: float = _flight.blend()
	if turned > 0.0 and _flight.flash_to() != _flight.flash_from():
		_draw_frame(_flight.flash_to(), shown * turned)


func _draw_frame(flash: String, alpha: float) -> void:
	var frames: Array = _frames[flash]
	if frames.is_empty():
		return
	draw_texture_rect(frames[frame_at(_clock, frames.size())] as Texture2D, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, alpha))
