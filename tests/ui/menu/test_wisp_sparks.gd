extends GutTest
## The Wisp Sparks: the Wisp leaves a trail of sparks wherever it goes, each in the Wisp's
## color as it is emitted, flying out of its middle at a random angle all the way round,
## drifting a little off straight, with none of the Wisp's own motion, and falling as it
## fades out. One that falls onto the main menu's
## window comes to rest on its top, on the step of a stepped corner, and fades out there;
## one that misses falls on past it.

const WINDOW: Rect2 = Rect2(500, 300, 408, 460)
const HALF: float = WispSparks.SIZE / 2
const STEP: float = 1.0 / 60.0

var _random: RandomNumberGenerator


func before_each() -> void:
	_random = RandomNumberGenerator.new()
	_random.seed = 7


func test_the_wisp_trails_sparks_as_it_goes() -> void:
	var sparks: WispSparks = WispSparks.new(_random)

	for frame: int in 60:
		sparks.trail(STEP, Vector2(200, 100 + frame), Color.RED, 1.0)

	assert_almost_eq(float(sparks.sparks().size()), WispSparks.PER_SECOND, 1.0, "so many a second")


func test_each_spark_appears_in_the_wisps_middle_flying_out_of_it_and_drifting() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	var middle: Vector2 = Vector2(200, 100)
	var speeds: float = 0.0

	sparks.trail(20.0, middle, Color.RED, 1.0)

	var all: Array[WispSparks.Spark] = sparks.sparks()
	for spark: WispSparks.Spark in all:
		assert_eq(spark.position, middle, "in its middle")
		assert_lte(spark.velocity.length(), WispSparks.SPEED.y + WispSparks.DRIFT + 0.01, "no faster than both together")
		speeds += spark.velocity.length()
	assert_between(speeds / all.size(), WispSparks.SPEED.x, WispSparks.SPEED.y + WispSparks.DRIFT / 2, "flying out, on the whole")


func test_sparks_fly_out_all_the_way_round_the_wisp() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	var eighths: Array[int] = []

	sparks.trail(20.0, Vector2(200, 100), Color.RED, 1.0)

	for spark: WispSparks.Spark in sparks.sparks():
		var eighth: int = posmod(floori(spark.velocity.angle() / (TAU / 8)), 8)
		if not eighths.has(eighth):
			eighths.append(eighth)
	assert_eq(eighths.size(), 8, "every way out, up and down and to either side")


func test_sparks_have_none_of_the_wisps_motion() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	var moving: Vector2 = Vector2(200, 100)
	var together: Vector2 = Vector2.ZERO

	for frame: int in 60 * 20:
		moving += Vector2(WispFlight.TOP_SPEED * STEP, 0)
		sparks.trail(STEP, moving, Color.RED, 1.0)

	for spark: WispSparks.Spark in sparks.sparks():
		together += spark.velocity
	var count: int = sparks.sparks().size()
	assert_gt(count, 300)
	assert_lt((together / count).length(), WispSparks.SPEED.x / 2, "no one way more than another, the Wisp's least of all")


func test_a_spark_keeps_the_color_the_wisp_was_as_it_was_emitted() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	sparks.emit(Vector2(200, 100), Color.RED, 1.0)
	sparks.emit(Vector2(200, 100), Color.BLUE, 1.0)

	_advance(sparks, 0.5, Rect2())

	assert_eq(sparks.sparks()[0].color, Color.RED)
	assert_eq(sparks.sparks()[1].color, Color.BLUE)


func test_it_falls_as_it_fades_out_and_is_gone_once_faded() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	sparks.emit(Vector2(200, 100), Color.RED, 1.0)
	var spark: WispSparks.Spark = sparks.sparks()[0]
	var faded: float = spark.opacity()
	var falling: float = spark.velocity.y
	var highest: float = spark.position.y

	for frame: int in int(WispSparks.LIFE.x / STEP) - 1:
		sparks.advance(STEP, Rect2())
		assert_lt(spark.opacity(), faded, "fading all the while")
		faded = spark.opacity()
		assert_gt(spark.velocity.y, falling, "falling ever faster")
		falling = spark.velocity.y
		highest = minf(highest, spark.position.y)

	assert_gt(spark.velocity.y, 0.0, "falling by the time it has faded")
	assert_gt(spark.position.y, highest, "down from the highest it flew")
	_advance(sparks, WispSparks.LIFE.y, Rect2())
	assert_eq(sparks.sparks().size(), 0, "gone once faded out")


func test_one_emitted_as_the_wisp_fades_in_is_as_faint_as_the_wisp() -> void:
	var sparks: WispSparks = WispSparks.new(_random)

	sparks.emit(Vector2(200, 100), Color.RED, 0.25)

	assert_almost_eq(sparks.sparks()[0].opacity(), 0.25, 0.001)


func test_one_falling_onto_the_window_rests_on_its_top_and_fades_out_there() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	for spark: int in 30:
		sparks.emit(Vector2(WINDOW.get_center().x, WINDOW.position.y - 24), Color.RED, 1.0)
	var all: Array[WispSparks.Spark] = _heading_down(sparks)

	_advance(sparks, WispSparks.LIFE.x - STEP * 3, WINDOW)

	var resting: Array[Vector2] = []
	var faded: Array[float] = []
	for spark: WispSparks.Spark in all:
		assert_true(spark.is_landed, "landed")
		assert_eq(spark.drawn_rect().end.y, WINDOW.position.y, "resting on the window's top")
		resting.append(spark.position)
		faded.append(spark.opacity())
	sparks.advance(STEP, WINDOW)
	for at: int in all.size():
		assert_eq(all[at].position, resting[at], "and staying there")
		assert_lt(all[at].opacity(), faded[at], "fading out")
	_advance(sparks, WispSparks.LIFE.y, WINDOW)
	assert_eq(sparks.sparks().size(), 0, "gone once faded out")


func test_one_beside_the_window_falls_on_past_its_top() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	var reach: float = (WispSparks.SPEED.y + WispSparks.DRIFT) * WispSparks.LIFE.y + HALF + 1.0
	for spark: int in 30:
		sparks.emit(Vector2(WINDOW.position.x - reach, WINDOW.position.y - 24), Color.RED, 1.0)
	var all: Array[WispSparks.Spark] = _heading_down(sparks)

	_advance(sparks, WispSparks.LIFE.x - STEP, WINDOW)

	for spark: WispSparks.Spark in all:
		assert_false(spark.is_landed)
		assert_gt(spark.position.y, WINDOW.position.y, "below the window's top")


func test_one_falling_down_beside_the_window_never_drifts_onto_it() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	for spark: int in 30:
		sparks.emit(Vector2(WINDOW.end.x + HALF + 1, WINDOW.position.y + 40), Color.RED, 1.0)
	var all: Array[WispSparks.Spark] = sparks.sparks().duplicate()

	for frame: int in int(WispSparks.LIFE.x / STEP) - 1:
		sparks.advance(STEP, WINDOW)
		for spark: WispSparks.Spark in all:
			assert_false(spark.drawn_rect().intersects(WINDOW), "off the window's side")


func test_the_windows_top_is_lower_on_its_stepped_corners() -> void:
	var band: float = WindowLook.RIM_BAND
	var deepest: float = WindowLook.CORNER_STEPS * band

	assert_eq(WispSparks.top_at(WINDOW, WINDOW.get_center().x), WINDOW.position.y, "level across the middle")
	assert_eq(WispSparks.top_at(WINDOW, WINDOW.position.x + deepest), WINDOW.position.y, "past the corner")
	assert_eq(WispSparks.top_at(WINDOW, WINDOW.position.x), WINDOW.position.y + deepest, "lowest at the very edge")
	assert_eq(WispSparks.top_at(WINDOW, WINDOW.position.x + band), WINDOW.position.y + deepest - band, "a step up")
	assert_eq(WispSparks.top_at(WINDOW, WINDOW.end.x - 1), WINDOW.position.y + deepest, "on either side")
	assert_eq(WispSparks.top_at(WINDOW, WINDOW.position.x - 1), INF, "and none off the window")


func test_one_falling_onto_a_corner_rests_on_its_step() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	sparks.emit(Vector2(WINDOW.position.x + 1, WINDOW.position.y - 24), Color.RED, 1.0)
	var spark: WispSparks.Spark = sparks.sparks()[0]
	spark.position = Vector2(WINDOW.position.x + 1, WINDOW.position.y - 24)
	spark.velocity = Vector2.ZERO

	_advance(sparks, WispSparks.LIFE.x - STEP, WINDOW)

	assert_true(spark.is_landed)
	var highest: float = WispSparks.top_at(WINDOW, spark.position.x + HALF - 1)
	assert_eq(spark.drawn_rect().end.y, highest, "on the highest step under it")


func test_a_spark_is_drawn_one_wisp_pixel_square_on_whole_pixels() -> void:
	var sparks: WispSparks = WispSparks.new(_random)
	sparks.trail(1.0, Vector2(200.3, 100.6), Color.RED, 1.0)
	_advance(sparks, 0.37, Rect2())

	assert_eq(WispSparks.SIZE, float(MenuSoldier.SCALE), "on the Wisp's grid")
	for spark: WispSparks.Spark in sparks.sparks():
		var drawn: Rect2 = spark.drawn_rect()
		assert_eq(drawn.size, Vector2.ONE * WispSparks.SIZE)
		assert_eq(drawn.position, drawn.position.round(), "on whole pixels")


## Every spark of [param sparks], each turned to fly out downward if it was flying upward,
## so that it falls onto or past the window well within its life.
func _heading_down(sparks: WispSparks) -> Array[WispSparks.Spark]:
	for spark: WispSparks.Spark in sparks.sparks():
		spark.velocity.y = absf(spark.velocity.y)
	return sparks.sparks().duplicate()


func _advance(sparks: WispSparks, seconds: float, window: Rect2) -> void:
	for frame: int in floori(seconds / STEP):
		sparks.advance(STEP, window)
