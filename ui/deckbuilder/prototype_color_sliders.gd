extends SceneTree
## PROTOTYPE, throwaway: the deckbuilder with RGB sliders for its two background colors,
## to compare color schemes quickly. Not part of the game; delete once the colors are chosen.
##
##   ~/Desktop/Godot_v4.7.2-stable_linux.x86_64 --path . -s res://ui/deckbuilder/prototype_color_sliders.gd
##
## "Maroon" is the pane color (DeckbuilderLook.PANE); the bench, borders and panels are
## moved with it, keeping how much darker or lighter than a pane each one is. "Rose" is the
## deck columns' and the Collection's color (DeckbuilderLook.COLUMN). Nothing in the real
## code changes: a shader on the background panels swaps each shade they draw of a
## background color, flat or dithered, for the same shade of the chosen one, and leaves
## cards, buttons and text alone. Tab hides the sliders.
## Save keeps the pair as a swatch to click back to; the console prints the colors.

## How many colors the shader can match: each background color and every shade of it
## that the deckbuilder draws.
const MATCHES: int = 96
## The background colors that follow the pane color, kept as much darker or lighter than a
## pane as they are now.
const FAMILY: Array[String] = ["BENCH", "PANE", "PANE_BORDER", "MODIFY_PANEL", "SUBPANEL", "INSPECTOR_PANEL",
	"SUBPANEL_BORDER"]

const SHADER: String = """
shader_type canvas_item;
uniform int count;
uniform vec3 from_colors[96];
uniform vec3 to_colors[96];

// A pixel that is one of the colors drawn now (to within 8-bit rounding) takes the
// same shade of the chosen color; any other pixel is left alone.
void fragment() {
	for (int i = 0; i < count; i++) {
		vec3 gap = abs(COLOR.rgb - from_colors[i]);
		if (max(gap.r, max(gap.g, gap.b)) < 1.0 / 255.0) {
			COLOR.rgb = to_colors[i];
			break;
		}
	}
}
"""

## Hides and shows the sliders on Tab.
class Toggler:
	extends Node
	var target: CanvasItem = null

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_TAB:
			target.visible = not target.visible
			get_viewport().set_input_as_handled()

var _screen: Node = null
var _material: ShaderMaterial = null
var _overlay: PanelContainer = null
var _sliders: Dictionary[String, Array] = {}
var _hex_boxes: Dictionary[String, LineEdit] = {}
var _swatches: Dictionary[String, ColorRect] = {}
var _saved: HFlowContainer = null
var _colors: Dictionary[String, Color] = {
	"maroon": DeckbuilderLook.PANE,
	"rose": DeckbuilderLook.COLUMN,
}
var _is_syncing: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_screen = (load("res://ui/deckbuilder/deckbuilder_screen.tscn") as PackedScene).instantiate()
	root.add_child(_screen)
	_build_overlay()
	_apply()
	# Panels come and go (the inspector's, a pop-up's), so they are looked for again often.
	var timer: Timer = Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_tag_backgrounds)
	root.add_child(timer)
	_tag_backgrounds()


## Puts the recoloring shader on every background the deckbuilder draws: panels and
## plates, never a card, a button or text.
func _tag_backgrounds() -> void:
	if not is_instance_valid(_screen):
		return
	var pending: Array[Node] = [_screen]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CardFace or node is BaseButton or node is LineEdit or node is Label or node is RichTextLabel:
			continue
		if node == _overlay:
			continue
		if (node is Panel or node is PanelContainer or node is ColorRect or node is TextureRect) \
				and (node as CanvasItem).material == null:
			(node as CanvasItem).material = _material
		pending.append_array(node.get_children())


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	_overlay = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09, 0.94)
	style.border_color = Color(0.6, 0.6, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_overlay.add_theme_stylebox_override("panel", style)
	_overlay.position = Vector2(1500, 600)
	_overlay.custom_minimum_size = Vector2(400, 0)
	layer.add_child(_overlay)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_overlay.add_child(column)
	var toggler: Toggler = Toggler.new()
	toggler.target = _overlay
	root.add_child(toggler)
	var heading: Label = Label.new()
	heading.text = "PROTOTYPE colors  (Tab hides, drag the title)"
	heading.add_theme_font_size_override("font_size", 15)
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.gui_input.connect(_drag_overlay)
	column.add_child(heading)
	_add_color_group(column, "maroon", "Maroon: panes (bench, borders, panels follow)")
	_add_color_group(column, "rose", "Rose: deck columns and Collection")
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var save: Button = Button.new()
	save.text = "Save pair"
	save.pressed.connect(_save_pair)
	row.add_child(save)
	var reset: Button = Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func() -> void: _set_colors(DeckbuilderLook.PANE, DeckbuilderLook.COLUMN))
	row.add_child(reset)
	_saved = HFlowContainer.new()
	column.add_child(_saved)


func _add_color_group(column: VBoxContainer, key: String, title: String) -> void:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	column.add_child(label)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(48, 28)
	top.add_child(swatch)
	_swatches[key] = swatch
	var hex: LineEdit = LineEdit.new()
	hex.custom_minimum_size = Vector2(110, 0)
	hex.text_submitted.connect(func(text: String) -> void: _on_hex(key, text))
	top.add_child(hex)
	_hex_boxes[key] = hex
	var sliders: Array[HSlider] = []
	for channel: String in ["R", "G", "B"]:
		var line: HBoxContainer = HBoxContainer.new()
		column.add_child(line)
		var name: Label = Label.new()
		name.text = channel
		name.custom_minimum_size = Vector2(16, 0)
		line.add_child(name)
		var slider: HSlider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 255
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 22)
		line.add_child(slider)
		var number: Label = Label.new()
		number.custom_minimum_size = Vector2(36, 0)
		line.add_child(number)
		slider.value_changed.connect(func(value: float) -> void:
			number.text = str(int(value))
			_on_slider(key))
		sliders.append(slider)
	_sliders[key] = sliders


func _on_slider(key: String) -> void:
	if _is_syncing:
		return
	var sliders: Array = _sliders[key]
	_colors[key] = Color8(int((sliders[0] as HSlider).value), int((sliders[1] as HSlider).value), int((sliders[2] as HSlider).value))
	_apply()


func _on_hex(key: String, text: String) -> void:
	if Color.html_is_valid(text):
		_colors[key] = Color.html(text)
		_apply()


func _set_colors(maroon: Color, rose: Color) -> void:
	_colors["maroon"] = maroon
	_colors["rose"] = rose
	_apply()


## Shows the colors on the sliders and recolors the deckbuilder.
func _apply() -> void:
	_is_syncing = true
	for key: String in _colors:
		var color: Color = _colors[key]
		var sliders: Array = _sliders[key]
		(sliders[0] as HSlider).value = color.r8
		(sliders[1] as HSlider).value = color.g8
		(sliders[2] as HSlider).value = color.b8
		_swatches[key].color = color
		_hex_boxes[key].text = "#" + color.to_html(false)
	_is_syncing = false
	var now: Array[Color] = []
	var chosen: Array[Color] = []
	for name: String in FAMILY:
		var color: Color = _look(name)
		now.append(color)
		chosen.append(_moved(color, DeckbuilderLook.PANE, _colors["maroon"]))
	now.append(DeckbuilderLook.COLUMN)
	chosen.append(_colors["rose"])
	var from_colors: PackedVector3Array = PackedVector3Array()
	var to_colors: PackedVector3Array = PackedVector3Array()
	for index: int in now.size():
		var old_shades: Array[Color] = _shades(now[index])
		var new_shades: Array[Color] = _shades(chosen[index])
		for shade: int in old_shades.size():
			from_colors.append(_rgb(old_shades[shade]))
			to_colors.append(_rgb(new_shades[shade]))
	from_colors.resize(MATCHES)
	to_colors.resize(MATCHES)
	_material.set_shader_parameter("count", mini(now.size() * _shades(Color.BLACK).size(), MATCHES))
	_material.set_shader_parameter("from_colors", from_colors)
	_material.set_shader_parameter("to_colors", to_colors)


## [param color] and every shade the deckbuilder draws of it, rounded to 8 bits as it is on
## screen: the bands of a Dither Shaded plate, from a little lighter to darker, and the
## darker edge DeckbuilderLook.shade() gives a flat panel.
static func _shades(color: Color) -> Array[Color]:
	var top: Color = color.lightened(0.06)
	var bottom: Color = color.darkened(0.3)
	var shades: Array[Color] = [color, color.darkened(0.45)]
	for band: int in DitherShading.BANDS:
		shades.append(top.lerp(bottom, float(band) / float(DitherShading.BANDS - 1)))
	var rounded: Array[Color] = []
	for shade: Color in shades:
		rounded.append(Color8(roundi(shade.r * 255.0), roundi(shade.g * 255.0), roundi(shade.b * 255.0)))
	return rounded


## [param color] moved as [param from] is moved to [param to]: [param to]'s hue, with its
## saturation and value scaled as [param color]'s are to [param from]'s.
static func _moved(color: Color, from: Color, to: Color) -> Color:
	return Color.from_hsv(to.h, clampf(color.s * to.s / maxf(from.s, 0.001), 0.0, 1.0),
		clampf(color.v * to.v / maxf(from.v, 0.001), 0.0, 1.0))

func _save_pair() -> void:
	var maroon: Color = _colors["maroon"]
	var rose: Color = _colors["rose"]
	print("Saved: maroon #%s, rose #%s" % [maroon.to_html(false), rose.to_html(false)])
	for name: String in FAMILY:
		print("  %s #%s" % [name, _moved(_look(name), DeckbuilderLook.PANE, maroon).to_html(false)])
	var pair: Button = Button.new()
	pair.custom_minimum_size = Vector2(56, 28)
	pair.tooltip_text = "#%s / #%s" % [maroon.to_html(false), rose.to_html(false)]
	var halves: HBoxContainer = HBoxContainer.new()
	halves.add_theme_constant_override("separation", 0)
	halves.set_anchors_preset(Control.PRESET_FULL_RECT)
	halves.offset_left = 4
	halves.offset_top = 4
	halves.offset_right = -4
	halves.offset_bottom = -4
	halves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for color: Color in [maroon, rose]:
		var half: ColorRect = ColorRect.new()
		half.color = color
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halves.add_child(half)
	pair.add_child(halves)
	pair.pressed.connect(func() -> void: _set_colors(maroon, rose))
	_saved.add_child(pair)


func _drag_overlay(event: InputEvent) -> void:
	if event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_overlay.position += (event as InputEventMouseMotion).relative


## The color DeckbuilderLook names [param name].
static func _look(name: String) -> Color:
	return (DeckbuilderLook as Script).get_script_constant_map()[name] as Color


static func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)
