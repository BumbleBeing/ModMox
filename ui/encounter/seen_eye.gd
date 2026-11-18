class_name SeenEye
extends Control
## A small eye on the top card of the Hero's library while they may look at it: only the
## Hero sees this card (game ADR 0055).

const SIDE: float = 24.0
const BACKING: Color = Color("#1b1f27")
const INK: Color = Color("#e8e2cf")


func _init() -> void:
	size = Vector2(SIDE, SIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var middle: Vector2 = size / 2.0
	draw_circle(middle, SIDE / 2.0, BACKING)
	draw_arc(middle, SIDE / 2.0 - 1.0, 0, TAU, 24, Color(1, 1, 1, 0.55), 1.5, true)
	# Two lids, each an arc of a circle whose middle is past the other lid.
	draw_arc(middle + Vector2(0, 7), 10.0, PI * 1.23, PI * 1.77, 12, INK, 2.0, true)
	draw_arc(middle - Vector2(0, 7), 10.0, PI * 0.23, PI * 0.77, 12, INK, 2.0, true)
	draw_circle(middle, 3.2, INK)
	draw_circle(middle, 1.4, BACKING)
