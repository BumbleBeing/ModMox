class_name ScrollRow
extends Control
## A line of permanents that keeps its faces' size and scrolls sideways when there are too
## many to show (A278). An arrow appears at each end it can scroll toward: pressing one
## scrolls, and holding it keeps scrolling quickly. A thin bar under the line shows where it
## is and can be dragged. An arrow takes the color of a Glow hidden past its end (A292).

## The line was scrolled to [param offset] pixels, so whoever redraws it can keep its place.
signal scrolled(offset: float)

const ARROW_WIDTH: float = 26.0
## Pixels a second while an arrow is held, and pixels at once when it is first pressed.
const SPEED: float = 1100.0
const NUDGE: float = 60.0
const BAR_HEIGHT: float = 8.0

var _content: Control
var _left: Button
var _right: Button
var _bar: HScrollBar
var _content_width: float = 0.0
var _offset: float = 0.0


## Shows a line [param content_width] wide in [param view_rect], scrolled to [param offset].
func _init(view_rect: Rect2, content_width: float, offset: float) -> void:
	position = view_rect.position
	size = view_rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_width = content_width
	var window: Control = Control.new()
	window.size = view_rect.size
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(_content)
	_left = _arrow("◀", 0.0, -1.0)
	_right = _arrow("▶", view_rect.size.x - ARROW_WIDTH, 1.0)
	_bar = HScrollBar.new()
	_bar.position = Vector2(ARROW_WIDTH, view_rect.size.y - BAR_HEIGHT)
	_bar.size = Vector2(view_rect.size.x - ARROW_WIDTH * 2.0, BAR_HEIGHT)
	_bar.max_value = content_width
	_bar.page = view_rect.size.x
	_bar.visible = can_scroll()
	_bar.value_changed.connect(func(value: float) -> void: scroll_to(value))
	add_child(_bar)
	scroll_to(offset)


func _process(delta: float) -> void:
	if _left.is_pressed():
		scroll_by(-SPEED * delta)
	elif _right.is_pressed():
		scroll_by(SPEED * delta)


## Where the line's faces go. Its left edge is the start of the line.
func content() -> Control:
	return _content


func offset() -> float:
	return _offset


## Whether the line is wider than its view.
func can_scroll() -> bool:
	return EncounterLayout.max_scroll(_content_width, size.x) > 0.0


func left_arrow() -> Button:
	return _left


func right_arrow() -> Button:
	return _right


## Colors each arrow like the Glow of something hidden past its end of the line, or plain
## for null. The colors are Variants because "no Glow" is not a color.
func tint_arrows(left: Variant, right: Variant) -> void:
	_paint(_left, left)
	_paint(_right, right)


## The Glow color [param arrow] is painted in, or null if it is plain.
func arrow_tint(arrow: Button) -> Variant:
	return arrow.get_meta("tint") if arrow.has_meta("tint") else null


func scroll_by(distance: float) -> void:
	scroll_to(_offset + distance)


## Scrolls to [param offset], stopping at either end. A line that fits is centered.
func scroll_to(offset: float) -> void:
	var before: float = _offset
	_offset = clampf(offset, 0.0, EncounterLayout.max_scroll(_content_width, size.x))
	_content.position.x = EncounterLayout.line_start(_content_width, size.x, _offset)
	_left.visible = _offset > 0.0
	_right.visible = _offset < EncounterLayout.max_scroll(_content_width, size.x)
	_bar.set_value_no_signal(_offset)
	if _offset != before:
		scrolled.emit(_offset)


func _arrow(text: String, x: float, direction: float) -> Button:
	var arrow: Button = Button.new()
	arrow.text = text
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.position = Vector2(x, 0)
	arrow.size = Vector2(ARROW_WIDTH, size.y - BAR_HEIGHT)
	_paint(arrow, null)
	arrow.button_down.connect(func() -> void: scroll_by(NUDGE * direction))
	add_child(arrow)
	return arrow


func _paint(arrow: Button, tint: Variant) -> void:
	# Setting a meta to null removes it, which is how "plain" is remembered.
	arrow.set_meta("tint", tint)
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if tint == null:
			style.bg_color = Color(0.05, 0.05, 0.07, 0.75 if state == "normal" else 0.95)
		else:
			style.bg_color = Color(tint as Color, 0.8 if state == "normal" else 1.0)
		style.set_corner_radius_all(4)
		arrow.add_theme_stylebox_override(state, style)
