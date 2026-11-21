extends GutTest
## The Stage Intro (milestone 17): the Stage's name, its Tier Track (milestone 19,
## test_tier_track.gd), and its Boss; Continue opens the Stage Map.

var _run: Run
var _intro: StageIntro
var _went_to: Array[String] = []


func before_each() -> void:
	_went_to = []
	RunFlow.clear()
	_run = Run.debug(7)
	RunFlow.start(_run)


func after_each() -> void:
	RunFlow.clear()
	await wait_process_frames(2)


func _open() -> void:
	_intro = StageIntro.new()
	_intro.starts_itself = false
	_intro.navigate = func(scene: String) -> void: _went_to.append(scene)
	add_child_autofree(_intro)
	_intro.begin(_run)
	await wait_process_frames(1)


## S10: the Stage Intro shows the Stage and its Boss; its Tier is the Tier Track's
## (milestone 19), no longer in words.
func test_the_intro_names_the_stage_and_its_boss() -> void:
	await _open()
	var visit: StageVisit = _run.stage_visit

	assert_eq(_intro.texts(), [visit.stage.name, "Boss", visit.boss.name] as Array[String])


## S10: Continue opens the Stage Map.
func test_continue_opens_the_stage_map() -> void:
	await _open()

	_intro.button().pressed.emit()

	assert_eq(_went_to, [Screens.STAGE_MAP] as Array[String])
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_MAP)


func test_the_deckboxs_close_at_the_start_of_a_run_leads_here() -> void:
	assert_eq(RunFlow.back_from_deckbox, RunFlow.Screen.STAGE_INTRO)
	assert_true(ResourceLoader.exists(Screens.STAGE_INTRO))
	var scene: Node = (load(Screens.STAGE_INTRO) as PackedScene).instantiate()
	assert_true(scene is StageIntro)
	scene.free()


## ADR 0038: the Intro's ground is the Stage's own color.
func test_the_intro_is_drawn_in_the_stages_color() -> void:
	_run = Run.debug(7, load("res://content/stages/kitty_keep.tres") as StageDefinition)
	await _open()

	assert_eq(_intro.ground(), _run.stage_visit.stage.intro_color)
	assert_eq(_intro.text_color(), StageIntro.INK, "Kitty Keep's cream is light, so its text is dark.")


## ADR 0038: a Stage without a color keeps the slate.
func test_a_stage_without_a_color_keeps_the_slate() -> void:
	_run = Run.debug(7, load("res://content/stages/placeholder_red.tres") as StageDefinition)
	await _open()

	assert_eq(_intro.ground(), StageIntro.GROUND)
	assert_eq(_intro.text_color(), StageIntro.TEXT)
