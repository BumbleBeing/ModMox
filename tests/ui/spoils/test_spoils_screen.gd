extends GutTest
## The Spoils screen (milestone 18, signed off as prototypes/spoils_screen): "Found Items",
## the gold won on parchment, a Card Face for each card won glowing its Rarity, the reveal,
## and Continue on to the Stage Map.

const SCREEN: Vector2 = Vector2(1920, 1080)

var _run: Run
var _screen: SpoilsScreen
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	RunFlow.clear()
	_run = Run.debug(7)
	RunFlow.start(_run)
	RunFlow.finish_intro()


func after_each() -> void:
	RunFlow.clear()
	await wait_process_frames(2)


## Wins the first encounter on the first choices from the Start Node.
func _win_an_encounter() -> void:
	while not _run.stage_visit.must_play():
		_run.move_to(_run.stage_visit.choices()[0])
	RunFlow.arrive()
	assert_eq(RunFlow.finish_encounter(true), RunFlow.Screen.SPOILS)


## Walks to the Boss, winning every encounter, and beats it.
func _beat_the_boss() -> void:
	while _run.stage_visit.node().kind != StageMap.Kind.BOSS:
		if _run.stage_visit.must_play():
			_run.record_encounter(true)
		else:
			_run.move_to(_run.stage_visit.choices()[0])
	RunFlow.arrive()
	assert_eq(RunFlow.finish_encounter(true), RunFlow.Screen.SPOILS)


## Opens the screen in a viewport of its own, so that a pushed click reaches it as a real
## one does.
func _open(paced: bool = false) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SCREEN)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	_screen = SpoilsScreen.new()
	_screen.starts_itself = false
	_screen.navigate = func(scene: String) -> void: _went_to.append(scene)
	_screen.is_paced = paced
	_screen.game_speed = GameSpeed.Speed.BLAZING
	viewport.add_child(_screen)
	_screen.size = SCREEN
	_screen.set_process(false)
	_screen.begin(_run)
	await wait_process_frames(2)


## S1: after a win the screen reads "Found Items", shows the gold won and a Card Face for
## each card won, in order, and no Item panel.
func test_the_screen_shows_what_the_win_paid() -> void:
	_win_an_encounter()
	await _open()
	var paid: Spoils = _run.last_spoils

	assert_eq(_screen.heading(), "Found Items")
	assert_eq(_screen.gold_text(), "+%d" % paid.gold)
	var names: Array[String] = []
	for card: MmRunCard in paid.cards:
		names.append(card.base.name)
	assert_eq(_screen.card_names(), names)
	assert_eq(_screen.card_faces().size(), paid.cards.size())
	assert_null(_screen.item_panel())


## S2: with no Item the gold panel stands alone, centered on the window.
func test_the_gold_alone_is_centered() -> void:
	_win_an_encounter()
	await _open()

	var gold: Rect2 = _screen.gold_panel().get_global_rect()
	var window: Rect2 = _screen.window().get_global_rect()
	assert_almost_eq(gold.get_center().x, window.get_center().x, 1.0)


## The window is edged in the Steel Rim, as every window standing over a screen is.
func test_the_window_is_edged_in_the_steel_rim() -> void:
	_win_an_encounter()
	await _open()

	var window: Control = _screen.window()
	var face: StyleBoxTexture = window.get_theme_stylebox("panel") as StyleBoxTexture
	assert_eq(window.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(face.texture.get_image().get_data(), WindowLook.plate(int(window.size.y)).texture.get_image().get_data())


## S3: each card glows its Rarity's color, the Inspector's.
func test_each_card_glows_its_raritys_color() -> void:
	_beat_the_boss()
	await _open()

	var faces: Array[CardFace] = _screen.card_faces()
	for index: int in faces.size():
		var rarity: MmCardDefinition.Rarity = _run.last_spoils.cards[index].base.rarity
		assert_eq(BorderEffects.glow_colors(faces[index]), [Inspector.glow_of(rarity)] as Array[Color])


## S4: while the reveal plays, Continue cannot be clicked; once it ends, the count reads the
## gold won and Continue opens the Stage Map.
func test_continue_works_only_once_the_reveal_is_over() -> void:
	_win_an_encounter()
	await _open(true)

	assert_true(_screen.is_revealing())
	_screen.advance(0.4)
	assert_true(_screen.is_revealing())
	assert_ne(_screen.gold_text(), "+%d" % _run.last_spoils.gold, "the count is still going up")
	await _click(_screen.continue_button())
	assert_eq(_went_to, [] as Array[String])

	_screen.advance(10.0)
	assert_false(_screen.is_revealing())
	assert_eq(_screen.gold_text(), "+%d" % _run.last_spoils.gold)
	await _click(_screen.continue_button())
	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])


## S5: a click during the reveal ends it at once.
func test_a_click_during_the_reveal_ends_it() -> void:
	_win_an_encounter()
	await _open(true)
	_screen.advance(0.2)
	assert_true(_screen.is_revealing())

	await _click(_screen.window())

	assert_false(_screen.is_revealing())
	assert_eq(_screen.gold_text(), "+%d" % _run.last_spoils.gold)
	for face: CardFace in _screen.card_faces():
		assert_true(face.is_visible_in_tree(), "every card is face up")
	assert_eq(_went_to, [] as Array[String], "the click only ends the reveal")


## S6: Continue opens the Stage Map, whose Run Bar shows the gold paid.
func test_continue_opens_the_stage_map_with_the_gold() -> void:
	_win_an_encounter()
	var paid: int = _run.last_spoils.gold
	await _open()

	await _click(_screen.continue_button())

	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	var map: StageMapScreen = StageMapScreen.new()
	map.starts_itself = false
	add_child_autofree(map)
	map.size = SCREEN
	map.set_process(false)
	map.begin(_run)
	assert_eq(map.run_bar().gold_text(), str(paid))


## S6: after a Boss before the fifth, Continue opens the next Tier's Stage Intro
## (milestone 19), its Stage entered.
func test_after_a_boss_continue_opens_the_next_tiers_stage_intro() -> void:
	_beat_the_boss()
	await _open()

	await _click(_screen.continue_button())

	assert_eq(_went_to, [Screens.STAGE_INTRO] as Array[String])
	assert_eq(_run.stage_visit.stage.tier, 2)


## S7: the ground is the Stage Intro's: the Stage's own color, or the slate.
func test_the_ground_is_the_stage_intros() -> void:
	_win_an_encounter()
	await _open()

	assert_eq(_screen.ground_color(), StageIntro.ground_of(_run.stage_visit.stage))


## S8: --spoils (with --run-seed=, --stage= and --rank=) opens the Spoils screen of a debug
## run's win at that Rank.
func test_the_flag_wins_at_the_rank_asked_for() -> void:
	for rank: String in ["lesser", "elite", "boss"]:
		# Run Seed 2's red Stage has Elites (7's has none).
		var run: Run = SpoilsScreen.debug_run_from(["--spoils", "--run-seed=2", "--stage=red", "--rank=" + rank])
		assert_not_null(run.last_spoils, rank)
		assert_eq(run.stage_visit.stage.backdrop(), "red")
		assert_eq(run.stage_visit.node().kind, SpoilsScreen.RANKS[rank], rank)
	assert_eq(SpoilsScreen.FLAG, "--spoils")


## S8: where the Stage has no Node of the Rank asked for, the flag wins at the Boss.
func test_the_flag_wins_at_the_boss_when_no_node_of_the_rank_lies_ahead() -> void:
	var run: Run = SpoilsScreen.debug_run_from(["--spoils", "--run-seed=7", "--stage=red", "--rank=elite"])
	assert_eq(run.stage_visit.node().kind, StageMap.Kind.BOSS)
	assert_not_null(run.last_spoils)


## A real click on the middle of [param target], through the input pipeline.
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
