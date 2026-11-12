class_name HoldPanel
extends Control
## The Hold Panel (game glossary): the box at the top left of the battlefield, opposite the
## Info Panel, that says "Holding Priority" in large type. It shows only while the Hold Key
## is down, to say nothing will be passed for the Hero.

const TEXT: String = "Holding Priority"
const FONT_SIZE: int = 30
const COLOR: Color = Color(1, 0.85, 0.4)

var _label: Label = null
var _built_for: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


## Puts the panel in [param box]. It is built once, and again only for another size.
func place(box: Rect2) -> void:
	position = box.position
	size = box.size
	if box.size == _built_for:
		return
	_built_for = box.size
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_child(CardShapes.rounded(box.size, 8, Color("#2c323c")))
	add_child(CardShapes.outline(box.size, 8, 2, COLOR))
	_label = Label.new()
	_label.text = TEXT
	_label.size = box.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size())
	_label.add_theme_color_override("font_color", COLOR)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Shows the panel while the Hold Key is down, and hides it otherwise.
func set_key_down(is_down: bool) -> void:
	visible = is_down


func text() -> String:
	return _label.text


func font_size() -> int:
	return FONT_SIZE + UiText.RAISE


## How wide the words are as drawn.
func text_width() -> float:
	return _label.get_theme_font("font").get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size()).x
