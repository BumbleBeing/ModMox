class_name StackArrows
extends Control
## The curved arrows down the left of the Stack Window's entries, each from a spell to the
## spell on the stack it targets, in the targeting spell's color (A355). Several bow out
## to different depths so they do not overlap. It is as wide as its arrows need, and no
## wider than nothing when there are none.

const FIRST_BOW: float = 12.0
const BOW_STEP: float = 12.0
const WIDTH: float = 2.5
const HEAD: float = 9.0

## Each arrow as [from entry, to entry, color].
var _shown: Array = []


## How wide a gutter [param count] arrows need.
static func width_for(count: int) -> float:
	return 0.0 if count == 0 else FIRST_BOW + BOW_STEP * count + 4.0


## How far arrow number [param index] bows out to the left.
static func bow(index: int) -> float:
	return FIRST_BOW + BOW_STEP * index


## Shows [param arrows], each [from entry, to entry, color]. The entries must stand in a
## column beside this Control, with the same top.
func show_arrows(arrows: Array) -> void:
	_shown = arrows
	custom_minimum_size.x = width_for(arrows.size())
	queue_redraw()


func arrow_count() -> int:
	return _shown.size()


func arrow_color(index: int) -> Color:
	return _shown[index][2]


## Where arrow [param index] starts and ends: the left side of each entry, a little apart
## from its middle so an arrow in and an arrow out of one entry do not meet.
func arrow_from(index: int) -> Vector2:
	var entry: Control = _shown[index][0]
	return Vector2(size.x, entry.position.y + entry.size.y * 0.5 + 6.0)


func arrow_to(index: int) -> Vector2:
	var entry: Control = _shown[index][1]
	return Vector2(size.x, entry.position.y + entry.size.y * 0.5 - 6.0)


func _draw() -> void:
	for index: int in _shown.size():
		var from: Vector2 = arrow_from(index)
		var to: Vector2 = arrow_to(index)
		var out: Vector2 = Vector2(bow(index) * 1.4, 0)
		var points: PackedVector2Array = []
		for step: int in 25:
			points.append(from.bezier_interpolate(from - out, to - out, to - Vector2(HEAD - 2.0, 0), step / 24.0))
		draw_polyline(points, arrow_color(index), WIDTH, true)
		draw_colored_polygon(PackedVector2Array([to, to + Vector2(-HEAD, -6), to + Vector2(-HEAD, 6)]), arrow_color(index))
