class_name StackArrow
extends Control
## The double-headed arrow down the side of the Stack Window, from "resolves first" at the
## top to "resolves last" at the bottom.


func _draw() -> void:
	var x: float = size.x / 2.0
	var color: Color = Color(1, 1, 1, 0.7)
	draw_line(Vector2(x, 6), Vector2(x, size.y - 6), color, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x - 6, 10), Vector2(x + 6, 10)]), color)
	draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x - 6, size.y - 10), Vector2(x + 6, size.y - 10)]), color)
