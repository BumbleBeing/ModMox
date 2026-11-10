extends Control
## Developer tool: every card in content/cards/ as a Card Face beside its Battlefield Face.
## Drag a card's art to move its focus point (A233); letting go saves it to
## content/art/art.json. The wheel over either face scrolls rules text that overflows.
##
## Run: godot --path . res://tools/card_gallery/card_gallery.tscn
## Screenshot and quit: add `-- --screenshot=/absolute/path.png` (and --tapped).

const CARDS: String = "res://content/cards/"

var _face_height: float = 300.0
var _field_height: float = 140.0
var _is_tapped: bool = false
var _flow: HFlowContainer
var _definitions: Array[MmCardDefinition] = []


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_is_tapped = arguments.has("--tapped")
	for path: String in _card_files(CARDS):
		_definitions.append(load(path) as MmCardDefinition)
	_build_controls()
	_rebuild()
	for argument: String in arguments:
		if argument.begins_with("--screenshot="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
			get_tree().quit()


func _build_controls() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1a1d22")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var bar: HFlowContainer = HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 18)
	column.add_child(bar)
	bar.add_child(_slider("Card Face height", 150.0, 700.0, _face_height,
			func(value: float) -> void: _face_height = value))
	bar.add_child(_slider("Battlefield Face height", 70.0, 260.0, _field_height,
			func(value: float) -> void: _field_height = value))
	var tapped: CheckBox = CheckBox.new()
	tapped.text = "Tapped"
	tapped.button_pressed = _is_tapped
	tapped.toggled.connect(func(on: bool) -> void:
		_is_tapped = on
		_rebuild())
	bar.add_child(tapped)
	var hint: Label = Label.new()
	hint.text = "Drag a card's art to set its focus point."
	hint.modulate = Color(1, 1, 1, 0.6)
	bar.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 22)
	_flow.add_theme_constant_override("v_separation", 22)
	margin.add_child(_flow)


func _slider(text: String, lowest: float, highest: float, value: float, on_change: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = lowest
	slider.max_value = highest
	slider.step = 10.0
	slider.value = value
	slider.custom_minimum_size = Vector2(140, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var readout: Label = Label.new()
	readout.text = "%d" % int(value)
	row.add_child(readout)
	slider.value_changed.connect(func(changed: float) -> void: readout.text = "%d" % int(changed))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		on_change.call(slider.value)
		_rebuild())
	return row


func _rebuild() -> void:
	for child: Node in _flow.get_children():
		child.queue_free()
	for definition: MmCardDefinition in _definitions:
		_flow.add_child(_cell(definition))


func _cell(definition: MmCardDefinition) -> HBoxContainer:
	var cell: HBoxContainer = HBoxContainer.new()
	cell.add_theme_constant_override("separation", 10)
	var look: CardLook = CardLook.of_definition(definition)
	var card: CardFace = CardFace.new()
	card.setup(look, _face_height)
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	card.gui_input.connect(func(event: InputEvent) -> void:
		_drag_focus(event, look.art_key, CardGeometry.on_card(CardGeometry.ART, card.size).size))
	cell.add_child(card)
	if look.is_permanent():
		var field_look: CardLook = CardLook.of_definition(definition)
		field_look.is_tapped = _is_tapped
		var field: BattlefieldFace = BattlefieldFace.new()
		field.setup(field_look, _field_height)
		field.size_flags_vertical = Control.SIZE_SHRINK_END
		field.rules_scroll_requested.connect(card.scroll_rules)
		field.gui_input.connect(func(event: InputEvent) -> void:
			_drag_focus(event, look.art_key, BattlefieldFace.art_box(_field_height).size))
		cell.add_child(field)
	return cell


## Dragging the art right shows more of its left side, so the focus moves left.
func _drag_focus(event: InputEvent, key: String, box_size: Vector2) -> void:
	var library: ArtLibrary = ArtLibrary.shared()
	var art: Texture2D = library.texture(key)
	if art == null:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var shown: Vector2 = ArtLibrary.crop(art.get_size(), box_size, library.focus(key)).size
		var moved: Vector2 = library.focus(key) - motion.relative / box_size * shown
		library.set_focus(key, moved.clamp(shown / 2.0, Vector2.ONE - shown / 2.0))
		_rebuild_card(key)
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		library.save()


func _rebuild_card(key: String) -> void:
	for index: int in _definitions.size():
		if _definitions[index].resource_path.get_file().get_basename() == key:
			var old: Node = _flow.get_child(index)
			var fresh: HBoxContainer = _cell(_definitions[index])
			_flow.add_child(fresh)
			_flow.move_child(fresh, index)
			old.queue_free()
			return


static func _card_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_card_files(folder + sub + "/"))
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			found.append(folder + file)
	return found
