class_name MainMenu
extends Control
## The main menu: a plain list of where the game can go, in the Spoils screen's dithered
## window on the slate ground, with its buttons. A request on the command line
## (--hero=, --villain= or --seed=) skips it and opens the Encounter Screen (A246), unless
## it names something that does not exist, which the menu then says. --deckbuilder opens
## the deckbuilder on a made-up run, for pictures. --stage-map opens the Stage Map of a
## debug run (--run-seed=N, --stage=red), for pictures, and --spoils the Spoils screen of
## a win in one (--rank=lesser, elite or boss). Start Run (debug) begins a debug
## run at the Deckbox, in Kitty Keep, the Stage being built first (milestones 16 and 17).

const START_FORM: String = "res://ui/encounter/start_form.tscn"
const ENCOUNTER: String = "res://ui/encounter/encounter_screen.tscn"
const CARD_GALLERY: String = "res://tools/card_gallery/card_gallery.tscn"
## The Stage a debug run begins in.
const DEMO_STAGE: String = "res://content/stages/kitty_keep.tres"
const DECKBUILDER: String = Screens.DECKBUILDER
const DECKBUILDER_FLAG: String = "--deckbuilder"
## The smallest the window may be made: four times a Backdrop's picture, so that its pixels
## stay even there as they do at 1920 x 1080 (ADR 0035).
const MIN_WINDOW: Vector2i = Vector2i(1280, 720)
const REFUSAL_COLOR: Color = Color("#e08a7a")
## The gap between the menu's rows: the Spoils screen's.
const BUTTON_GAP: int = SpoilsScreen.ROW_GAP

## How the menu opens another scene, and how it quits. Tests replace both. A scene asked
## for on the command line opens at once, so that a --screenshot is not taken mid-fade; one
## chosen from the menu fades in.
var navigate: Callable = func(scene: String) -> void:
	if _is_skipping:
		get_tree().change_scene_to_file(scene)
	else:
		SceneFade.change_scene(get_tree(), scene)
var quit: Callable = func() -> void: get_tree().quit()
## The command line, as given after "--". Tests replace it.
var arguments: PackedStringArray = OS.get_cmdline_user_args()

var _buttons: Dictionary[String, Button] = {}
var _refusal: String = ""
## Whether the menu is going straight to a scene the command line asked for.
var _is_skipping: bool = false


func _ready() -> void:
	# Here because the game always opens on this scene, whatever it goes on to.
	get_window().min_size = MIN_WINDOW
	# Only until the deckbuilder is left, so that its Exit lands here and not back in it.
	if arguments.has(DECKBUILDER_FLAG) and not DeckbuilderScreen.has_left:
		_is_skipping = true
		navigate.call_deferred(DECKBUILDER)
		return
	if arguments.has(StageMapScreen.FLAG) and not StageMapScreen.has_left:
		_is_skipping = true
		RunFlow.start(StageMapScreen.debug_run_from(arguments))
		navigate.call_deferred(Screens.scene(RunFlow.finish_intro()))
		return
	if arguments.has(SpoilsScreen.FLAG) and not SpoilsScreen.has_left:
		_is_skipping = true
		RunFlow.start(SpoilsScreen.debug_run_from(arguments))
		RunFlow.finish_intro()
		navigate.call_deferred(Screens.SPOILS)
		return
	var asked_for: EncounterRequest = EncounterRequest.from_arguments(arguments)
	if asked_for != null:
		_refusal = asked_for.validate()
		if _refusal == "":
			EncounterScreen.request = asked_for
			_is_skipping = true
			navigate.call_deferred(ENCOUNTER)
			return
		# A deck, difficulty or backdrop that does not exist: the menu opens and says so.
		push_error(_refusal)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background: ColorRect = ColorRect.new()
	background.color = StageIntro.GROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var window: PanelContainer = PanelContainer.new()
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.resized.connect(func() -> void: _shade_window(window))
	center.add_child(window)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", BUTTON_GAP)
	window.add_child(column)
	_shade_window(window)
	var title: Label = Label.new()
	title.text = "ModMox"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", CardFonts.title())
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", SpoilsScreen.TEXT)
	column.add_child(title)
	if _refusal != "":
		var reason: Label = Label.new()
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.text = _refusal
		reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason.add_theme_font_size_override("font_size", 20 + UiText.RAISE)
		reason.add_theme_color_override("font_color", REFUSAL_COLOR)
		column.add_child(reason)
	_add(column, "Start Encounter", func() -> void: navigate.call(START_FORM))
	_add(column, "Start Run (debug)", func() -> void: navigate.call(Screens.scene(RunFlow.start(Run.debug(randi(), load(DEMO_STAGE) as StageDefinition)))))
	_add(column, "Card Gallery", func() -> void: navigate.call(CARD_GALLERY))
	_add(column, "Quit Game", func() -> void: quit.call())


## Why the request on the command line could not be played, or "" if there was none or it
## could. The menu shows it under its title.
func refusal() -> String:
	return _refusal


## The button labeled [param text], or null.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func _add(column: VBoxContainer, text: String, on_press: Callable) -> void:
	var made: Button = Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(0, SpoilsScreen.BUTTON_HEIGHT)
	made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.add_theme_font_override("font", UiText.bold())
	made.add_theme_font_size_override("font_size", 24)
	made.add_theme_color_override("font_color", SpoilsScreen.TEXT)
	var fill: Color = SpoilsScreen.BUTTON_FILL
	var height: int = SpoilsScreen.BUTTON_HEIGHT
	var radius: int = SpoilsScreen.BUTTON_RADIUS
	made.add_theme_stylebox_override("normal", DitherShading.button_plate(fill, false, height, radius))
	made.add_theme_stylebox_override("hover", DitherShading.button_plate(fill.lightened(0.1), false, height, radius))
	made.add_theme_stylebox_override("pressed", DitherShading.button_plate(fill, true, height, radius))
	made.add_theme_stylebox_override("hover_pressed", DitherShading.button_plate(fill, true, height, radius))
	made.pressed.connect(on_press)
	column.add_child(_shadowed(made))
	_buttons[text] = made


## The window the menu sits in: the Spoils screen's, shaded over its own height.
func _shade_window(window: PanelContainer) -> void:
	var color: Color = SpoilsScreen.WINDOW_COLOR
	var radius: int = SpoilsScreen.WINDOW_RADIUS
	var face: StyleBoxTexture = DitherShading.plate(color.lightened(0.06), color.darkened(0.3), SpoilsScreen.WINDOW_EDGE,
			radius, 2, 0, maxi(int(window.size.y), radius * 2 + 4))
	face.set_content_margin_all(SpoilsScreen.WINDOW_MARGIN)
	window.add_theme_stylebox_override("panel", face)


## [param item] in a frame that draws only the Spoils screen's drop shadow under a button.
func _shadowed(item: Control) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(SpoilsScreen.BUTTON_RADIUS + 1)
	style.shadow_color = SpoilsScreen.SHADOW
	style.shadow_size = SpoilsScreen.SHADOW_SIZE
	style.shadow_offset = Vector2(0, SpoilsScreen.PART_SHADOW_DROP)
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(item)
	return frame
