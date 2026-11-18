extends Control
## Developer tool: one Portrait breathing as it does on a player's panel, at its real size in
## its frame with a life total in its corner, to find each character's Breath Rate and
## Breath Intensity (game glossary). Pick a Portrait (Urza, Academy Headmaster first), move
## the sliders, and Save writes the Portrait's two values to BreathValues.PATH, which the
## encounter reads. It blinks now and then, as on a panel. Life shows the breathing speed up
## at low life; Hurt takes that much life and shows the Pain Portrait for as long as an
## encounter would at Normal speed, Winded; Lose stops it.
##
## Run: godot --path . res://tools/breath_lab/breath_lab.tscn
## Escape goes back to the main menu.
## Screenshot and quit: add `-- --screenshot=/absolute/path.png`.

const PORTRAITS: String = "res://ui/sprites/portraits/"
const FIRST: String = "urza_academy_headmaster"
const STARTING_LIFE: int = 20
## Six screen pixels to each of the Portrait's, as on a player's panel.
const SCALE: int = 6

var _keys: Array[String] = []
var _key: String = FIRST
var _values: BreathValues = BreathValues.load_from()
var _breath: Breath = Breath.new()
var _blink: Blink = Blink.new(1, 0)
var _life: int = STARTING_LIFE
var _pain_left: float = 0.0
var _hurt_by: int = 3
var _stage: Control = null
var _portrait: BreathingPortrait = null
var _life_label: Label = null
var _rate: HSlider = null
var _intensity: HSlider = null
var _life_slider: HSlider = null
var _saved: Label = null


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_keys = _portrait_keys()
	_build_controls()
	_pick(_keys.find(FIRST) if _keys.has(FIRST) else 0)
	for argument: String in arguments:
		if argument.begins_with("--screenshot="):
			for frame: int in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--screenshot="))
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		SceneFade.change_scene(get_tree(), "res://ui/menu/main_menu.tscn")


func _process(delta: float) -> void:
	var breathed: float = delta
	if _pain_left > 0.0 and _pain_left < INF:
		var pain_was: float = _pain_left
		_pain_left = maxf(_pain_left - delta, 0.0)
		if _pain_left == 0.0:
			_breath.catch_breath()
			_show_texture()
			breathed = delta - pain_was
	_breath.advance(breathed, _life, STARTING_LIFE)
	var was_shut: bool = _blink.is_shut()
	_blink.advance(delta)
	if _portrait != null:
		_portrait.show_growth(_breath.growth())
		if _blink.is_shut() != was_shut:
			_show_texture()


## Every Portrait with a picture of its own, Urza first, by file name.
func _portrait_keys() -> Array[String]:
	var keys: Array[String] = []
	for file: String in DirAccess.get_files_at(PORTRAITS):
		if file.ends_with(".png") and not file.ends_with("_pain.png") and not file.ends_with("_blink.png"):
			keys.append(file.get_basename())
	keys.sort()
	if keys.has(FIRST):
		keys.erase(FIRST)
		keys.push_front(FIRST)
	return keys


func _build_controls() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1a1d22")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(460, 0)
	column.add_theme_constant_override("separation", 14)
	row.add_child(column)
	column.add_child(_title("Breath lab"))

	var picker: OptionButton = OptionButton.new()
	for key: String in _keys:
		picker.add_item(key.capitalize())
	picker.item_selected.connect(_pick)
	picker.selected = maxi(_keys.find(FIRST), 0)
	column.add_child(_labeled("Portrait", picker))

	_rate = _slider(0.25, 3.0, 0.05, func(value: float) -> void: _breath.rate = value)
	column.add_child(_labeled("Breath Rate", _with_readout(_rate)))
	_intensity = _slider(0.0, 4.0, 0.05, func(value: float) -> void: _breath.intensity = value)
	column.add_child(_labeled("Breath Intensity", _with_readout(_intensity)))
	_life_slider = _slider(1.0, STARTING_LIFE, 1.0, func(value: float) -> void:
		_life = int(value)
		_show_life())
	_life_slider.value = _life
	column.add_child(_labeled("Life (of %d)" % STARTING_LIFE, _with_readout(_life_slider)))

	var hurt_row: HBoxContainer = HBoxContainer.new()
	var amount: SpinBox = SpinBox.new()
	amount.min_value = 1
	amount.max_value = STARTING_LIFE
	amount.value = _hurt_by
	amount.value_changed.connect(func(value: float) -> void: _hurt_by = int(value))
	hurt_row.add_child(amount)
	hurt_row.add_child(_button("Hurt", _hurt))
	hurt_row.add_child(_button("Lose", _lose))
	hurt_row.add_child(_button("Reset", _reset))
	column.add_child(_labeled("Life lost", hurt_row))

	var save_row: HBoxContainer = HBoxContainer.new()
	save_row.add_child(_button("Save this Portrait's values", _save))
	_saved = Label.new()
	_saved.modulate = Color(0.6, 0.9, 0.6)
	save_row.add_child(_saved)
	column.add_child(save_row)
	var help: Label = Label.new()
	help.text = "Saved to %s.\nA Portrait not saved breathes at 1 and 1.\nEscape: main menu." % BreathValues.PATH
	help.modulate = Color(0.7, 0.7, 0.75)
	column.add_child(help)

	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_stage)


## The Portrait chosen in the list at [param index]: its saved values, a fresh breath.
func _pick(index: int) -> void:
	_key = _keys[index]
	_rate.value = _values.rate_of(_key)
	_intensity.value = _values.intensity_of(_key)
	_saved.text = ""
	_reset()


func _reset() -> void:
	_breath = Breath.new(_rate.value, _intensity.value)
	_blink = Blink.new(randi(), 0)
	_life = STARTING_LIFE
	_set_quietly(_life_slider, _life)
	_pain_left = 0.0
	_build_stage()


func _hurt() -> void:
	_life = maxi(_life - _hurt_by, 1)
	_set_quietly(_life_slider, _life)
	_pain_left = maxf(_pain_left, PainHold.seconds(_hurt_by, GameSpeed.Speed.NORMAL))
	_breath.wind()
	_show_texture()
	_show_life()


func _lose() -> void:
	_life = 0
	_set_quietly(_life_slider, 1)
	_pain_left = INF
	_breath.stop()
	_show_texture()
	_show_life()


func _save() -> void:
	_values.set_values(_key, _rate.value, _intensity.value)
	_values.save_to()
	_saved.text = "Saved %s: rate %.2f, intensity %.2f" % [_key.capitalize(), _rate.value, _intensity.value]


## Draws the Portrait's frame as a player's panel draws it: a flat square, the picture, an
## edge, and the life total in its corner.
func _build_stage() -> void:
	for child: Node in _stage.get_children():
		child.queue_free()
	var box: Rect2 = Rect2(Vector2(0, 60), Vector2(32.0 * SCALE, 32.0 * SCALE))
	var back: Panel = CardShapes.rounded(box.size, 0, Inspector.palette().panel)
	back.position = box.position
	_stage.add_child(back)
	_portrait = BreathingPortrait.new(box)
	_stage.add_child(_portrait)
	var edge: Panel = CardShapes.outline(box.size, 0, 2, Inspector.palette().edge)
	edge.position = box.position
	_stage.add_child(edge)
	_life_label = Label.new()
	_life_label.add_theme_font_size_override("font_size", 42)
	_life_label.add_theme_constant_override("outline_size", 8)
	_life_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_life_label.position = box.end - Vector2(70, 60)
	_life_label.size = Vector2(64, 56)
	_life_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(_life_label)
	_show_texture()
	_show_life()


func _show_texture() -> void:
	var wincing: bool = _pain_left > 0.0
	var texture: Texture2D = load(PORTRAITS + _key + ".png")
	var pain_path: String = PORTRAITS + _key + "_pain.png"
	if wincing and ResourceLoader.exists(pain_path):
		texture = load(pain_path)
	elif not wincing and not _breath.is_stopped() and _blink.is_shut() and PlayerPanel.blink_of(texture) != null:
		texture = PlayerPanel.blink_of(texture)
	_portrait.set_texture(texture)


func _show_life() -> void:
	_life_label.text = str(_life)


func _title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	return label


func _labeled(text: String, control: Control) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	box.add_child(label)
	box.add_child(control)
	return box


## A slider whose number shows beside it.
func _slider(lowest: float, highest: float, step: float, on_change: Callable) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.min_value = lowest
	slider.max_value = highest
	slider.step = step
	slider.custom_minimum_size = Vector2(360, 24)
	slider.value_changed.connect(func(value: float) -> void:
		on_change.call(value)
		var readout: Label = slider.get_meta(&"readout") as Label
		readout.text = _number(slider, value))
	var readout: Label = Label.new()
	slider.set_meta(&"readout", readout)
	return slider


## [param slider] with its number beside it.
func _with_readout(slider: HSlider) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(slider)
	var readout: Label = slider.get_meta(&"readout") as Label
	readout.text = _number(slider, slider.value)
	row.add_child(readout)
	return row


## Moves [param slider] to [param value] without acting on it, its number shown.
func _set_quietly(slider: HSlider, value: float) -> void:
	slider.set_value_no_signal(value)
	(slider.get_meta(&"readout") as Label).text = _number(slider, value)


## [param value] as [param slider] counts: whole numbers for life.
func _number(slider: HSlider, value: float) -> String:
	return str(int(value)) if slider.step >= 1.0 else "%.2f" % value


func _button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(on_press)
	return button
