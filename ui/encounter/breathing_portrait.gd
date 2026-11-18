class_name BreathingPortrait
extends Control
## A Portrait in its square, cropped to it, drawn with hard pixels as large as its Breath
## has grown (BreathDrawing). The player panel and the breath lab both draw one.

var _picture: TextureRect = TextureRect.new()
var _growth: float = 0.0


func _init(box: Rect2) -> void:
	position = box.position
	size = box.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_picture)
	_place()


## The picture drawn, which is larger than the square at the top of a breath.
func picture() -> TextureRect:
	return _picture


func set_texture(texture: Texture2D) -> void:
	_picture.texture = texture
	_place()


func texture() -> Texture2D:
	return _picture.texture


## Draws the Portrait [param growth] of its own pixels larger than at rest.
func show_growth(growth: float) -> void:
	_growth = growth
	_place()


func _place() -> void:
	var art: Vector2 = _picture.texture.get_size() if _picture.texture != null else Vector2(32, 32)
	var drawn: Rect2 = BreathDrawing.rect(size, art, _growth)
	_picture.position = drawn.position
	_picture.size = drawn.size
