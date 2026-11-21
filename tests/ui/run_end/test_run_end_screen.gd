extends GutTest
## Run Won and Run Lost (milestone 19, signed off as step 2 of prototypes/run_ends): "Trial
## won" with the five Stages, the gold and the Hearts; "Trial lost" with the Villain that took
## the last Heart and the Stages beaten; the discs, still or breathing, in their Stages'
## colors; the reveal; and where each button leads.

const SCREEN: Vector2 = Vector2(1920, 1080)
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"

var _screen: RunEndScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()
	RunEndScreen.has_left = false
	StageMapScreen.has_left = false
	await wait_process_frames(2)


## A run that has beaten all five Bosses, begun in Kitty Keep.
func _won_run() -> Run:
	var run: Run = Run.debug(7, load(KITTY_KEEP) as StageDefinition)
	run.record_encounter(false)
	while not run.is_won():
		if run.is_stage_beaten():
			run.enter_next_stage()
		elif run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])
	RunFlow.start(run)
	return run


## A run whose last Heart was taken at [param tier]: by its Boss, or by the first Villain
## met there when [param to_the_boss] is off.
func _lost_run(tier: int, to_the_boss: bool) -> Run:
	var run: Run = Run.debug(7, load(KITTY_KEEP) as StageDefinition, tier)
	while not run.stage_visit.must_play() or (to_the_boss and run.stage_visit.node().kind != StageMap.Kind.BOSS):
		if run.stage_visit.must_play():
			run.record_encounter(true)
		else:
			run.move_to(run.stage_visit.choices()[0])
	run.hearts = 1
	run.record_encounter(false)
	RunFlow.start(run)
	return run


## Opens the screen in a viewport of its own, so that a pushed click reaches it as a real
## one does.
func _open(run: Run, won: bool, paced: bool = false) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	_screen = RunEndScreen.new()
	_screen.is_won = won
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	_screen.is_paced = paced
	_screen.game_speed = GameSpeed.Speed.BLAZING
	viewport.add_child(_screen)
	_screen.size = SCREEN
	_screen.set_process(false)
	_screen.begin(run)
	await wait_process_frames(2)


func _click(target: Control) -> void:
	var spot: Vector2 = target.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		_screen.get_viewport().push_input(click)
	await wait_process_frames(1)


## S3: Run Won reads "Trial won" and shows the five Stages' discs in Tier order, each with
## its Stage's name.
func test_run_won_shows_the_five_stages_in_tier_order() -> void:
	var run: Run = _won_run()
	await _open(run, true)

	assert_eq(_screen.title(), "Trial won")
	var names: Array[String] = ["Trial won"]
	for visit: StageVisit in run.stages_played():
		names.append(visit.stage.name)
	assert_eq(_screen.texts(), names, "The Stages' names in Tier order, and no other words.")
	assert_eq(_screen.stage_discs().size(), Villain.TIERS)
	for index: int in Villain.TIERS:
		assert_eq(_screen.stage_discs()[index].portrait, run.stages_played()[index].boss.sprite)


## S3: the gold held and the Hearts left stand on their two plates.
func test_run_won_shows_the_gold_and_the_hearts_on_their_plates() -> void:
	var run: Run = _won_run()
	await _open(run, true)

	assert_eq(_screen.gold_text(), str(run.gold))
	assert_gt(run.gold, 0)
	assert_eq(_screen.hearts_shown(), [true, true, false] as Array[bool])
	var plates: Array[PanelContainer] = _screen.plates()
	assert_eq(plates.size(), 2)
	for plate: PanelContainer in plates:
		assert_eq(plate.size, Vector2(RunEndScreen.PLATE_WIDTH, RunEndScreen.PLATE_HEIGHT))
		assert_eq(plate.get_theme_stylebox("panel"), SteelFrame.plate(SteelFrame.STEEL, "normal",
				RunEndScreen.PLATE_HEIGHT, false, ButtonShading.DISABLED, RunEndScreen.PLATE_SIDE, true, 0,
				WindowLook.BUTTON), "The button's frame turned inside out: silver in a dark gray ring.")


## S3: Continue opens the Credits.
func test_run_won_continue_opens_the_credits() -> void:
	await _open(_won_run(), true)

	await _click(_screen.button())

	assert_eq(_screen.button().text, "Continue")
	assert_eq(_went_to, [Screens.CREDITS] as Array[String])


## S4: Run Lost reads "Trial lost" and shows the Boss that took the last Heart in its disc,
## its name and where the run fell, and the Stages beaten.
func test_run_lost_to_a_boss_shows_it_in_its_disc_and_the_stages_beaten() -> void:
	var run: Run = _lost_run(3, true)
	await _open(run, false)
	var visit: StageVisit = run.stage_visit

	assert_eq(_screen.title(), "Trial lost")
	assert_not_null(_screen.villain_disc())
	assert_null(_screen.villain_frame())
	assert_eq(_screen.villain_disc().portrait, visit.boss.sprite)
	var names: Array[String] = ["Trial lost", visit.boss.name, "%s, Tier 3" % visit.stage.name, "Stages beaten"]
	for beaten: StageVisit in run.stages_beaten():
		names.append(beaten.stage.name)
	assert_eq(_screen.texts(), names)
	assert_eq(_screen.stage_discs().size(), 2)


## S4: a Villain that is not a Boss stands in the Portrait frame.
func test_run_lost_to_another_villain_shows_it_in_the_portrait_frame() -> void:
	var run: Run = _lost_run(2, false)
	await _open(run, false)

	assert_null(_screen.villain_disc())
	assert_not_null(_screen.villain_frame())
	assert_eq((_screen.villain_frame().get_child(0) as TextureRect).texture, run.fell_to.sprite)
	assert_eq(_screen.texts()[1], run.fell_to.name)


## S4: lost at Tier 1, the heading and the row are left out.
func test_run_lost_at_tier_one_leaves_out_the_stages_beaten() -> void:
	var run: Run = _lost_run(1, true)
	await _open(run, false)

	assert_false(_screen.texts().has("Stages beaten"))
	assert_eq(_screen.stage_discs().size(), 0)
	assert_eq(_screen.texts(), ["Trial lost", run.fell_to.name, "Kitty Keep, Tier 1"] as Array[String])


## S4: Main Menu goes to the main menu, and the run is over.
func test_run_lost_main_menu_goes_to_the_main_menu() -> void:
	await _open(_lost_run(2, true), false)

	await _click(_screen.button())

	assert_eq(_screen.button().text, "Main Menu")
	assert_eq(_went_to, [Screens.MENU] as Array[String])
	assert_null(RunFlow.run)
	assert_true(StageMapScreen.has_left, "The menu's --stage-map does not open the ended run again.")


## S5: a beaten Boss's disc is still, and Run Lost's Boss breathes.
func test_beaten_bosses_are_still_and_the_boss_not_beaten_breathes() -> void:
	await _open(_lost_run(3, true), false)
	_screen.villain_disc().set_process(true)
	for disc: RunEndDisc in _screen.stage_discs():
		disc.set_process(true)

	await wait_seconds(0.3)

	assert_true(_screen.villain_disc().is_breathing)
	assert_gt(_screen.villain_disc().seconds_drawn(), 0.0)
	for disc: RunEndDisc in _screen.stage_discs():
		assert_false(disc.is_breathing)
		assert_eq(disc.seconds_drawn(), 0.0)


## S6: each disc is filled with its Stage's ground color, its ring in the same hue.
func test_each_disc_is_filled_with_its_stages_ground_color() -> void:
	var run: Run = _won_run()
	await _open(run, true)

	for index: int in Villain.TIERS:
		var stage: StageDefinition = run.stages_played()[index].stage
		assert_eq(_screen.stage_discs()[index].ground, RunEndScreen.ground_of(stage), stage.name)
	assert_eq(RunEndScreen.ground_of(load(KITTY_KEEP) as StageDefinition), (load(KITTY_KEEP) as StageDefinition).intro_color)
	var picture: Image = BossDisc.jeweled_disc(Color8(92, 118, 160)).get_image()
	var clay: Color = picture.get_pixel(16, 16)
	var ring: Color = picture.get_pixel(16, 4)
	assert_almost_eq(clay.h, Color8(92, 118, 160).h, 0.05, "The fill is the Stage's color.")
	assert_almost_eq(ring.h, clay.h, 0.05, "The ring is in the same hue.")
	assert_gt(ring.s, clay.s, "The ring is a saturated jewel.")


## S7: the screen comes in, and a click ends it at once.
func test_the_reveal_plays_and_a_click_ends_it() -> void:
	await _open(_won_run(), true, true)

	assert_true(_screen.is_revealing())
	assert_eq(_screen.gold_text(), "0")
	_screen.advance(0.1)
	assert_true(_screen.is_revealing())

	await _click(_screen.stage_discs()[0])

	assert_false(_screen.is_revealing())
	assert_eq(_went_to, [] as Array[String], "The click only ended the reveal.")


## S7: the gold ends on the gold held, and the button takes no clicks until it has come in.
func test_the_gold_counts_up_and_the_button_waits_for_the_reveal() -> void:
	var run: Run = _won_run()
	await _open(run, true, true)

	_screen.advance(RunEndReveal.part_at(Villain.TIERS) + 0.1)
	assert_between(int(_screen.gold_text()), 1, run.gold - 1, "Counting up.")
	assert_eq(_screen.button().mouse_filter, Control.MOUSE_FILTER_IGNORE)

	_screen.advance(10.0)

	assert_eq(_screen.gold_text(), str(run.gold))
	assert_eq(_screen.button().mouse_filter, Control.MOUSE_FILTER_STOP)
	await _click(_screen.button())
	assert_eq(_went_to, [Screens.CREDITS] as Array[String])


func test_each_screen_is_its_scene() -> void:
	for pair: Array in [[Screens.RUN_WON, true], [Screens.RUN_LOST, false]]:
		var scene: Node = (load(pair[0]) as PackedScene).instantiate()
		assert_true(scene is RunEndScreen)
		assert_eq((scene as RunEndScreen).is_won, pair[1])
		scene.free()
