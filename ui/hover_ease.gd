class_name HoverEase
extends RefCounted
## How every button lightens under the cursor (game ADR 0066): eased in and out over TIME,
## smooth but quick, never switched. A button's own "hover" style is left to say what it
## looks like there; the ease draws the difference between that and its "normal" style as a
## layer over the button, faded in when the cursor comes and out when it goes, and has the
## button draw its normal style meanwhile. The layer stays out while the button cannot be
## pressed, is held down or is toggled on.
##
## watch() does this for every plain Button added to a scene tree from then on, each made
## ready only the first time the cursor reaches it, so a screen that rebuilds its buttons
## pays nothing for it. A button whose hover is a layer of its own, as a steel-framed one's
## is, hands that layer to ease() instead.
##
## The difference can be drawn for a style painted as a texture and for a flat one, when
## the hover is the normal lightened or darkened. Any other hover is left to switch.

const TIME: float = 0.1
## The name of the layer on a button.
const LAYER: String = "HoverLayer"
## On a button: the normal style its hover was replaced with, and that its layer is its own.
const NORMAL_META: StringName = &"hover_ease_normal"
const OWN_META: StringName = &"hover_ease_own"

static var _differences: Dictionary[String, StyleBox] = {}


## Eases the hover of every plain Button in [param tree], and of each added to it later.
static func watch(tree: SceneTree) -> void:
	if tree.node_added.is_connected(_on_node_added):
		return
	tree.node_added.connect(_on_node_added)
	_watch_under(tree.root)


## Stops watching [param tree]. Buttons already made ready keep their ease.
static func unwatch(tree: SceneTree) -> void:
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


static func is_watching(tree: SceneTree) -> bool:
	return tree.node_added.is_connected(_on_node_added)


## Makes [param layer] what shows [param button] is under the cursor: it is put on the
## button, under anything added later, and eased in and out. A button made under a cursor
## that is already there starts lit.
static func ease(button: Button, layer: Control) -> void:
	var old: Node = button.get_node_or_null(LAYER)
	if old != null:
		button.remove_child(old)
		old.queue_free()
	layer.name = LAYER
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.modulate.a = 0.0
	button.add_child(layer)
	button.move_child(layer, 0)
	if button.has_meta(OWN_META):
		return
	button.set_meta(OWN_META, true)
	button.mouse_entered.connect(_light.bind(button))
	button.mouse_exited.connect(_fade.bind(button, 0.0))
	button.button_down.connect(_put_out.bind(button))
	button.button_up.connect(_light_if_hovered.bind(button))
	button.ready.connect(_light_if_under_cursor.bind(button), CONNECT_ONE_SHOT)


## The layer that lights [param button] under the cursor, or null if it has none yet.
static func layer_of(button: Button) -> Control:
	return button.get_node_or_null(LAYER) as Control


## Gives [param button] its layer from its own "normal" and "hover" styles, if it has none
## for them yet, and has it draw its normal style under the cursor. Returns whether its
## hover is eased: false when the two styles are the same or their difference cannot be drawn.
static func prepare(button: Button) -> bool:
	if button.has_meta(OWN_META):
		return true
	var normal: StyleBox = button.get_theme_stylebox("normal")
	var hover: StyleBox = button.get_theme_stylebox("hover")
	if button.has_meta(NORMAL_META) and button.get_meta(NORMAL_META) == normal and hover == normal and layer_of(button) != null:
		return true
	var difference: StyleBox = difference_of(normal, hover)
	if difference == null:
		return false
	button.set_meta(NORMAL_META, normal)
	button.add_theme_stylebox_override("hover", normal)
	var old: Node = button.get_node_or_null(LAYER)
	if old != null:
		button.remove_child(old)
		old.queue_free()
	var layer: Panel = Panel.new()
	layer.name = LAYER
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.modulate.a = 0.0
	layer.add_theme_stylebox_override("panel", difference)
	button.add_child(layer)
	button.move_child(layer, 0)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return true


## What drawn over [param normal] makes it [param hover]: white where the hover is lighter
## and black where it is darker, as thick as the difference. Null when the two are the same
## or of kinds whose difference cannot be drawn.
static func difference_of(normal: StyleBox, hover: StyleBox) -> StyleBox:
	if normal == null or hover == null or normal == hover:
		return null
	var key: String = "%d/%d" % [normal.get_instance_id(), hover.get_instance_id()]
	if _differences.has(key):
		return _differences[key]
	var made: StyleBox = null
	if normal is StyleBoxTexture and hover is StyleBoxTexture:
		made = _texture_difference(normal as StyleBoxTexture, hover as StyleBoxTexture)
	elif normal is StyleBoxFlat and hover is StyleBoxFlat:
		made = _flat_difference(normal as StyleBoxFlat, hover as StyleBoxFlat)
	elif normal is StyleBoxEmpty and hover is StyleBoxFlat and (hover as StyleBoxFlat).bg_color.a < 0.5:
		# A see-through wash over nothing is its own difference.
		made = hover
	_differences[key] = made
	return made


## The see-through color that, drawn over [param from], gives [param to]: white or black.
## Both are taken as opaque.
static func wash(from: Color, to: Color) -> Color:
	var change: float = (to.r - from.r) + (to.g - from.g) + (to.b - from.b)
	if is_zero_approx(change):
		return Color(1, 1, 1, 0)
	var share: float = 0.0
	if change > 0.0:
		var room: float = (1.0 - from.r) + (1.0 - from.g) + (1.0 - from.b)
		share = change / room if room > 0.0 else 0.0
		return Color(1, 1, 1, clampf(share, 0.0, 1.0))
	var depth: float = from.r + from.g + from.b
	share = -change / depth if depth > 0.0 else 0.0
	return Color(0, 0, 0, clampf(share, 0.0, 1.0))


static func _texture_difference(normal: StyleBoxTexture, hover: StyleBoxTexture) -> StyleBox:
	if normal.texture == null or hover.texture == null:
		return null
	var under: Image = normal.texture.get_image()
	var over: Image = hover.texture.get_image()
	if under == null or over == null or under.get_size() != over.get_size():
		return null
	var image: Image = Image.create_empty(over.get_width(), over.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in over.get_height():
		for x: int in over.get_width():
			var from: Color = under.get_pixel(x, y)
			var to: Color = over.get_pixel(x, y)
			if to.a == 0.0 or from.a == 0.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				image.set_pixel(x, y, wash(from, to))
	var made: StyleBoxTexture = hover.duplicate() as StyleBoxTexture
	made.texture = ImageTexture.create_from_image(image)
	return made


static func _flat_difference(normal: StyleBoxFlat, hover: StyleBoxFlat) -> StyleBox:
	var made: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	made.shadow_size = 0
	if is_zero_approx(normal.bg_color.a):
		# Over nothing, the hover's own fill is the difference.
		if hover.bg_color.a >= 0.5:
			return null
	elif normal.bg_color.a < 1.0 or hover.bg_color.a < 1.0:
		return null
	else:
		made.bg_color = wash(normal.bg_color, hover.bg_color)
	made.border_color = wash(normal.border_color, hover.border_color) if normal.border_color.a == 1.0 and hover.border_color.a == 1.0 \
		else Color(1, 1, 1, 0)
	return made


static func _watch_under(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_watch_under(child)


## A plain Button, or a script's own kind of one: not a checkbox, a menu or a link.
static func _on_node_added(node: Node) -> void:
	var button: Button = node as Button
	if button == null or button.get_class() != "Button" or button.mouse_entered.is_connected(_on_entered):
		return
	button.mouse_entered.connect(_on_entered.bind(button))


## The cursor reached a watched button: it is made ready the first time, and again if it
## has been styled anew since, and then lit.
static func _on_entered(button: Button) -> void:
	if button.has_meta(OWN_META):
		return
	if not button.mouse_exited.is_connected(_fade):
		button.mouse_exited.connect(_fade.bind(button, 0.0))
		button.button_down.connect(_put_out.bind(button))
		button.button_up.connect(_light_if_hovered.bind(button))
	if prepare(button):
		_light(button)


static func _light(button: Button) -> void:
	if not button.disabled and not (button.toggle_mode and button.button_pressed):
		_fade(button, 1.0)


static func _light_if_hovered(button: Button) -> void:
	if button.is_hovered():
		_light(button)


static func _light_if_under_cursor(button: Button) -> void:
	var layer: Control = layer_of(button)
	if layer != null and not button.disabled and Rect2(Vector2.ZERO, button.size).has_point(button.get_local_mouse_position()):
		layer.modulate.a = 1.0


static func _put_out(button: Button) -> void:
	var layer: Control = layer_of(button)
	if layer != null:
		layer.modulate.a = 0.0


static func _fade(button: Button, to: float) -> void:
	var layer: Control = layer_of(button)
	if layer == null:
		return
	if not button.is_inside_tree():
		layer.modulate.a = to
		return
	var tween: Tween = layer.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(layer, "modulate:a", to, TIME)
