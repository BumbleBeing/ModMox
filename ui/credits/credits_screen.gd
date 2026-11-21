class_name CreditsScreen
extends Control
## The Credits (game glossary; milestone 19, signed off as step 3 of prototypes/run_ends),
## on the slate: the roll authored in content/credits/credits.txt (CreditsText), centered in
## a column, rising on its own from below the screen at PACE pixels a second, in real time
## and not at the Game Speed, and holding once "Thanks for playing" stands at the screen's
## middle; the mouse wheel does nothing to it. Main Menu stands at the top left and Art
## Attribution at the top right, of the same size, shape and look, over the roll.
##
## Art Attribution (ArtAttribution) is a page of the Credits on the same ground, scrolled by
## the mouse wheel alone with no scroll bar, and not rolling. Its button reads "Credits"
## while it is open, and returns to the roll from the top. Mouse only.
##
## Opened on its own (the main menu's --credits) --screenshot=/absolute/path.png saves a
## picture and quits, and --page=art shows Art Attribution.

const FLAG: String = "--credits"
const GROUND: Color = StageIntro.GROUND
const TEXT: Color = StageIntro.TEXT
const MUTED: Color = StageIntro.MUTED
const SCREEN: Vector2 = Vector2(1920, 1080)
## How fast the roll rises, in pixels a second at 1080p.
const PACE: float = 60.0
const COLUMN_WIDTH: float = 1200.0
const MARGIN: float = 32.0
const BUTTON_WIDTH: int = 260
const BUTTON_HEIGHT: int = 56
const SHADOW: Color = Color(0, 0, 0, 0.55)
const MAIN_MENU: String = "Main Menu"
const ART_ATTRIBUTION: String = "Art Attribution"
const CREDITS: String = "Credits"
## The line the roll holds on, once it stands at the screen's middle: the closing title.
const LAST_LINE: String = "Thanks for playing"

## Whether the screen starts itself when it is ready. Tests begin it themselves.
var starts_itself: bool = true
## How the screen opens another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: SceneFade.change_scene(get_tree(), scene)

## Whether the Credits have led to the main menu, so the menu's --credits does not open them
## again.
static var has_left: bool = false

var _roll_clip: Control
var _roll: VBoxContainer
var _roll_texts: Array[Label] = []
var _last: Label = null
var _seconds: float = 0.0
var _attribution: ScrollContainer
var _attribution_texts: Array[Label] = []
var _main_menu: Button
var _page: Button
var _is_attribution_open: bool = false


func _ready() -> void:
	if not starts_itself:
		return
	begin()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--page=art"):
		_toggle_page()
	var picture: String = EncounterScreen.screenshot_path(arguments)
	if picture != "":
		set_process(false)
		for frame: int in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(picture)
		get_tree().quit()


## Builds the roll, Art Attribution and the two buttons, the roll at its start.
func begin() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_roll()
	_build_attribution()
	var main_menu: Control = _button(MAIN_MENU, _leave)
	_main_menu = main_menu.get_child(0) as Button
	main_menu.position = Vector2(MARGIN, MARGIN)
	add_child(main_menu)
	var page: Control = _button(ART_ATTRIBUTION, _toggle_page)
	_page = page.get_child(0) as Button
	page.position = Vector2(SCREEN.x - MARGIN - BUTTON_WIDTH, MARGIN)
	add_child(page)
	_show_page()


## Where the roll's top stands now: PACE pixels a second above the screen's foot, held once
## "Thanks for playing" is at the screen's middle.
func roll_top() -> float:
	var risen: float = SCREEN.y - PACE * _seconds
	if _last == null:
		return risen
	return maxf(risen, SCREEN.y / 2.0 - (_last.position.y + _last.size.y / 2.0))


## Moves the roll on by [param seconds] of real time.
func advance(seconds: float) -> void:
	if not _is_attribution_open:
		_seconds += seconds
		_place_roll()


## Puts the roll back at its start, below the screen.
func restart_roll() -> void:
	_seconds = 0.0
	_place_roll()


## Every line the roll says, top to bottom.
func roll_texts() -> Array[String]:
	var said: Array[String] = []
	for label: Label in _roll_texts:
		said.append(label.text)
	return said


## The roll's line that says [param text], or null.
func roll_label(text: String) -> Label:
	for label: Label in _roll_texts:
		if label.text == text:
			return label
	return null


## Every line Art Attribution says, top to bottom.
func attribution_texts() -> Array[String]:
	var said: Array[String] = []
	for label: Label in _attribution_texts:
		said.append(label.text)
	return said


## How far Art Attribution is scrolled down, in pixels.
func attribution_scroll() -> int:
	return _attribution.scroll_vertical


func is_attribution_open() -> bool:
	return _is_attribution_open


func main_menu_button() -> Button:
	return _main_menu


## The button that opens Art Attribution, and returns to the roll from it.
func page_button() -> Button:
	return _page


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)


func _leave() -> void:
	has_left = true
	StageMapScreen.has_left = true
	navigate.call(Screens.scene(RunFlow.finish_credits()))


func _toggle_page() -> void:
	_is_attribution_open = not _is_attribution_open
	_attribution.scroll_vertical = 0
	restart_roll()
	_show_page()


func _show_page() -> void:
	_roll_clip.visible = not _is_attribution_open
	_attribution.visible = _is_attribution_open
	_page.text = CREDITS if _is_attribution_open else ART_ATTRIBUTION
	_place_roll()


func _place_roll() -> void:
	_roll.position = Vector2((SCREEN.x - COLUMN_WIDTH) / 2.0, roll_top())


func _build_roll() -> void:
	_roll_clip = Control.new()
	_roll_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roll_clip.clip_contents = true
	_roll_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_roll_clip)
	_roll = VBoxContainer.new()
	_roll.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	_roll.add_theme_constant_override("separation", 8)
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_clip.add_child(_roll)
	var was_license: bool = false
	for line: CreditsText.Line in CreditsText.lines():
		match line.kind:
			CreditsText.Kind.GAP:
				_roll.add_child(_gap(40))
			CreditsText.Kind.HEADING:
				_roll.add_child(_gap(8))
				_roll.add_child(_roll_line(line.text, 32, TEXT, true))
			CreditsText.Kind.TITLE:
				_last = _roll_line(line.text, 64, TEXT, true)
				_roll.add_child(_last)
			CreditsText.Kind.LICENSE:
				if not was_license:
					_roll.add_child(_gap(8))
				_roll.add_child(_roll_line(line.text, 18, MUTED, false) if line.text != "" else _gap(12))
			_:
				_roll.add_child(_roll_line(line.text, 24, TEXT, false))
		was_license = line.kind == CreditsText.Kind.LICENSE
	_roll.size = _roll.get_combined_minimum_size()


func _build_attribution() -> void:
	_attribution = ScrollContainer.new()
	_attribution.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attribution.offset_top = MARGIN * 2 + BUTTON_HEIGHT
	_attribution.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_attribution.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_attribution)
	var centered: CenterContainer = CenterContainer.new()
	centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centered.mouse_filter = Control.MOUSE_FILTER_PASS
	_attribution.add_child(centered)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	centered.add_child(column)
	for group: ArtAttribution.Group in ArtAttribution.groups():
		column.add_child(_gap(24))
		column.add_child(_attribution_line(group.heading, 32, true))
		column.add_child(_gap(4))
		for line: String in group.lines:
			column.add_child(_attribution_line(line, 22, false))
	column.add_child(_gap(64))


func _roll_line(text: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = _text(text, font_size, color, is_bold)
	_roll_texts.append(made)
	return made


func _attribution_line(text: String, font_size: int, is_bold: bool) -> Label:
	var made: Label = _text(text, font_size, TEXT, is_bold)
	_attribution_texts.append(made)
	return made


## A centered line, wrapped within the column.
func _text(text: String, font_size: int, color: Color, is_bold: bool) -> Label:
	var made: Label = Label.new()
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	made.text = text
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", color)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_bold:
		made.add_theme_font_override("font", UiText.bold())
	return made


func _button(text: String, pressed: Callable) -> Control:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_override("font", UiText.bold())
	button.add_theme_font_size_override("font_size", 26)
	SteelFrame.frame_roomy(button, WindowLook.BUTTON, BUTTON_HEIGHT)
	button.pressed.connect(pressed)
	var frame: PanelContainer = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(WindowLook.BUTTON_RADIUS + 1)
	style.shadow_color = SHADOW
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(button)
	return frame


func _gap(height: int) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap
