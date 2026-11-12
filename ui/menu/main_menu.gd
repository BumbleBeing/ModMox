class_name MainMenu
extends Control
## The main menu: a plain list of where the game can go. A request on the command line
## (--hero=, --villain= or --seed=) skips it and opens the Encounter Screen (A246), and
## --deckbuilder opens the deckbuilder prototype.

const START_FORM: String = "res://ui/encounter/start_form.tscn"
const ENCOUNTER: String = "res://ui/encounter/encounter_screen.tscn"
const CARD_GALLERY: String = "res://tools/card_gallery/card_gallery.tscn"
## The deckbuilder is a prototype (milestone 15) until it is ported into ui/.
const DECKBUILDER: String = "res://prototypes/deckbuilder/deckbuilder_screen.tscn"
const DECKBUILDER_FLAG: String = "--deckbuilder"

## How the menu opens another scene, and how it quits. Tests replace both.
var navigate: Callable = func(scene: String) -> void: get_tree().change_scene_to_file(scene)
var quit: Callable = func() -> void: get_tree().quit()
## The command line, as given after "--". Tests replace it.
var arguments: PackedStringArray = OS.get_cmdline_user_args()

var _buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	if arguments.has(DECKBUILDER_FLAG):
		navigate.call_deferred(DECKBUILDER)
		return
	var asked_for: EncounterRequest = EncounterRequest.from_arguments(arguments)
	if asked_for != null:
		EncounterScreen.request = asked_for
		navigate.call_deferred(ENCOUNTER)
		return
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
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)
	_add(column, "Start Encounter", func() -> void: navigate.call(START_FORM))
	_add(column, "Deckbuilder (prototype)", func() -> void: navigate.call(DECKBUILDER))
	_add(column, "Card Gallery", func() -> void: navigate.call(CARD_GALLERY))
	_add(column, "Quit Game", func() -> void: quit.call())


## The button labeled [param text], or null.
func button(text: String) -> Button:
	return _buttons.get(text, null) as Button


func _add(column: VBoxContainer, text: String, on_press: Callable) -> void:
	var made: Button = Button.new()
	made.text = text
	made.custom_minimum_size = Vector2(0, 56)
	made.add_theme_font_size_override("font_size", 22)
	made.pressed.connect(on_press)
	column.add_child(made)
	_buttons[text] = made
