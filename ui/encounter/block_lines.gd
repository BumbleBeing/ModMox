class_name BlockLines
extends Control
## The lines across the lane that say who blocks whom (A315): one from each blocker to its
## attacker, with an arrowhead at the attacker. A block the Hero is still choosing is pale
## gold, and one that has been declared is white. It lies over the board and under the
## windows, and never takes the mouse.

const CHOSEN: Color = Color("#f3e9a0")
const DECLARED: Color = Color("#e8eaf0")
const WIDTH: float = 4.0

var _shown: Array[Line] = []


## One Block Line, from a blocker to the attacker it blocks.
class Line:
	extends RefCounted
	## At the blocker.
	var from: Vector2
	## At the attacker, where the arrowhead is.
	var to: Vector2
	## Whether the Hero is still choosing this block, rather than having declared it.
	var is_chosen: bool = false

	func _init(blocker_end: Vector2, attacker_end: Vector2, chosen: bool) -> void:
		from = blocker_end
		to = attacker_end
		is_chosen = chosen


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param lines] in place of whatever was shown.
func show_lines(lines: Array[Line]) -> void:
	_shown = lines.duplicate()
	queue_redraw()


func line_count() -> int:
	return _shown.size()


## Where line [param index] starts, at its blocker.
func line_from(index: int) -> Vector2:
	return _shown[index].from


## Where line [param index] ends, at its attacker.
func line_to(index: int) -> Vector2:
	return _shown[index].to


func line_color(index: int) -> Color:
	return CHOSEN if _shown[index].is_chosen else DECLARED


func _draw() -> void:
	for index: int in _shown.size():
		var from: Vector2 = line_from(index)
		var to: Vector2 = line_to(index)
		if from.is_equal_approx(to):
			continue
		draw_line(from, to, line_color(index), WIDTH, true)
		draw_colored_polygon(EncounterLayout.arrowhead(from, to), line_color(index))
