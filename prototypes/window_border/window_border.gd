extends Node
## PROTOTYPE: throwaway. Four variants of a new border for the main menu's window: a rim of
## three bands, dark outside and in with a mid-tone between, for a more solid frame. They
## are switched on the real main menu with the arrow keys or the bar's arrows, or picked with
## --variant= on the command line. "Before" is the window as it is, for comparison.
##
## Nothing in ui/ is touched: this opens the real main menu and repaints its window's style
## each time the window is resized, after the menu's own shade_window(). The face inside the
## rim is the menu's own Dither Shading on the same grid, so the Soldier Shadow still lands
## on its blocks, and the room between the rim and the buttons is kept: the margin grows by
## what the rim adds past today's 2 px edge. Nothing here is ported as it is; the variant the
## user picks is rebuilt test-first.
##
## Run: godot --path . res://prototypes/window_border/window_border.tscn [-- --variant=B]
## Keys: left and right arrows cycle the variants.
## Pictures: -- --shots=/absolute/folder saves every variant, whole and both its top-left
##   and bottom-right corners four times over, with the menu held still, and quits.

const MAIN_MENU: String = "res://ui/menu/main_menu.tscn"
## Where the face's dither grid starts, as the menu's own window has it.
const GRID_LEFT: int = SpoilsScreen.WINDOW_RADIUS + MainMenu.WINDOW_EDGE_WIDTH
const BAR_FILL: Color = Color("#3a2a10")
const BAR_INK: Color = Color("#f1dc9a")
const ZOOM: int = 4
const CROP: Vector2i = Vector2i(64, 48)

var _variants: Array[Dictionary] = []
var _index: int = 0
var _menu: MainMenu = null
var _bar: PanelContainer
var _label: Label
var _shots: String = ""
## The variant and size last painted, and whether a repaint waits for the end of the frame.
var _painted: String = ""
var _is_queued: bool = false


func _ready() -> void:
	_variants = _make_variants()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			var key: String = argument.trim_prefix("--variant=").to_lower()
			for i: int in _variants.size():
				if (_variants[i]["key"] as String).to_lower() == key:
					_index = i
		elif argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
	if _shots != "":
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_build_bar()
	_show_state()
	# This node outlives the scene it opens: it moves to the root, then opens the menu.
	_open_menu.call_deferred()


func _open_menu() -> void:
	var tree: SceneTree = get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.change_scene_to_file(MAIN_MENU)


func _process(_delta: float) -> void:
	var menu: MainMenu = get_tree().current_scene as MainMenu
	if menu == null or menu.window() == null or (is_instance_valid(_menu) and menu == _menu):
		return
	_menu = menu
	_painted = ""
	var window: PanelContainer = menu.window()
	# The menu's own repaint is taken off: the two fought, each margin resizing the window
	# for the other, until the stack overflowed. Before calls it from here instead. The
	# repaint waits for the end of the frame, so a resize it causes comes back once, settled.
	for connection: Dictionary in window.resized.get_connections():
		window.resized.disconnect(connection["callable"])
	window.resized.connect(func() -> void: _queue_paint())
	_paint(window)
	if _shots != "":
		_take_shots()


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_LEFT or key.keycode == KEY_RIGHT:
		_step(-1 if key.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()


func _step(by: int) -> void:
	_index = posmod(_index + by, _variants.size())
	_show_state()
	if is_instance_valid(_menu) and _menu.window() != null:
		_paint(_menu.window())


# Variants -----------------------------------------------------------------------------------

## Each rim is its bands' widths from the outside in, the block its corners are drawn in, the
## corners' shape and each band's color; "shade" Dither-Shades the mid band top to bottom.
func _make_variants() -> Array[Dictionary]:
	var dark: Color = SpoilsScreen.WINDOW_EDGE
	var warm: Color = SpoilsScreen.WINDOW_COLOR.lightened(0.22)
	var steel: Color = SteelFrame.STEEL.darkened(0.35)
	var made: Array[Dictionary] = [
		{"key": "Before", "name": "As it is", "note": "a 2 px dark edge, round corners"},
		{"key": "A", "name": "Thin rim", "note": "1 + 1 + 1 px: dark, warm mid-tone, dark. Round corners, as asked",
			"widths": [1, 1, 1], "block": 1, "corner": "round", "colors": [dark, warm, dark]},
		{"key": "B", "name": "Block rim", "note": "3 + 3 + 3 px, each band one dither block. Round corners stepped in 3 px blocks",
			"widths": [3, 3, 3], "block": 3, "corner": "round", "colors": [dark, warm, dark]},
		{"key": "C", "name": "Steel rim", "note": "3 + 3 + 3 px, dark steel mid-tone, the buttons' stepped corners",
			"widths": [3, 3, 3], "block": 3, "corner": "stepped", "colors": [dark, steel, dark]},
		{"key": "D", "name": "Shaded rim", "note": "as B, the mid band Dither-Shaded light at the top to dark at the bottom",
			"widths": [3, 3, 3], "block": 3, "corner": "round", "colors": [dark, warm, dark],
			"shade": [SpoilsScreen.WINDOW_COLOR.lightened(0.38), SpoilsScreen.WINDOW_COLOR.darkened(0.05)]},
	]
	return made


# Painting -----------------------------------------------------------------------------------

func _queue_paint() -> void:
	if _is_queued:
		return
	_is_queued = true
	(func() -> void:
		_is_queued = false
		if is_instance_valid(_menu) and _menu.window() != null:
			_paint(_menu.window())).call_deferred()


func _paint(window: PanelContainer) -> void:
	var variant: Dictionary = _variants[_index]
	var width: int = int(window.size.x)
	var height: int = int(window.size.y)
	# The same variant at the same size is already painted.
	var key: String = "%s/%d/%d" % [variant["key"], width, height]
	if key == _painted or width < 1 or height < 1:
		return
	_painted = key
	if not variant.has("widths"):
		MainMenu.shade_window(window)
		return
	var widths: Array = variant["widths"]
	var rim: int = 0
	var depths: Array[int] = [0]
	for band: int in widths:
		rim += band
		depths.append(rim)
	# Past this far from both a side and an end, a pixel is in no corner.
	var reach: int = SpoilsScreen.WINDOW_RADIUS + rim + 3
	var top: Color = SpoilsScreen.WINDOW_COLOR.lightened(0.06)
	var bottom: Color = SpoilsScreen.WINDOW_COLOR.darkened(0.3)
	var colors: Array = variant["colors"]
	var shade: Array = variant.get("shade", [])
	var started: int = Time.get_ticks_msec()
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		var dy: int = mini(y, height - 1 - y)
		for x: int in width:
			var dx: int = mini(x, width - 1 - x)
			var band: int = widths.size()
			if (dx < reach and dy < reach) or dx < rim or dy < rim:
				band = _band(dx, dy, depths, variant)
			var pixel: Color = Color(0, 0, 0, 0)
			if band == widths.size():
				pixel = DitherShading.band_color(x - GRID_LEFT, y, height, top, bottom)
			elif band == 1 and not shade.is_empty():
				pixel = DitherShading.band_color(x - GRID_LEFT, y, height, shade[0], shade[1])
			elif band >= 0:
				pixel = colors[band]
			image.set_pixel(x, y, pixel)
	var face: StyleBoxTexture = StyleBoxTexture.new()
	face.texture = ImageTexture.create_from_image(image)
	face.set_content_margin_all(SpoilsScreen.WINDOW_MARGIN + rim - MainMenu.WINDOW_EDGE_WIDTH)
	window.add_theme_stylebox_override("panel", face)
	print("painted %d x %d in %d ms" % [width, height, Time.get_ticks_msec() - started])


## Which band the pixel [param dx] from the nearest side and [param dy] from the nearest end
## is in: -1 outside the window, the face past the last.
func _band(dx: int, dy: int, depths: Array[int], variant: Dictionary) -> int:
	var band: int = -1
	for depth: int in depths:
		if not _is_inside(dx, dy, depth, variant):
			break
		band += 1
	return band


func _is_inside(dx: int, dy: int, depth: int, variant: Dictionary) -> bool:
	var block: int = variant["block"]
	if variant["corner"] == "stepped":
		var from_side: int = dx - depth
		var from_end: int = dy - depth
		@warning_ignore("integer_division")
		return from_side >= 0 and from_end >= 0 and from_side / block + from_end / block >= 4
	# Round, measured block by block: a block takes one band whole.
	@warning_ignore("integer_division")
	var point: Vector2 = Vector2(dx / block + 0.5, dy / block + 0.5)
	var radius: float = float(SpoilsScreen.WINDOW_RADIUS) / block
	var inside: float = minf(point.x, point.y)
	if point.x < radius and point.y < radius:
		inside = radius - point.distance_to(Vector2(radius, radius))
	return floorf(inside) * block >= depth


# The bar ------------------------------------------------------------------------------------

func _build_bar() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_bar = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BAR_FILL
	style.border_color = BAR_INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	_bar.add_theme_stylebox_override("panel", style)
	layer.add_child(_bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_bar.add_child(row)
	row.add_child(_arrow("<", -1))
	_label = Label.new()
	_label.custom_minimum_size = Vector2(820, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", BAR_INK)
	row.add_child(_label)
	row.add_child(_arrow(">", 1))
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _arrow(text: String, by: int) -> Button:
	var made: Button = Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	made.custom_minimum_size = Vector2(44, 44)
	made.add_theme_font_size_override("font_size", 22)
	made.pressed.connect(func() -> void: _step(by))
	return made


func _show_state() -> void:
	var variant: Dictionary = _variants[_index]
	_label.text = "PROTOTYPE   %s. %s   (%d of %d, arrow keys)\n%s" % [variant["key"], variant["name"], _index + 1,
		_variants.size(), variant["note"]]
	print("window border variant: %s. %s: %s" % [variant["key"], variant["name"], variant["note"]])


# Pictures -----------------------------------------------------------------------------------

func _take_shots() -> void:
	_bar.visible = false
	await get_tree().create_timer(1.5).timeout
	# Held still, so every variant is pictured with the soldier and the Wisp where they were.
	_menu.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(_shots)
	for i: int in _variants.size():
		_index = i
		_show_state()
		_paint(_menu.window())
		for frame: int in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var file: String = (_variants[i]["key"] as String).to_lower()
		image.save_png(_shots.path_join(file + ".png"))
		var rect: Rect2 = _menu.window().get_global_rect()
		_save_crop(image, Rect2i(Vector2i(rect.position) - Vector2i(8, 8), CROP), file + "_top_left.png")
		_save_crop(image, Rect2i(Vector2i(rect.end) - CROP + Vector2i(8, 8), CROP), file + "_bottom_right.png")
	get_tree().quit()


func _save_crop(image: Image, region: Rect2i, file: String) -> void:
	var crop: Image = image.get_region(region)
	crop.resize(region.size.x * ZOOM, region.size.y * ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(_shots.path_join(file))
