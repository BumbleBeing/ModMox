extends GutTest
## The Tier Track on the Stage Intro (milestone 19, signed off as step 1 of
## prototypes/run_ends): five medallions where "Tier N" stood, each Stage played in its
## color, the one being entered lit, larger and in the Glow ring, those ahead empty, the
## middle one on the screen's center line whichever is lit.

const SCREEN: Vector2 = Vector2(1920, 1080)
const KITTY_KEEP: String = "res://content/stages/kitty_keep.tres"

var _intro: StageIntro


func before_each() -> void:
	RunFlow.clear()


func after_each() -> void:
	RunFlow.clear()
	await wait_process_frames(2)


func _open(run: Run) -> void:
	_intro = StageIntro.new()
	_intro.starts_itself = false
	_intro.navigate = func(_scene: String) -> void: pass
	add_child_autoqfree(_intro)
	_intro.size = SCREEN
	_intro.begin(run)
	await wait_process_frames(2)


## S1: the Stage Intro shows the Tier Track where "Tier N" stood.
func test_the_intro_shows_the_tier_track_in_place_of_the_tier_in_words() -> void:
	await _open(Run.debug(7, load(KITTY_KEEP) as StageDefinition))

	assert_not_null(_intro.tier_track())
	assert_false(_intro.texts().has("Tier 1"))


## S1: each Stage played shows its color, the one being entered is lit, those ahead empty.
func test_each_stage_played_shows_its_color_and_those_ahead_are_empty() -> void:
	var run: Run = Run.debug(7, load(KITTY_KEEP) as StageDefinition, 3)
	await _open(run)
	var played: Array[StageVisit] = run.stages_played()

	var shown: Array[String] = _intro.tier_track().medallions()

	assert_eq(shown, [played[0].stage.backdrop(), played[1].stage.backdrop(), played[2].stage.backdrop(),
		TierTrack.EMPTY, TierTrack.EMPTY] as Array[String])
	assert_eq(shown[0], "white", "Kitty Keep is white.")
	assert_eq(_intro.tier_track().lit_tier(), 3)


## S1: the one being entered is drawn larger, in the Glow ring.
func test_the_medallion_being_entered_is_larger_and_glows() -> void:
	await _open(Run.debug(7, null, 2))
	var track: TierTrack = _intro.tier_track()

	assert_eq(track.side_of(2), 32.0 * TierTrack.LIT_SCALE)
	assert_eq(track.side_of(1), 32.0 * TierTrack.SCALE)
	assert_eq(track.side_of(3), 32.0 * TierTrack.SCALE)
	assert_eq(TierTrack.LIT_SCALE * 2, TierTrack.SCALE * 3, "Half again as large.")
	assert_true(track.glows(2))
	assert_false(track.glows(1))


## The medallions are the six signed-off pictures, imported as pixel art.
func test_each_medallion_is_a_32_pixel_picture() -> void:
	for name: String in StageDefinition.BACKDROPS.values() + [TierTrack.EMPTY]:
		var picture: Texture2D = load(TierTrack.MEDALLIONS % name) as Texture2D
		assert_not_null(picture, name)
		assert_eq(picture.get_size(), Vector2(32, 32), name)


## S2: at every Tier the middle medallion and "Boss" stand on the screen's center line.
func test_the_middle_medallion_and_boss_stand_on_the_center_line_at_every_tier() -> void:
	for tier: int in range(1, Villain.TIERS + 1):
		await _open(Run.debug(7, null, tier))
		var track: TierTrack = _intro.tier_track()

		var middle: float = track.get_global_rect().position.x + track.center_of(3).x
		assert_almost_eq(middle, SCREEN.x / 2.0, 1.0, "The middle medallion at Tier %d" % tier)
		var boss: Label = _intro.label_of("Boss")
		assert_almost_eq(boss.get_global_rect().get_center().x, SCREEN.x / 2.0, 1.0, "Boss at Tier %d" % tier)
		remove_child(_intro)


## S2: the medallions stand evenly apart, whichever is lit.
func test_the_medallions_stand_evenly_apart() -> void:
	await _open(Run.debug(7, null, 2))
	var track: TierTrack = _intro.tier_track()

	for tier: int in range(1, Villain.TIERS):
		assert_almost_eq(track.center_of(tier + 1).x - track.center_of(tier).x, TierTrack.PITCH, 0.01)
	assert_eq(TierTrack.PITCH, 104.0)
