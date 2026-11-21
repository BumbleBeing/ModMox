class_name RunEndDisc
extends Control
## A Boss on Run Won or Run Lost (milestone 19, signed off as step 2 of prototypes/run_ends):
## its Portrait in a disc filled with its Stage's ground color, ringed with a jewel in that
## hue (BossDisc.draw_jeweled()). A beaten Boss's disc is still; only a Boss not beaten
## breathes.

var portrait: Texture2D
## The color the disc is filled with: its Stage's ground (RunEndScreen.ground_of()).
var ground: Color
var radius: float
var portrait_scale: float = 1.0
var is_breathing: bool = false

var _seconds: float = 0.0


func _init(boss_portrait: Texture2D, stage_ground: Color, disc_radius: float, room: Vector2) -> void:
	portrait = boss_portrait
	ground = stage_ground
	radius = disc_radius
	custom_minimum_size = room
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Lets the Boss breathe, as one not beaten does.
func breathe() -> void:
	is_breathing = true
	set_process(true)


## How far into its breath the Boss is drawn: always 0, at rest, unless it breathes.
func seconds_drawn() -> float:
	return _seconds if is_breathing else 0.0


func _process(delta: float) -> void:
	_seconds += delta
	queue_redraw()


func _draw() -> void:
	BossDisc.draw_jeweled(self, size / 2.0, radius, portrait, seconds_drawn(), ground, portrait_scale)
