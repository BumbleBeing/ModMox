class_name StageIntro
extends Control
## The Stage Intro (game glossary; milestone 17, signed off as prototypes/stage_map_screen),
## in its plain form: the Stage's name, its Tier in words, and its Boss, breathing in the
## Boss's disc with its name under it. Continue opens the Stage Map. Later (milestone 19):
## the Tier graphic.
##
## Opened on its own (godot --path . res://ui/stage_map/stage_intro.tscn) it begins a debug
## run from the command line as the Stage Map does; --screenshot=/absolute/path.png saves a
## picture and quits.

const GROUND: Color = Color8(42, 44, 56)
const TEXT: Color = Color8(228, 231, 238)
const MUTED: Color = Color8(154, 163, 181)
## The Boss's disc and its ring.
const RING_RADIUS: float = 104.0
const RING_WIDTH: float = 10.0
const BUTTON_FILL: Color = Color("#4b4e55")
const BUTTON_HEIGHT: int = 56
const CONTINUE: String = "Continue"

## Whether the screen reads the run from RunFlow when it is ready. Tests hand it one.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)

var _run: Run = null
var _ring: Control
var _texts: Array[Label] = []
var _button: Button
var _time: float = 0.0


func _ready() -> void:
	if not starts_itself:
		return
	if RunFlow.run == null:
		RunFlow.start(StageMapScreen.debug_run_from(OS.get_cmdline_user_args()))
	begin(RunFlow.run)
	var picture: String = EncounterScreen.screenshot_path(OS.get_cmdline_user_args())
	if picture != "":
		set_process(false)
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Shows [param run]'s Stage and its Boss.
func begin(run: Run) -> void:
	_run = run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var visit: StageVisit = run.stage_visit
	var centered: CenterContainer = CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centered)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	centered.add_child(column)
	column.add_child(_text(visit.stage.name, 64, TEXT, true))
	column.add_child(_text("Tier %d" % visit.stage.tier, 30, MUTED, false))
	column.add_child(_gap())
	column.add_child(_text("Boss", 24, MUTED, false))
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2.ONE * (RING_RADIUS * 2.0 + 40.0)
	_ring.draw.connect(func() -> void:
		BossDisc.draw(_ring, _ring.size / 2.0, RING_RADIUS, RING_WIDTH, visit.boss.sprite, _time, Color.WHITE))
	column.add_child(_ring)
	column.add_child(_text(visit.boss.name, 36, TEXT, true))
	column.add_child(_gap())
	_button = Button.new()
	_button.text = CONTINUE
	_button.custom_minimum_size = Vector2(220, BUTTON_HEIGHT)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_button.add_theme_font_override("font", UiText.bold())
	_button.add_theme_font_size_override("font_size", 26)
	_button.add_theme_stylebox_override("normal", DitherShading.button_plate(BUTTON_FILL, false, BUTTON_HEIGHT))
	_button.add_theme_stylebox_override("hover", DitherShading.button_plate(BUTTON_FILL.lightened(0.1), false, BUTTON_HEIGHT))
	_button.add_theme_stylebox_override("pressed", DitherShading.button_plate(BUTTON_FILL, true, BUTTON_HEIGHT))
	_button.add_theme_stylebox_override("hover_pressed", DitherShading.button_plate(BUTTON_FILL, true, BUTTON_HEIGHT))
	_button.pressed.connect(func() -> void: navigate.call(RunFlow.finish_intro()))
	column.add_child(_button)


## Everything the Intro says, top to bottom.
func texts() -> Array[String]:
	var said: Array[String] = []
	for label: Label in _texts:
		said.append(label.text)
	return said


func button() -> Button:
	return _button


func _process(delta: float) -> void:
	_time += delta
	if _ring != null:
		_ring.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)


func _gap() -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	return gap


func _text(text: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	_texts.append(made)
	return made
