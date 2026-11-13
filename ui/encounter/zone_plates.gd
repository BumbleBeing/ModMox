class_name ZonePlates
extends Control
## The Zone Plates (game glossary): a rounded, mostly see-through gray rectangle behind each
## row of the battlefield and each pile, which shows where the zone is and sets it off from
## the Backdrop. One node draws them all, over the Backdrop and under the board; it is built
## once and only told where they go (EncounterLayout.zone_plates()).

const COLOR: Color = Color(0.64, 0.66, 0.70, 0.14)
const RADIUS: int = 12

var _rects: Array[Rect2] = []
var _box: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.bg_color = COLOR
	_box.set_corner_radius_all(RADIUS)


## Draws a plate at each of [param rects], in the screen's coordinates.
func place(rects: Array[Rect2]) -> void:
	if rects == _rects:
		return
	_rects = rects
	queue_redraw()


func rects() -> Array[Rect2]:
	return _rects


func _draw() -> void:
	for rect: Rect2 in _rects:
		draw_style_box(_box, rect)
