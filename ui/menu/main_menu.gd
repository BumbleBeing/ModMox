class_name MainMenu
extends Control
## The main menu: a plain list of where the game can go. A request on the command line
## (--hero=, --villain= or --seed=) skips it and opens the Encounter Screen (A246), unless
## it names something that does not exist, which the menu then says. --deckbuilder opens
## the deckbuilder on a made-up run, for pictures. --stage-map opens the Stage Map of a
## debug run (--run-seed=N, --stage=red), for pictures. Start Run (debug) begins a debug
## run at the Deckbox (milestones 16 and 17).

const START_FORM: String = "res://ui/encounter/start_form.tscn"
const ENCOUNTER: String = "res://ui/encounter/encounter_screen.tscn"
const CARD_GALLERY: String = "res://tools/card_gallery/card_gallery.tscn"
const DECKBUILDER: String = RunFlow.DECKBUILDER
const DECKBUILDER_FLAG: String = "--deckbuilder"
## The smallest the window may be made: four times a Backdrop's picture, so that its pixels
## stay even there as they do at 1920 x 1080 (ADR 0035).
const MIN_WINDOW: Vector2i = Vector2i(1280, 720)
const REFUSAL_COLOR: Color = Color("#e08a7a")

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
		navigate.call_deferred(RunFlow.finish_intro())
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
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1a1d22")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(360, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title: Label = Label.new()
	title.text = "ModMox"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", CardFonts.title())
	title.add_theme_font_size_override("font_size", 66)
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
	_add(column, "Start Run (debug)", func() -> void: navigate.call(RunFlow.start(Run.debug(randi()))))
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
	made.custom_minimum_size = Vector2(0, 56)
	made.add_theme_font_size_override("font_size", 24)
	made.pressed.connect(on_press)
	column.add_child(made)
	_buttons[text] = made
