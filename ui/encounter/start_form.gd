class_name StartForm
extends Control
## Chooses the encounter to play: both decks, the seed and the Villain's difficulty.
## Temporary: once runs exist, the game hands the Encounter Screen its setup (A246), and
## this form and its sample Emblems go.

const ENCOUNTER: String = "res://ui/encounter/encounter_screen.tscn"
const MENU: String = "res://ui/menu/main_menu.tscn"

## How this form leaves for another scene. Tests replace it.
var navigate: Callable = func(scene: String) -> void: get_tree().change_scene_to_file(scene)

var _request: EncounterRequest = EncounterRequest.new()
var _hero: OptionButton
var _villain: OptionButton
var _seed: SpinBox
var _difficulty: OptionButton
var _emblems: CheckBox
var _start: Button


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1a1d22")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var heading: Label = Label.new()
	heading.text = "Start an encounter"
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	_hero = _choice(column, "Hero's deck", EncounterRequest.deck_names(), _request.hero_deck)
	_villain = _choice(column, "Villain's deck", EncounterRequest.deck_names(), _request.villain_deck)
	_seed = SpinBox.new()
	_seed.max_value = 999999
	_seed.value = _request.encounter_seed
	_row(column, "Seed", _seed)
	_difficulty = _choice(column, "Villain's difficulty", EncounterRequest.DIFFICULTIES, _request.difficulty)
	_emblems = CheckBox.new()
	_emblems.text = "Sample Emblems"
	column.add_child(_emblems)
	_start = Button.new()
	_start.text = "Start"
	_start.pressed.connect(start)
	column.add_child(_start)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		navigate.call(MENU)


## The request as the form is filled in now.
func request() -> EncounterRequest:
	var filled: EncounterRequest = EncounterRequest.new()
	filled.hero_deck = _hero.get_item_text(_hero.selected)
	filled.villain_deck = _villain.get_item_text(_villain.selected)
	filled.encounter_seed = int(_seed.value)
	filled.difficulty = _difficulty.get_item_text(_difficulty.selected)
	filled.has_sample_emblems = _emblems.button_pressed
	return filled


## Fills the form in as [param wanted] says.
func fill_in(wanted: EncounterRequest) -> void:
	_select(_hero, wanted.hero_deck)
	_select(_villain, wanted.villain_deck)
	_seed.value = wanted.encounter_seed
	_select(_difficulty, wanted.difficulty)
	_emblems.button_pressed = wanted.has_sample_emblems


func start_button() -> Button:
	return _start


## Opens the Encounter Screen on the encounter the form describes.
func start() -> void:
	EncounterScreen.request = request()
	navigate.call(ENCOUNTER)


func _choice(column: VBoxContainer, text: String, names: Array[String], chosen: String) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	for item: String in names:
		choice.add_item(item)
	_select(choice, chosen)
	_row(column, text, choice)
	return choice


func _select(choice: OptionButton, wanted: String) -> void:
	for index: int in choice.item_count:
		if choice.get_item_text(index) == wanted:
			choice.select(index)


func _row(column: VBoxContainer, text: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	column.add_child(row)
