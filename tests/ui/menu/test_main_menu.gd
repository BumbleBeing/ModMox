extends GutTest
## The main menu leads to the start form, the card gallery and out of the game; the start
## form opens the Encounter Screen on the encounter it describes.

var _went_to: Array[String] = []
var _has_quit: bool = false


func before_each() -> void:
	_went_to.clear()
	_has_quit = false
	EncounterScreen.request = null


func after_each() -> void:
	EncounterScreen.request = null


func test_each_menu_button_leads_where_it_says() -> void:
	var menu: MainMenu = _menu(PackedStringArray())

	menu.button("Start Encounter").pressed.emit()
	menu.button("Card Gallery").pressed.emit()

	assert_eq(_went_to, [MainMenu.START_FORM, MainMenu.CARD_GALLERY] as Array[String])
	assert_false(_has_quit)
	for scene: String in _went_to:
		assert_true(ResourceLoader.exists(scene), "%s exists." % scene)


func test_the_deckbuilder_button_opens_the_prototype() -> void:
	var menu: MainMenu = _menu(PackedStringArray())

	menu.button("Deckbuilder (prototype)").pressed.emit()

	assert_eq(_went_to, [MainMenu.DECKBUILDER] as Array[String])
	assert_true(ResourceLoader.exists(MainMenu.DECKBUILDER))
	var screen: Node = (load(MainMenu.DECKBUILDER) as PackedScene).instantiate()
	assert_true(screen is DeckbuilderScreen)
	screen.free()


func test_the_deckbuilder_flag_no_longer_skips_the_menu_once_the_deckbuilder_has_been_left() -> void:
	DeckbuilderScreen.has_left = true

	var menu: MainMenu = _menu(PackedStringArray(["--deckbuilder"]))
	await wait_process_frames(2)
	DeckbuilderScreen.has_left = false

	assert_eq(_went_to, [] as Array[String], "Exit lands on the menu and does not bounce back.")
	assert_not_null(menu.button("Start Encounter"))


func test_the_deckbuilder_flag_skips_the_menu() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--deckbuilder"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [MainMenu.DECKBUILDER] as Array[String])
	assert_null(menu.button("Start Encounter"), "The menu was never drawn.")


func test_quit_game_quits() -> void:
	var menu: MainMenu = _menu(PackedStringArray())

	menu.button("Quit Game").pressed.emit()

	assert_true(_has_quit)
	assert_eq(_went_to.size(), 0)


func test_a_request_on_the_command_line_skips_the_menu() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--hero=blue_red", "--seed=4"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [MainMenu.ENCOUNTER] as Array[String])
	assert_eq(EncounterScreen.request.hero_deck, "blue_red")
	assert_eq(EncounterScreen.request.encounter_seed, 4)
	assert_null(menu.button("Start Encounter"), "The menu was never drawn.")


func test_the_scenes_are_the_menu_the_form_and_the_screen() -> void:
	assert_true(ResourceLoader.exists(MainMenu.ENCOUNTER))
	var menu: Node = (load("res://ui/menu/main_menu.tscn") as PackedScene).instantiate()
	var form: Node = (load(MainMenu.START_FORM) as PackedScene).instantiate()

	assert_true(menu is MainMenu)
	assert_true(form is StartForm)
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://ui/menu/main_menu.tscn")
	menu.free()
	form.free()


func test_the_start_form_opens_the_encounter_it_describes() -> void:
	var form: StartForm = StartForm.new()
	form.navigate = _go
	add_child_autofree(form)
	var wanted: EncounterRequest = EncounterRequest.new()
	wanted.hero_deck = "white_black"
	wanted.villain_deck = "blue_red"
	wanted.encounter_seed = 321
	wanted.difficulty = "normal"
	wanted.has_sample_emblems = true
	form.fill_in(wanted)

	form.start_button().pressed.emit()

	assert_eq(_went_to, [StartForm.ENCOUNTER] as Array[String])
	var asked: EncounterRequest = EncounterScreen.request
	assert_eq([asked.hero_deck, asked.villain_deck, asked.encounter_seed, asked.difficulty, asked.has_sample_emblems],
		["white_black", "blue_red", 321, "normal", true])


func test_the_start_form_starts_on_an_easy_villain_and_no_sample_emblems() -> void:
	var form: StartForm = StartForm.new()
	add_child_autofree(form)

	assert_eq(form.request().difficulty, "easy")
	assert_false(form.request().has_sample_emblems)
	assert_eq(form.request().validate(), "")


func _menu(arguments: PackedStringArray) -> MainMenu:
	var menu: MainMenu = MainMenu.new()
	menu.navigate = _go
	menu.quit = func() -> void: _has_quit = true
	menu.arguments = arguments
	add_child_autofree(menu)
	return menu


func _go(scene: String) -> void:
	_went_to.append(scene)
