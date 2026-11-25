class_name ZoneWindow
extends Panel
## A window over the Encounter Screen that shows a zone's contents: the Stack Window (game
## glossary), a player's Emblems, and later every other zone (13f). Every one can be dragged
## and resized within its bounds, scrolls when its contents overflow, is titled with its
## zone's name and how many things are in it, and keeps its place and size while hidden.
## All but the Stack Window can be closed.

const BAR_HEIGHT: float = 28.0
const SMALLEST: Vector2 = Vector2(200, 120)
## The close button's width and color.
const CLOSE_WIDTH: float = 46.0
const CLOSE_COLOR: Color = Color("#bb0a21")
## The darker red of the close button's border.
const CLOSE_BORDER_COLOR: Color = Color("#5e0510")
## The space between the contents and a strip baked into the bottom edge (game ADR 0085).
const EDGE_GAP: float = 8.0
## The margins round the scrolled contents: each side, and below with no strip.
const SIDE_MARGIN: float = 8.0
const BOTTOM_MARGIN: float = 14.0

## Where the window may be: it is moved and shrunk to stay inside. Empty for anywhere.
var bounds: Rect2 = Rect2()
## How long it takes to ease in or out; the Encounter Screen sets it.
var ease_seconds: float = 0.0

var _zone_name: String
var _tint: Color
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _close: Button = null
var _grip: ColorRect
## The strip baked into the bottom edge, or null for none (game ADR 0085).
var _edge_strip: Panel = null
var _is_dragging: bool = false
var _is_resizing: bool = false
## Where the cursor was pressed on the title bar or the corner, and where the window was
## then. A drag follows the cursor from there, so a window stopped at its bounds waits for
## the cursor to come back to where it holds it, never drifting off it.
var _grab_cursor: Vector2 = Vector2.ZERO
var _grab_rect: Rect2 = Rect2()


func _init(zone_name: String, can_close: bool, tint: Color) -> void:
	_zone_name = zone_name
	_tint = tint
	clip_contents = true
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 0.96)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(tint, 0.35)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 2
	bar.offset_right = -2
	bar.offset_top = 2
	bar.offset_bottom = 2 + BAR_HEIGHT
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_bar_input)
	add_child(bar)
	_title = Label.new()
	_title.position = Vector2(8, 2)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_title)
	if can_close:
		_close = Button.new()
		_close.text = "X"
		_close.focus_mode = Control.FOCUS_NONE
		_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		# Inside the bar, never taller than it.
		_close.offset_left = -3 - CLOSE_WIDTH
		_close.offset_right = -3
		_close.offset_top = 3
		_close.offset_bottom = BAR_HEIGHT - 3
		_close.add_theme_font_size_override("font_size", 14)
		for state: String in ["normal", "hover", "pressed"]:
			var flat: StyleBoxFlat = StyleBoxFlat.new()
			flat.bg_color = CLOSE_COLOR
			if state == "hover":
				flat.bg_color = CLOSE_COLOR.lightened(0.15)
			elif state == "pressed":
				flat.bg_color = CLOSE_COLOR.darkened(0.2)
			flat.set_corner_radius_all(3)
			flat.border_color = CLOSE_BORDER_COLOR
			flat.set_border_width_all(2)
			_close.add_theme_stylebox_override(state, flat)
		_close.pressed.connect(close)
		bar.add_child(_close)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = SIDE_MARGIN
	scroll.offset_top = BAR_HEIGHT + SIDE_MARGIN
	scroll.offset_right = -SIDE_MARGIN
	scroll.offset_bottom = -BOTTOM_MARGIN
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)
	_scroll = scroll
	var grip: ColorRect = ColorRect.new()
	grip.color = Color(tint, 0.8)
	grip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.offset_left = -14
	grip.offset_top = -14
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(_on_grip_input)
	add_child(grip)
	_grip = grip
	show_count(0)


## The window's size around contents of [param inner], as its margins and title bar leave
## room for them, with a strip [param edge_height] tall baked into its bottom edge
## (bake_button()), or none for 0.
static func size_around(inner: Vector2, edge_height: float = 0.0) -> Vector2:
	var below: float = BOTTOM_MARGIN if edge_height <= 0.0 else EDGE_GAP + edge_height + 2.0
	return Vector2(inner.x + SIDE_MARGIN * 2.0 + 4.0, inner.y + BAR_HEIGHT + SIDE_MARGIN + below)


## Bakes [param button], [param button_size] big, into the window's bottom edge (game ADR
## 0085): a strip along the bottom, inside the border, as the title bar runs along the top,
## exactly as tall as the button and in the bar's color, its bottom corners rounded to the
## window's. The button is anchored to the strip's middle, so it stays centered however the
## window is resized. The contents scroll above the strip, and the resize grip stays on top.
func bake_button(button: Button, button_size: Vector2) -> void:
	_edge_strip = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_tint, 0.35)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_edge_strip.add_theme_stylebox_override("panel", style)
	_edge_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_edge_strip.offset_left = 2
	_edge_strip.offset_right = -2
	_edge_strip.offset_bottom = -2
	_edge_strip.offset_top = -2 - button_size.y
	_edge_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge_strip)
	move_child(_grip, -1)
	_scroll.offset_bottom = -(EDGE_GAP + button_size.y + 2.0)
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.anchor_top = 0.0
	button.anchor_bottom = 1.0
	button.offset_left = -button_size.x / 2.0
	button.offset_right = button_size.x / 2.0
	button.offset_top = 0
	button.offset_bottom = 0
	_edge_strip.add_child(button)


## The strip baked into the bottom edge, or null for none.
func edge_strip() -> Control:
	return _edge_strip


## Where the window's contents go.
func body() -> VBoxContainer:
	return _body


## What scrolls the window's contents when they overflow.
func scroll() -> ScrollContainer:
	return _scroll


## Shows the window, easing in.
func open() -> void:
	Easing.appear(self, ease_seconds)


## Hides the window, easing out. It is closed at once and takes no clicks while it fades.
func close() -> void:
	Easing.disappear(self, ease_seconds)


## Opens or closes the window; one already so is left as it is.
func set_open(is_wanted: bool) -> void:
	if is_wanted:
		open()
	elif is_open():
		close()


func is_open() -> bool:
	return Easing.is_shown(self)


## The close button, or null for a window that cannot be closed.
func close_button() -> Button:
	return _close


func title_text() -> String:
	return _title.text


## Titles the window with its zone's name and [param count] in parentheses.
func show_count(count: int) -> void:
	_title.text = "%s (%d)" % [_zone_name, count]


## Titles the window with just [param text], for one that is not a zone.
func show_title(text: String) -> void:
	_title.text = text


## Empties the window's contents.
func clear() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


## Shrinks and moves the window to stay inside its bounds.
func fit() -> void:
	if bounds.size == Vector2.ZERO:
		return
	size = size.clamp(SMALLEST.min(bounds.size), bounds.size)
	position = position.clamp(bounds.position, bounds.end - size)


## Moves the window by [param offset], as dragging its title bar does.
func drag_by(offset: Vector2) -> void:
	position += offset
	fit()


## Resizes the window by [param offset], as dragging its corner does. Its top left stays
## where it is: it grows no further than its bounds and shrinks no smaller than SMALLEST.
func resize_by(offset: Vector2) -> void:
	_resize_to(size + offset)


func _resize_to(wanted: Vector2) -> void:
	if bounds.size == Vector2.ZERO:
		size = wanted.max(SMALLEST)
		return
	size = wanted.clamp(SMALLEST.min(bounds.size), (bounds.end - position).max(SMALLEST.min(bounds.size)))
	fit()


func _on_bar_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging = button.pressed
		_grab(button.global_position)
		move_to_front()
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _is_dragging:
		position = _grab_rect.position + motion.global_position - _grab_cursor
		fit()


func _on_grip_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_is_resizing = button.pressed
		_grab(button.global_position)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _is_resizing:
		_resize_to(_grab_rect.size + motion.global_position - _grab_cursor)


func _grab(cursor: Vector2) -> void:
	_grab_cursor = cursor
	_grab_rect = Rect2(position, size)
