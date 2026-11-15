class_name RunWonNotice
extends Control
## The plain notice that the run is won (milestone 17), standing in until milestone 19's
## Run Won screen: it darkens the Stage Map under a small slate window in the Deckbox's
## style, with one button, Main Menu.

const SCRIM: Color = Color(0.03, 0.03, 0.05, 0.6)
const SLATE: Color = Color("#2a2f37")
const SLATE_BORDER: Color = Color("#14171c")
const TEXT: Color = Color8(228, 231, 238)
const MUTED: Color = Color8(154, 163, 181)
const WINDOW_SIZE: Vector2 = Vector2(560, 300)
const WINDOW_RADIUS: int = 16
const BUTTON_FILL: Color = Color("#4b4e55")
const BUTTON_HEIGHT: int = 52
## It eases in over this long at Fast.
const FADE_SECONDS: float = 0.3
const MAIN_MENU: String = "Main Menu"

## Who was beaten.
var boss_name: String = ""
## How long it takes to ease in; none in a test.
var fade_seconds: float = 0.0
## What Main Menu does.
var main_menu: Callable = func() -> void: pass

var _button: Button


## Fills the screen: set before it enters the tree, so its size follows its parent's.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var scrim: ColorRect = ColorRect.new()
	scrim.color = SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var window: PanelContainer = PanelContainer.new()
	var face: StyleBoxTexture = DitherShading.plate(SLATE.lightened(0.06), SLATE.darkened(0.3), SLATE_BORDER,
			WINDOW_RADIUS, 2, 0, int(WINDOW_SIZE.y))
	face.set_content_margin_all(32)
	window.add_theme_stylebox_override("panel", face)
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.size = WINDOW_SIZE
	window.position = (StageMapLayout.SCREEN - WINDOW_SIZE) / 2.0
	add_child(window)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	window.add_child(column)
	column.add_child(_text("Run won", 48, TEXT, true))
	column.add_child(_text("You beat %s." % boss_name, 24, MUTED, false))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	column.add_child(gap)
	_button = Button.new()
	_button.text = MAIN_MENU
	_button.custom_minimum_size = Vector2(220, BUTTON_HEIGHT)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_button.add_theme_font_override("font", UiText.bold())
	_button.add_theme_font_size_override("font_size", 24)
	_button.add_theme_stylebox_override("normal", DitherShading.button_plate(BUTTON_FILL, false, BUTTON_HEIGHT))
	_button.add_theme_stylebox_override("hover", DitherShading.button_plate(BUTTON_FILL.lightened(0.1), false, BUTTON_HEIGHT))
	_button.add_theme_stylebox_override("pressed", DitherShading.button_plate(BUTTON_FILL, true, BUTTON_HEIGHT))
	_button.add_theme_stylebox_override("hover_pressed", DitherShading.button_plate(BUTTON_FILL, true, BUTTON_HEIGHT))
	_button.pressed.connect(func() -> void: main_menu.call())
	column.add_child(_button)
	Easing.fade_in(self, fade_seconds)


func button() -> Button:
	return _button


func _text(text: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.text = text
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	return made
