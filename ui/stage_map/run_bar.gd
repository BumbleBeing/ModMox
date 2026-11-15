class_name RunBar
extends PanelContainer
## The Run Bar (game glossary) across the top of the Stage Map (milestone 17, signed off as
## prototypes/stage_map_screen): the Stage's name and Tier at the left, then the Hearts left
## and the gold held, then the Satchel button, which does nothing yet, and the Deckbox
## button. A slate plate with Dither Shading, as the Deckbox's window is.

signal deckbox_pressed

const HEIGHT: int = 96
const SLATE: Color = Color("#2a2f37")
const SLATE_BORDER: Color = Color("#14171c")
const TEXT: Color = Color8(228, 231, 238)
const MUTED: Color = Color8(154, 163, 181)
const ICONS: String = "res://ui/sprites/run_bar/%s.png"
## The 16 × 16 icons are drawn at twice their size.
const ICON_SCALE: int = 2
const BUTTON_FILL: Color = Color("#4b4e55")
const BUTTON_HEIGHT: int = 48
## A button is as wide as its name and icon, with this much room at each side.
const BUTTON_SIDE: int = 18
const HOVER_LIGHTEN: float = 0.10
const SATCHEL: String = "Satchel"
const DECKBOX: String = "Deckbox"

var _stage_name: Label
var _tier: Label
var _hearts: HBoxContainer
var _gold: Label
var _buttons: Dictionary[String, Button] = {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, HEIGHT)
	var face: StyleBoxTexture = DitherShading.plate(SLATE.lightened(0.06), SLATE.darkened(0.3), SLATE_BORDER,
			0, 2, 0, HEIGHT)
	face.content_margin_left = 32
	face.content_margin_right = 32
	add_theme_stylebox_override("panel", face)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	add_child(row)

	var naming: VBoxContainer = VBoxContainer.new()
	naming.alignment = BoxContainer.ALIGNMENT_CENTER
	naming.add_theme_constant_override("separation", -4)
	row.add_child(naming)
	_stage_name = _text(30, TEXT, true)
	naming.add_child(_stage_name)
	_tier = _text(20, MUTED, false)
	naming.add_child(_tier)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 8)
	_hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_hearts)

	var gold: HBoxContainer = HBoxContainer.new()
	gold.add_theme_constant_override("separation", 10)
	gold.add_child(_icon("gold_coin"))
	_gold = _text(28, TEXT, true)
	_gold.custom_minimum_size = Vector2(72, 0)
	gold.add_child(_gold)
	row.add_child(gold)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	# Later (milestone 22): the Satchel opens.
	_add_button(buttons, SATCHEL, "satchel", func() -> void: pass)
	_add_button(buttons, DECKBOX, "deckbox", deckbox_pressed.emit)
	row.add_child(buttons)


## Shows [param run]: its Stage and Tier, its Hearts, full and empty, and its gold.
func show_run(run: Run) -> void:
	_stage_name.text = run.stage_visit.stage.name
	_tier.text = "Tier %d" % run.stage_visit.stage.tier
	for child: Node in _hearts.get_children():
		_hearts.remove_child(child)
		child.queue_free()
	for index: int in Run.STARTING_HEARTS:
		_hearts.add_child(_icon("heart_full" if index < run.hearts else "heart_empty"))
	_gold.text = str(run.gold)


func stage_text() -> String:
	return _stage_name.text


func tier_text() -> String:
	return _tier.text


func gold_text() -> String:
	return _gold.text


## Whether each Heart is drawn full, left to right.
func hearts_shown() -> Array[bool]:
	var shown: Array[bool] = []
	for heart: Node in _hearts.get_children():
		shown.append((heart as TextureRect).texture.resource_path.ends_with("heart_full.png"))
	return shown


func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func _icon(icon_name: String) -> TextureRect:
	var made: TextureRect = TextureRect.new()
	made.texture = load(ICONS % icon_name) as Texture2D
	made.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	made.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	made.custom_minimum_size = made.texture.get_size() * ICON_SCALE
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


func _text(font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return made


## A button with its name in bold and its 16 × 16 icon, drawn at twice its size, to the
## right.
func _add_button(parent: Control, text: String, icon_name: String, on_press: Callable) -> void:
	var made: Button = Button.new()
	made.text = text
	made.icon = _scaled(icon_name)
	made.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	made.add_theme_font_override("font", UiText.bold())
	made.add_theme_constant_override("h_separation", 10)
	made.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	made.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.add_theme_font_size_override("font_size", 22)
	made.add_theme_stylebox_override("normal", _plate(BUTTON_FILL, false))
	made.add_theme_stylebox_override("hover", _plate(BUTTON_FILL.lightened(HOVER_LIGHTEN), false))
	made.add_theme_stylebox_override("pressed", _plate(BUTTON_FILL, true))
	made.add_theme_stylebox_override("hover_pressed", _plate(BUTTON_FILL, true))
	made.pressed.connect(on_press)
	parent.add_child(made)
	_buttons[text] = made


func _plate(fill: Color, is_pressed: bool) -> StyleBoxTexture:
	var made: StyleBoxTexture = DitherShading.button_plate(fill, is_pressed, BUTTON_HEIGHT)
	made.content_margin_left = BUTTON_SIDE
	made.content_margin_right = BUTTON_SIDE
	return made


## The icon called [param icon_name] at twice its size with hard edges, for a Button, which
## draws its icon at the texture's own size. Never changes the loaded image.
static func _scaled(icon_name: String) -> Texture2D:
	var image: Image = (load(ICONS % icon_name) as Texture2D).get_image().duplicate() as Image
	image.resize(image.get_width() * ICON_SCALE, image.get_height() * ICON_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
