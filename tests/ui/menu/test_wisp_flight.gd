extends GutTest
## The Wisp's flight: it reaches the Menu Soldier's chest on the frame he first flashes each
## Effect Animation's color, from the left and the right in turns, on a lazy, smooth route that
## stays on the screen, off the window and above its bottom. It bobs on the way, turns to the
## next effect's color after each touch, and fades in as the menu opens.

const STEP: float = 1.0 / 60.0
const SCREENS: Array[Vector2] = [Vector2(1920, 1080), Vector2(1280, 720)]
const SEEDS: int = 8
const LOOPS: int = 4
## About the size of the main menu's window.
const WINDOW_SIZE: Vector2 = Vector2(408, 460)
## Speeds and turns are measured over this many frames, so that they are the route's own and
## not the steps between the points it is drawn through.
const SPAN: int = 6

## Every flight flown, for each seed on each screen: its ground and its loops. A loop is the
## side it wandered on and its frames, each with where the Wisp was and its bob; every loop
## after the first starts on the frame of a touch.
var _flights: Array[Dictionary] = []


func before_all() -> void:
	for screen: Vector2 in SCREENS:
		for flown: int in SEEDS:
			_flights.append(_fly(flown, screen, LOOPS))


func test_it_touches_his_chest_on_the_frame_he_first_flashes_each_effect() -> void:
	for flight: Dictionary in _flights:
		var touch: Vector2 = flight.ground.touch
		for loop: int in range(1, flight.loops.size()):
			var at_touch: Vector2 = flight.loops[loop].frames[0].position
			var before: Vector2 = flight.loops[loop - 1].frames.back().position
			assert_lt(at_touch.distance_to(touch), 0.01, "on his chest as he flashes")
			assert_lt(before.distance_to(touch), 2.0, "coming to him, not jumping onto him")


func test_it_comes_from_the_left_and_the_right_in_turns() -> void:
	for flight: Dictionary in _flights:
		var touch: Vector2 = flight.ground.touch
		var window: Rect2 = flight.ground.window
		for loop: int in flight.loops.size() - 1:
			var side: int = flight.loops[loop].side
			var farthest: float = 0.0
			for frame: Dictionary in flight.loops[loop].frames:
				var out: float = side * (frame.position.x - touch.x)
				assert_gt(out, -0.5, "on its own side of him")
				farthest = maxf(farthest, out)
			assert_gt(farthest, window.size.x / 2 + WispFlight.SIZE, "out beside the window")
			if loop > 0:
				assert_eq(side, -flight.loops[loop - 1].side, "the other side from last time")


func test_it_stays_on_the_screen_off_the_window_and_above_its_bottom() -> void:
	for flight: Dictionary in _flights:
		var screen: Rect2 = flight.ground.screen.grow(-WispFlight.MARGIN)
		var window: Rect2 = flight.ground.window
		for loop: Dictionary in flight.loops:
			for frame: Dictionary in loop.frames:
				var wisp: Rect2 = _rect(frame.position)
				assert_true(screen.encloses(wisp), "inside the screen's margin at %s" % wisp)
				assert_false(window.intersects(wisp), "off the window at %s" % wisp)
				assert_lte(wisp.end.y, window.end.y, "above the window's bottom")


func test_its_route_is_smooth_and_it_never_stops() -> void:
	for flight: Dictionary in _flights:
		var route: Array[Vector2] = _route(flight)
		var speeds: Array[float] = _speeds(route)
		for at: int in speeds.size():
			assert_gt(speeds[at], 20.0, "always moving")
			assert_lt(speeds[at], WispFlight.TOP_SPEED + 1.0, "never rushing")
			if at > 0:
				assert_lt(absf(speeds[at] - speeds[at - 1]) / (SPAN * STEP), 300.0, "speeding up and slowing gently")
		for at: int in range(SPAN * 2, route.size() - SPAN * 2, SPAN):
			var turn: float = _turn_radius(route[at - SPAN * 2], route[at], route[at + SPAN * 2])
			assert_gt(turn, WispFlight.SIZE / 2, "no sharp turn at %s" % route[at])


func test_it_is_slowest_near_its_far_turn() -> void:
	for flight: Dictionary in _flights:
		var touch: Vector2 = flight.ground.touch
		for loop: int in range(1, flight.loops.size() - 1):
			var route: Array[Vector2] = []
			for frame: Dictionary in flight.loops[loop].frames:
				route.append(frame.position - frame.bob)
			var speeds: Array[float] = _speeds(route)
			var slowest: int = speeds.find(speeds.min())
			var farthest: Vector2 = route[0]
			for point: Vector2 in route:
				if point.distance_to(touch) > farthest.distance_to(touch):
					farthest = point
			assert_lt(route[slowest * SPAN + SPAN / 2].distance_to(farthest), 64.0, "slowest where it turns back")


func test_it_bobs_a_little_and_not_at_all_as_it_touches_him() -> void:
	var most: float = 0.0
	for flight: Dictionary in _flights:
		for loop: int in flight.loops.size():
			for frame: Dictionary in flight.loops[loop].frames:
				assert_lte(frame.bob.length(), WispFlight.BOB + 0.001)
				most = maxf(most, frame.bob.length())
			if loop > 0:
				assert_lt(flight.loops[loop].frames[0].bob.length(), 0.001, "still as it touches him")
	assert_gt(most, WispFlight.BOB / 2, "it does bob")


func test_it_carries_the_effects_color_and_turns_to_the_next_after_the_touch() -> void:
	var sequence: SoldierSequence = SoldierSequence.new(_random(3))
	var flight: WispFlight = _flight_over(sequence, 3, SCREENS[0])
	var bringing: Color = sequence.next_color()

	assert_eq(flight.color(), bringing, "the first effect's color, from the first moment")
	_advance(sequence, sequence.seconds_until_flash() - 0.5)
	assert_eq(flight.color(), bringing, "and up to the touch")
	_advance(sequence, 0.501)
	var next: Color = sequence.next_color()
	assert_almost_eq(flight.blend(), 0.0, 0.001, "still the color it brought as it touches him")
	_advance(sequence, WispFlight.COLOR_SECONDS / 2)
	assert_almost_eq(flight.blend(), 0.5, 0.001, "halfway there")
	assert_true(flight.color().is_equal_approx(bringing.lerp(next, 0.5)))
	_advance(sequence, WispFlight.COLOR_SECONDS / 2)
	assert_eq(flight.color(), next, "the next effect's color, five seconds on")
	assert_eq(flight.flash_to(), SoldierAnimations.flash_of(sequence.next_effect()))


func test_it_fades_in_as_the_menu_opens_and_first_touches_him_at_his_first_flash() -> void:
	var sequence: SoldierSequence = SoldierSequence.new(_random(4))
	var flight: WispFlight = _flight_over(sequence, 4, SCREENS[0])

	assert_almost_eq(sequence.seconds_until_flash(), 7.6, 0.001, "his first flash")
	assert_eq(flight.opacity(), 0.0, "unseen as the menu opens")
	_advance(sequence, WispFlight.FADE_SECONDS / 2)
	assert_almost_eq(flight.opacity(), 0.5, 0.001)
	_advance(sequence, WispFlight.FADE_SECONDS / 2)
	assert_eq(flight.opacity(), 1.0, "all there after two seconds")
	assert_gt(flight.position().distance_to(_ground(SCREENS[0]).touch), 200.0, "away off on its side")


func test_the_same_seed_flies_the_same_flight() -> void:
	var first: Dictionary = _fly(11, SCREENS[0], 2)
	var again: Dictionary = _fly(11, SCREENS[0], 2)
	var other: Dictionary = _fly(12, SCREENS[0], 2)

	assert_eq_deep(again, first)
	assert_ne(str(other), str(first), "another seed, another route")


func test_it_still_reaches_him_when_the_screen_is_resized_on_the_way() -> void:
	var sequence: SoldierSequence = SoldierSequence.new(_random(5))
	var flight: WispFlight = _flight_over(sequence, 5, SCREENS[0])
	_advance(sequence, sequence.seconds_until_flash() + 0.001)
	_advance(sequence, 6.0)

	var smaller: Dictionary = _ground(SCREENS[1])
	flight.set_ground(smaller.touch, smaller.window, smaller.screen)
	var screen: Rect2 = smaller.screen.grow(-WispFlight.MARGIN)
	while sequence.seconds_until_flash() > STEP:
		_advance(sequence, STEP)
		assert_true(screen.encloses(_rect(flight.position())), "on the smaller screen")
	_advance(sequence, STEP)

	assert_lt(flight.position().distance_to(smaller.touch), 0.01, "on his chest where he now stands")


func test_it_waits_for_somewhere_to_fly() -> void:
	var flight: WispFlight = WispFlight.new(SoldierSequence.new(_random(6)), _random(6))

	assert_false(flight.is_flying(), "no route before it knows where he stands")


## [param loops] loops of a flight with [param seed] on a screen of [param screen]'s size,
## each frame recorded.
func _fly(seed: int, screen: Vector2, loops: int) -> Dictionary:
	var sequence: SoldierSequence = SoldierSequence.new(_random(seed))
	var flight: WispFlight = _flight_over(sequence, seed, screen)
	var flown: Array[Dictionary] = [{"side": flight.side(), "frames": []}]
	var touched: Array[bool] = [false]
	sequence.next_effect_changed.connect(func(_effect: String) -> void: touched[0] = true)
	while flown.size() <= loops:
		touched[0] = false
		sequence.advance(STEP)
		if touched[0]:
			flown.append({"side": flight.side(), "frames": []})
		flown.back().frames.append({"position": flight.position(), "bob": flight.bob()})
	return {"ground": _ground(screen), "loops": flown}


func _flight_over(sequence: SoldierSequence, seed: int, screen: Vector2) -> WispFlight:
	var flight: WispFlight = WispFlight.new(sequence, _random(seed + 1000))
	var ground: Dictionary = _ground(screen)
	flight.set_ground(ground.touch, ground.window, ground.screen)
	return flight


## Where he stands and the window lies on a screen of [param size], as the main menu sets them:
## he on the window, the two centered together.
func _ground(size: Vector2) -> Dictionary:
	var his: float = MenuSoldier.SPRITE_SIZE * MenuSoldier.SCALE
	var top: float = floorf((size.y - (his - MenuSoldier.SCALE + WINDOW_SIZE.y)) / 2)
	var window: Rect2 = Rect2(Vector2(floorf((size.x - WINDOW_SIZE.x) / 2), top + his - MenuSoldier.SCALE), WINDOW_SIZE)
	var left: float = window.get_center().x - his / 2
	return {
		"touch": Vector2(left, top) + MenuSoldier.CHEST * MenuSoldier.SCALE,
		"window": window,
		"screen": Rect2(Vector2.ZERO, size),
	}


func _advance(sequence: SoldierSequence, seconds: float) -> void:
	sequence.advance(seconds)


## Every frame of [param flight]'s route, without its bob, from first to last.
func _route(flight: Dictionary) -> Array[Vector2]:
	var route: Array[Vector2] = []
	for loop: Dictionary in flight.loops:
		for frame: Dictionary in loop.frames:
			route.append(frame.position - frame.bob)
	return route


## How fast [param route] goes over each run of [constant SPAN] frames, in pixels a second.
func _speeds(route: Array[Vector2]) -> Array[float]:
	var speeds: Array[float] = []
	for at: int in range(0, route.size() - SPAN, SPAN):
		speeds.append(route[at].distance_to(route[at + SPAN]) / (SPAN * STEP))
	return speeds


## The radius of the circle through [param a], [param b] and [param c]: how tightly a route
## through them turns.
func _turn_radius(a: Vector2, b: Vector2, c: Vector2) -> float:
	var twice_area: float = absf((b - a).cross(c - a))
	if twice_area < 0.0001:
		return INF
	return a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * twice_area)


func _rect(middle: Vector2) -> Rect2:
	return Rect2(middle - Vector2.ONE * WispFlight.SIZE / 2, Vector2.ONE * WispFlight.SIZE)


func _random(seed: int) -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed
	return random
