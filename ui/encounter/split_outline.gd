class_name SplitOutline
extends Control
## A rounded outline in two colors, for the Glow of something that offers two kinds of
## thing: the first color along the top and left, the second along the bottom and right,
## blending over a short stretch at the two corners where they meet.

## How much of the way from one corner to the other the blend takes, each side of the middle.
const BLEND: float = 0.14
## How many points each corner and each side is drawn with.
const CORNER_STEPS: int = 8
const SIDE_STEPS: int = 24

var _first: Color
var _second: Color
var _width: float
var _radius: float
## How far outside its own rectangle the outline's outer edge is.
var _grow: float


func _init(host_size: Vector2, first: Color, second: Color, grow: float, radius: float, width: float) -> void:
	size = host_size
	_first = first
	_second = second
	_grow = grow
	_radius = radius
	_width = width
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The rectangle the middle of the line runs around, in this Control's own coordinates.
func box() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(_grow - _width / 2.0)


## The color of the line at [param point].
func color_at(point: Vector2) -> Color:
	return _first.lerp(_second, share_at(point, box()))


## How much of the second color the line has at [param point] on an outline around
## [param around]: none at the top left corner, all of it at the bottom right.
static func share_at(point: Vector2, around: Rect2) -> float:
	var center: Vector2 = around.get_center()
	var along: float = (point.x - center.x) / around.size.x + (point.y - center.y) / around.size.y
	return smoothstep(-BLEND, BLEND, along)


## The points of a closed outline around [param around] with corners of [param radius],
## clockwise from the top left corner. The first two points are repeated at the end, so a
## line drawn through them joins itself.
static func points(around: Rect2, radius: float) -> PackedVector2Array:
	var found: PackedVector2Array = PackedVector2Array()
	var centers: Array[Vector2] = [
		around.position + Vector2(radius, radius), Vector2(around.end.x - radius, around.position.y + radius),
		around.end - Vector2(radius, radius), Vector2(around.position.x + radius, around.end.y - radius)]
	for corner: int in 4:
		var start: float = PI + corner * PI / 2.0
		for step: int in CORNER_STEPS + 1:
			found.append(centers[corner] + Vector2.from_angle(start + PI / 2.0 * step / CORNER_STEPS) * radius)
		var from: Vector2 = found[found.size() - 1]
		var to: Vector2 = centers[(corner + 1) % 4] + Vector2.from_angle(start + PI / 2.0) * radius
		for step: int in range(1, SIDE_STEPS):
			found.append(from.lerp(to, float(step) / SIDE_STEPS))
	found.append(found[0])
	found.append(found[1])
	return found


func _draw() -> void:
	var line: PackedVector2Array = points(box(), _radius - _width / 2.0)
	var colors: PackedColorArray = PackedColorArray()
	for point: Vector2 in line:
		colors.append(color_at(point))
	draw_polyline_colors(line, colors, _width, true)
