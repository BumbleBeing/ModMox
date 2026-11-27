extends GutTest
## Milestone 24: the Potions the Hero holds between encounters, in place of the mock (A523).
## Every Potion held is the Hero's in each encounter, in the order held; one used there is
## gone afterwards, won or lost, and one not used stays. An encounter quit starts over, so
## its Potions come back.

const BIG_GULP: String = "res://content/potions/big_gulp.tres"
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"

var _big_gulp: MmCardDefinition
## A second kind of Potion, made in code.
var _tonic: MmCardDefinition


func before_each() -> void:
	RunFlow.clear()
	_big_gulp = load(BIG_GULP) as MmCardDefinition
	_tonic = _big_gulp.duplicate() as MmCardDefinition
	_tonic.name = "Test Tonic"


func after_each() -> void:
	RunFlow.clear()
	RunFlow.remembers_saves = false


func test_the_same_potion_held_twice_is_one_kind_with_a_count_of_two() -> void:
	var held: HeldPotions = HeldPotions.new()

	held.add(_big_gulp)
	held.add(_tonic)
	held.add(_big_gulp)

	assert_eq(held.kinds(), [_big_gulp, _tonic] as Array[MmCardDefinition])
	assert_eq(held.count_of(_big_gulp), 2)
	assert_eq(held.count_of(_tonic), 1)
	assert_eq(held.all(), [_big_gulp, _tonic, _big_gulp] as Array[MmCardDefinition])


## Those used are named by their places in all(), as the encounter was handed them.
func test_using_up_takes_the_potions_at_their_places() -> void:
	var held: HeldPotions = HeldPotions.new()
	held.add(_big_gulp)
	held.add(_tonic)
	held.add(_big_gulp)

	held.use_up([2, 1])

	assert_eq(held.all(), [_big_gulp] as Array[MmCardDefinition])


func test_using_up_nothing_changes_nothing() -> void:
	var held: HeldPotions = HeldPotions.new()
	held.add(_big_gulp)

	held.use_up([])

	assert_eq(held.all(), [_big_gulp] as Array[MmCardDefinition])


## The debug run holds two Big Gulps, as it holds the Mods and the Armor, to try them out.
func test_the_debug_run_holds_two_big_gulps() -> void:
	var run: Run = Run.debug(7)

	assert_eq(run.held_potions.all(), [_big_gulp, _big_gulp] as Array[MmCardDefinition])


## P1: every Potion held is the Hero's in an encounter, in the order held.
func test_every_potion_held_is_the_heros_in_an_encounter() -> void:
	var run: Run = Run.debug(7)
	run.held_potions.add(_tonic)

	var setup: MmPlayerSetup = run.hero_setup()

	assert_eq(setup.potions, [_big_gulp, _big_gulp, _tonic] as Array[MmCardDefinition])


## P1: the encounter the run leads to hands the Hero those Potions.
func test_the_runs_encounter_gives_the_hero_the_potions_held() -> void:
	var run: Run = _meeting_a_villain()

	var setup: MmEncounterSetup = EncounterRequest.for_run(run).setup()

	assert_eq(setup.hero.potions, [_big_gulp, _big_gulp] as Array[MmCardDefinition])


## P2: a Potion used in an encounter won is gone afterwards, and one not used stays.
func test_a_potion_used_in_an_encounter_won_is_gone_afterwards() -> void:
	var run: Run = _meeting_a_villain()
	run.held_potions.add(_tonic)

	RunFlow.finish_encounter(true, {"potions_used": [0]})

	assert_eq(run.held_potions.all(), [_big_gulp, _tonic] as Array[MmCardDefinition])


## P2: lost, it is gone all the same.
func test_a_potion_used_in_an_encounter_lost_is_gone_too() -> void:
	var run: Run = _meeting_a_villain()

	RunFlow.finish_encounter(false, {"potions_used": [1, 0]})

	assert_eq(run.held_potions.all(), [] as Array[MmCardDefinition])


## P2: an encounter where none was used leaves them all.
func test_potions_not_used_stay() -> void:
	var run: Run = _meeting_a_villain()

	RunFlow.finish_encounter(true, {"potions_used": []})

	assert_eq(run.held_potions.all(), [_big_gulp, _big_gulp] as Array[MmCardDefinition])


## P3: an encounter quit starts over on Continue, its Potions back, whatever it used.
func test_an_encounter_quit_gives_its_potions_back() -> void:
	RunFlow.remembers_saves = true
	var run: Run = _meeting_a_villain()
	RunFlow.arrive()
	RunFlow.begin_encounter()

	RunFlow.quit({"potions_used": [0, 1]})
	RunFlow.continue_run(RunFlow.last_save())

	assert_ne(RunFlow.run, run, "Continue loaded the snapshot.")
	assert_eq(RunFlow.run.held_potions.all(), [_big_gulp, _big_gulp] as Array[MmCardDefinition])


## A debug run on the Stage Map, standing on an encounter Node.
func _meeting_a_villain() -> Run:
	var run: Run = Run.debug(21, load(KITTY_KEEP) as StageDefinition)
	RunFlow.start(run)
	RunFlow.finish_intro()
	while not run.stage_visit.must_play():
		run.move_to(run.stage_visit.choices()[0])
	return run
