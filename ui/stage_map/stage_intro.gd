class_name StageIntro
extends Control
## The Stage Intro (game glossary; milestone 17, signed off as prototypes/stage_map_screen),
## in its plain form: the Stage's name, its Tier in words, and its Boss, breathing in the
## Boss's disc with its name under it, on a ground of the Stage's own color shaded with
## Dither Shading, or the slate for a Stage without one (ADR 0038). Continue opens the Stage Map. Later (milestone 19):
## the Tier graphic.
##
## Opened on its own (godot --path . res://ui/stage_map/stage_intro.tscn) it begins a debug
## run from the command line as the Stage Map does; --screenshot=/absolute/path.png saves a
## picture and quits.

const GROUND: Color = Color8(42, 44, 56)
const TEXT: Color = Color8(228, 231, 238)
const MUTED: Color = Color8(154, 163, 181)
## The text on a light ground, which the pale TEXT would vanish on.
const INK: Color = Color8(46, 40, 36)
const INK_MUTED: Color = Color8(108, 96, 84)
## How far a Stage's color is lightened at the top of the ground and darkened at its foot.
const GROUND_LIGHTEN: float = 0.08
const GROUND_DARKEN: float = 0.18
## The Boss's disc and its ring.
const RING_RADIUS: float = 104.0
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
	if visit.stage.has_intro_color():
		var shaded: Panel = Panel.new()
		shaded.set_anchors_preset(Control.PRESET_FULL_RECT)
		shaded.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shaded.add_theme_stylebox_override("panel", DitherShading.plate(ground().lightened(GROUND_LIGHTEN),
				ground().darkened(GROUND_DARKEN), ground(), 0, 0, 0, int(StageMapLayout.SCREEN.y)))
		add_child(shaded)
	var text: Color = INK if _is_light() else TEXT
	var muted: Color = INK_MUTED if _is_light() else MUTED
	var centered: CenterContainer = CenterContainer.new()
	centered.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centered)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	centered.add_child(column)
	column.add_child(_text(visit.stage.name, 64, text, true))
	column.add_child(_text("Tier %d" % visit.stage.tier, 30, muted, false))
	column.add_child(_gap())
	column.add_child(_text("Boss", 24, muted, false))
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2.ONE * (RING_RADIUS * 2.0 + 40.0)
	_ring.draw.connect(func() -> void:
		BossDisc.draw(_ring, _ring.size / 2.0, RING_RADIUS, visit.boss.sprite, _time, Color.WHITE))
	column.add_child(_ring)
	column.add_child(_text(visit.boss.name, 36, text, true))
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
	_button.pressed.connect(func() -> void: navigate.call(Screens.scene(RunFlow.finish_intro())))
	column.add_child(_button)


## Everything the Intro says, top to bottom.
func texts() -> Array[String]:
	var said: Array[String] = []
	for label: Label in _texts:
		said.append(label.text)
	return said


## The color the ground is shaded in: the Stage's own, or the slate.
func ground() -> Color:
	return ground_of(_run.stage_visit.stage)


## The color the ground of [param stage]'s Stage Intro is shaded in, which the Spoils
## screen shares: the Stage's own, or the slate.
static func ground_of(stage: StageDefinition) -> Color:
	return stage.intro_color if stage.has_intro_color() else GROUND


## The ground [param stage]'s Stage Intro is drawn on, filling its parent: the Stage's color
## shaded with Dither Shading over the screen's height, or the flat slate.
static func ground_panel(stage: StageDefinition) -> Panel:
	var made: Panel = Panel.new()
	made.set_anchors_preset(Control.PRESET_FULL_RECT)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = ground_of(stage)
	if stage.has_intro_color():
		made.add_theme_stylebox_override("panel", DitherShading.plate(color.lightened(GROUND_LIGHTEN),
				color.darkened(GROUND_DARKEN), color, 0, 0, 0, int(StageMapLayout.SCREEN.y)))
	else:
		var flat: StyleBoxFlat = StyleBoxFlat.new()
		flat.bg_color = color
		made.add_theme_stylebox_override("panel", flat)
	return made


## The color the Stage's name is written in.
func text_color() -> Color:
	return INK if _is_light() else TEXT


func button() -> Button:
	return _button


func _process(delta: float) -> void:
	_time += delta
	if _ring != null:
		_ring.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)


func _is_light() -> bool:
	return ground().get_luminance() > 0.5


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
