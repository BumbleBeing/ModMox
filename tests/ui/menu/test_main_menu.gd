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


func test_start_run_debug_begins_a_debug_run_at_the_deckbox_with_close() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	RunFlow.clear()

	menu.button("Start Run (debug)").pressed.emit()

	assert_eq(_went_to, [Screens.DECKBOX] as Array[String])
	assert_not_null(RunFlow.run)
	assert_not_null(RunFlow.run.deckbox.active())
	assert_null(RunFlow.villain, "The run opens on the Deckbox with Close.")
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_INTRO)
	assert_eq(RunFlow.run.stage_visit.stage.name, "Kitty Keep", "The demo's Stage.")
	var screen: Node = (load(Screens.DECKBOX) as PackedScene).instantiate()
	assert_true(screen is DeckboxScreen)
	screen.free()
	RunFlow.clear()


func test_there_is_no_deckbuilder_button_any_more() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	assert_null(menu.button("Deckbuilder (prototype)"), "the Deckbox is the only door to the deckbuilder")


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


## S12: the Stage Map flag opens the Stage Map of the debug run asked for.
func test_the_stage_map_flag_opens_the_stage_map_of_the_run_asked_for() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--stage-map", "--run-seed=7", "--stage=red"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	assert_eq(RunFlow.run.run_seed, 7)
	assert_eq(RunFlow.run.stage_visit.stage.backdrop(), "red")
	assert_null(menu.button("Start Encounter"), "The menu was never drawn.")
	var screen: Node = (load(Screens.STAGE_MAP) as PackedScene).instantiate()
	assert_true(screen is StageMapScreen)
	screen.free()
	RunFlow.clear()


func test_the_stage_map_flag_no_longer_skips_the_menu_once_the_run_has_ended() -> void:
	StageMapScreen.has_left = true

	var menu: MainMenu = _menu(PackedStringArray(["--stage-map"]))
	await wait_process_frames(2)
	StageMapScreen.has_left = false

	assert_eq(_went_to, [] as Array[String])
	assert_not_null(menu.button("Start Encounter"))


## Milestone 19's S12: --tier=N with --stage-map walks the debug run up to Tier N.
func test_the_stage_map_flag_walks_up_to_the_tier_asked_for() -> void:
	_menu(PackedStringArray(["--stage-map", "--run-seed=7", "--stage=red", "--tier=4"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	assert_eq(RunFlow.run.stage_visit.stage.tier, 4)
	assert_eq(RunFlow.run.stages_beaten().size(), 3)
	assert_eq(RunFlow.run.stages_beaten()[0].stage.backdrop(), "red", "--stage= is the Tier 1 Stage.")
	RunFlow.clear()


## Milestone 19's S12: --run-won opens Run Won of a debug run that has beaten all five Bosses.
func test_the_run_won_flag_opens_run_won() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--run-won", "--run-seed=7"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.RUN_WON] as Array[String])
	assert_true(RunFlow.run.is_won())
	assert_null(menu.button("Start Encounter"), "The menu was never drawn.")
	RunFlow.clear()


## Milestone 19's S12: --run-lost opens Run Lost of a debug run lost to the Boss of --tier=N.
func test_the_run_lost_flag_opens_run_lost_at_the_tier_asked_for() -> void:
	_menu(PackedStringArray(["--run-lost", "--run-seed=7", "--tier=3"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.RUN_LOST] as Array[String])
	assert_true(RunFlow.run.is_lost())
	assert_eq(RunFlow.run.stage_visit.stage.tier, 3)
	assert_eq(RunFlow.run.fell_to, RunFlow.run.stage_visit.boss)
	RunFlow.clear()


## Milestone 19's S12: --credits opens the Credits.
func test_the_credits_flag_opens_the_credits() -> void:
	_menu(PackedStringArray(["--credits"]))
	await wait_process_frames(2)

	assert_eq(_went_to, [Screens.CREDITS] as Array[String])


func test_the_run_end_and_credits_flags_no_longer_skip_the_menu_once_left() -> void:
	RunEndScreen.has_left = true
	CreditsScreen.has_left = true

	var menu: MainMenu = _menu(PackedStringArray(["--run-won", "--credits"]))
	await wait_process_frames(2)
	RunEndScreen.has_left = false
	CreditsScreen.has_left = false

	assert_eq(_went_to, [] as Array[String])
	assert_not_null(menu.button("Start Encounter"))


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


func test_a_request_that_cannot_be_played_stays_on_the_menu_and_says_why() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--hero=no_such_deck", "--seed=4"]))
	await wait_process_frames(2)

	assert_eq(_went_to.size(), 0, "No encounter is opened on a deck that does not exist.")
	assert_null(EncounterScreen.request)
	assert_not_null(menu.button("Start Encounter"), "The menu is drawn instead.")
	assert_eq(menu.refusal(), "There is no deck named \"no_such_deck\".")
	assert_push_error("no_such_deck")


func test_a_request_with_an_unknown_difficulty_is_refused_too() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--seed=4", "--difficulty=impossible"]))
	await wait_process_frames(2)

	assert_eq(_went_to.size(), 0)
	assert_eq(menu.refusal(), "There is no difficulty named \"impossible\".")
	assert_push_error("impossible")


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


func test_the_start_form_offers_every_backdrop_and_starts_on_plain() -> void:
	var form: StartForm = StartForm.new()
	add_child_autofree(form)

	var offered: Array[String] = []
	for index: int in form.backdrop_choice().item_count:
		offered.append(form.backdrop_choice().get_item_text(index))
	assert_eq(offered, Backdrops.NAMES)
	assert_eq(form.request().backdrop, "plain")


func test_the_start_form_puts_the_chosen_backdrop_on_the_request() -> void:
	var form: StartForm = StartForm.new()
	form.navigate = _go
	add_child_autofree(form)
	var wanted: EncounterRequest = EncounterRequest.new()
	wanted.backdrop = "green"
	form.fill_in(wanted)

	form.start_button().pressed.emit()

	assert_eq(EncounterScreen.request.backdrop, "green")


func test_the_window_is_never_smaller_than_four_times_a_backdrop() -> void:
	_menu(PackedStringArray())

	assert_eq(MainMenu.MIN_WINDOW, Vector2i(1280, 720))
	assert_eq(get_window().min_size, MainMenu.MIN_WINDOW)


func test_the_menu_soldier_stands_on_the_window_and_the_two_are_centered_together() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	menu.size = Vector2(1920, 1080)
	await wait_process_frames(2)

	var soldier: MenuSoldier = menu.soldier()
	var his: Rect2 = soldier.get_global_rect()
	var window: Rect2 = menu.window().get_global_rect()

	assert_not_null(soldier)
	assert_true(soldier.is_visible_in_tree())
	assert_eq(his.size, Vector2.ONE * MenuSoldier.SPRITE_SIZE * MenuSoldier.SCALE)
	assert_eq(his.position, his.position.round(), "on whole pixels")
	assert_almost_eq(his.get_center().x, window.get_center().x, 1.0, "centered on the window")
	assert_eq(his.end.y - MenuSoldier.SCALE, window.position.y,
			"his soles, a sprite pixel above his picture's foot, on the window's top")
	assert_almost_eq((his.position.y + window.end.y) / 2, menu.get_global_rect().get_center().y, 1.0,
			"he and the window centered on the screen together")
	assert_eq(soldier.texture.resource_path, SoldierAnimations.SPRITES % SoldierAnimations.NEUTRAL,
			"every animation opens standing still")
	assert_not_null(soldier.sequence(), "what brings him his effects asks his sequence")


func test_his_shadow_lies_on_the_windows_top_under_where_he_touches_it() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	menu.size = Vector2(1920, 1080)
	await wait_process_frames(2)
	var soldier: MenuSoldier = menu.soldier()
	var his: Rect2 = soldier.get_global_rect()
	var window: Rect2 = menu.window().get_global_rect()

	var blocks: Array[Rect2] = menu.shadow_blocks()

	assert_gt(blocks.size(), 0)
	for block: Rect2 in blocks:
		assert_between(block.position.y, window.position.y, window.position.y + 12.0, "on the window's top")
		assert_has(soldier.contacts(), floori((block.get_center().x - his.position.x) / MenuSoldier.SCALE))
		assert_eq(posmod(int(block.position.y - window.position.y), DitherShading.BLOCK), 0,
				"in step with the window's dither")


func test_the_wisp_floats_in_front_of_him_on_whole_pixels_and_takes_no_clicks() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	menu.size = Vector2(1920, 1080)
	await wait_process_frames(3)
	var wisp: MenuWisp = menu.wisp()

	assert_not_null(wisp)
	assert_true(wisp.is_visible_in_tree(), "flying once it knows where he stands")
	assert_gt(wisp.get_index(), menu.soldier().get_parent().get_parent().get_index(), "drawn in front of him")
	assert_eq(wisp.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no clicks")
	assert_eq(wisp.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(wisp.size, Vector2.ONE * MenuWisp.SPRITE_SIZE * MenuWisp.SCALE, "eight times its sprite")
	assert_eq(wisp.global_position, wisp.global_position.round(), "on whole pixels")
	assert_false(menu.window().get_global_rect().intersects(wisp.get_global_rect()), "off the window")


func test_the_wisp_light_pools_on_the_windows_top_at_his_feet_as_the_wisp_touches_him() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	menu.size = Vector2(1920, 1080)
	await wait_process_frames(2)
	var soldier: MenuSoldier = menu.soldier()
	var window: Rect2 = menu.window().get_global_rect()
	soldier.set_process(false)

	soldier.advance(soldier.sequence().seconds_until_flash() + 0.001)

	assert_lt(menu.wisp().flight().position().distance_to(soldier.chest()), 0.01, "on his chest as he flashes")
	var blocks: Array[Rect2] = menu.light_blocks()
	var middle: float = 0.0
	assert_gt(blocks.size(), 0)
	for block: Rect2 in blocks:
		assert_between(block.position.y, window.position.y, window.position.y + DitherShading.BLOCK * 3.0,
				"on the window's top")
		middle += block.get_center().x
	assert_almost_eq(middle / blocks.size(), soldier.chest().x, DitherShading.BLOCK * 1.0, "at his feet")


func test_the_wisp_light_lies_over_the_soldier_shadow() -> void:
	var menu: MainMenu = _menu(PackedStringArray())

	assert_gt(menu.get_node("WispLight").get_index(), menu.get_node("SoldierShadow").get_index())


func test_effect_callouts_float_in_front_of_him_and_behind_the_wisp_on_whole_pixels_taking_no_clicks() -> void:
	var menu: MainMenu = _menu(PackedStringArray())
	menu.size = Vector2(1920, 1080)
	await wait_process_frames(2)
	var soldier: MenuSoldier = menu.soldier()
	soldier.set_process(false)

	soldier.advance(soldier.sequence().seconds_until_flash() + 0.5)

	var layer: MenuCallouts = menu.callouts()
	var shown: Array[EffectCallout] = layer.callouts().shown()
	assert_eq(shown.size(), 1, "his first effect's")
	assert_gt(layer.get_index(), soldier.get_parent().get_parent().get_index(), "drawn in front of him")
	assert_lt(layer.get_index(), menu.wisp().get_index(), "and behind the Wisp")
	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE, "it takes no clicks")
	assert_eq(layer.callouts().square(), soldier.get_global_rect(), "it knows where he stands")
	var drawn: Rect2 = shown[0].drawn_rect(soldier.get_global_rect(), layer.callouts().age_of(shown[0]))
	assert_eq(drawn.position, drawn.position.round(), "on whole pixels")


func test_there_are_no_effect_callouts_when_the_menu_is_skipped() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--seed=7"]))

	assert_null(menu.callouts())


func test_there_is_no_wisp_when_the_menu_is_skipped() -> void:
	var menu: MainMenu = _menu(PackedStringArray(["--seed=7"]))

	assert_null(menu.wisp())


func test_the_window_keeps_its_smallest_size_when_the_menu_is_skipped() -> void:
	get_window().min_size = Vector2i.ZERO
	_menu(PackedStringArray(["--seed=7"]))

	assert_eq(get_window().min_size, MainMenu.MIN_WINDOW)


func _menu(arguments: PackedStringArray) -> MainMenu:
	var menu: MainMenu = MainMenu.new()
	menu.navigate = _go
	menu.quit = func() -> void: _has_quit = true
	menu.arguments = arguments
	add_child_autofree(menu)
	return menu


func _go(scene: String) -> void:
	_went_to.append(scene)
