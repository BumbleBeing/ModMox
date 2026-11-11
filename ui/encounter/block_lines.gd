class_name BlockLines
extends Control
## The lines across the lane that say who blocks whom (A315): one from each blocker to its
## attacker, with an arrowhead at the attacker. A block the Hero is still choosing is pale
## gold, and one that has been declared is white. It lies over the board and under the
## windows, and never takes the mouse.

const CHOSEN: Color = Color("#f3e9a0")
const DECLARED: Color = Color("#e8eaf0")
const WIDTH: float = 4.0

## Each line as [from, to, is_chosen].
var _shown: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param lines], each [from, to, is_chosen] with the attacker at "to", in place of
## whatever was shown.
func show_lines(lines: Array) -> void:
	_shown = lines.duplicate(true)
	queue_redraw()


func line_count() -> int:
	return _shown.size()


## Where line [param index] starts, at its blocker.
func line_from(index: int) -> Vector2:
	return _shown[index][0]


## Where line [param index] ends, at its attacker.
func line_to(index: int) -> Vector2:
	return _shown[index][1]


func line_color(index: int) -> Color:
	return CHOSEN if _shown[index][2] else DECLARED


func _draw() -> void:
	for index: int in _shown.size():
		var from: Vector2 = line_from(index)
		var to: Vector2 = line_to(index)
		if from.is_equal_approx(to):
			continue
		draw_line(from, to, line_color(index), WIDTH, true)
		draw_colored_polygon(EncounterLayout.arrowhead(from, to), line_color(index))
