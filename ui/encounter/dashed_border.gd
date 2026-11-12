class_name DashedBorder
extends Control
## A dashed outline around something: a trigger still being put in order, or the target of
## the Stack Window entry under the cursor (A337). Dashes read as "about to happen".

const DASH: float = 7.0

var _color: Color
var _width: float
## How far outside its own rectangle the outline is drawn.
var _grow: float


func _init(border_size: Vector2, color: Color, width: float, grow: float = 0.0) -> void:
	size = border_size
	_color = color
	_width = width
	_grow = grow
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func color() -> Color:
	return _color


## Where the outline runs, in this Control's own coordinates.
func outline() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(_grow)


func _draw() -> void:
	var rect: Rect2 = outline()
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index: int in 4:
		draw_dashed_line(corners[index], corners[(index + 1) % 4], _color, _width, DASH)
