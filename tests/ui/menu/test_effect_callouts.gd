extends GutTest
## The Effect Callouts: on the frame the Menu Soldier first flashes each Effect Animation's
## color, its words appear just outside his square, beside or above his upper half, in the
## flash's color. They float straight off from him for two seconds, slowing, wiggling across
## their way and rocking a little, fading in over the flash and out to nothing; then they are
## gone. None comes with an effect's other flashes.

const STEP: float = 1.0 / 60.0
const SCREENS: Array[Vector2] = [Vector2(1920, 1080), Vector2(1280, 720)]
const SEEDS: int = 12
## How many effects each flight is flown for.
const EFFECTS: int = 4
## The main menu's window.
const WINDOW_SIZE: Vector2 = Vector2(408, 471)
const WORDS: Dictionary[String, String] = {
	"boost": "+1/+1",
	"lifelink": "Lifelink",
	"deathtouch": "Deathtouch",
	"flying": "Flying",
	"reach": "Reach",
	"vigilance": "Vigilance",
	"haste": "Haste",
	"defender": "Defender",
	"first_strike": "First strike",
	"double_strike": "Double strike",
	"trample": "Trample",
	"indestructible": "Indestructible",
	"protection": "Protection",
	"menace": "Menace",
}

## Every flight flown, for each seed on each screen: its ground, the frames he first flashed
## each effect on, how many flashes he began in all, and every callout seen, each with the
## frame it appeared on and every frame it was shown.
var _flights: Array[Dictionary] = []


func before_all() -> void:
	for screen: Vector2 in SCREENS:
		for flown: int in SEEDS:
			_flights.append(_fly(flown, screen))


func test_each_effect_has_the_words_cards_print_for_it() -> void:
	assert_eq(SoldierAnimations.WORDS.size(), SoldierAnimations.EFFECTS.size(), "one for each effect")
	for effect: String in SoldierAnimations.EFFECTS:
		assert_eq(SoldierAnimations.words_of(effect), WORDS[effect], effect)


func test_one_appears_on_the_frame_he_first_flashes_each_effect_and_on_no_other_flash() -> void:
	for flight: Dictionary in _flights:
		assert_eq(flight.callouts.size(), flight.first_flashes.size(), "one for each effect")
		for at: int in flight.callouts.size():
			var seen: Dictionary = flight.callouts[at]
			assert_eq(seen.appeared, flight.first_flashes[at].frame, "on the frame of his first flash")
			assert_eq(seen.callout.words(), SoldierAnimations.words_of(flight.first_flashes[at].effect))
		# Every effect but the last, which the flight stops partway through, flashed on its way
		# out too.
		assert_gte(flight.flashes, flight.first_flashes.size() * 2 - 1, "his other flashes brought none")


func test_it_is_in_its_flashs_color_at_most_three_quarters_strong() -> void:
	for flight: Dictionary in _flights:
		for at: int in flight.callouts.size():
			var seen: Dictionary = flight.callouts[at]
			var strongest: float = 0.0
			assert_eq(seen.callout.color(), SoldierAnimations.color_of(flight.first_flashes[at].effect))
			for frame: Dictionary in seen.frames:
				strongest = maxf(strongest, frame.opacity)
			assert_between(strongest, 0.7, EffectCallout.STRENGTH, "ghostly")


func test_it_keeps_clear_of_him_and_inside_the_screen_for_its_whole_flight() -> void:
	for flight: Dictionary in _flights:
		var inside: Rect2 = flight.screen.grow(-EffectCallout.MARGIN)
		for seen: Dictionary in flight.callouts:
			for frame: Dictionary in seen.frames:
				assert_true(inside.encloses(frame.bounds), "%s on the screen" % frame.bounds)
				assert_false(frame.bounds.intersects(flight.square), "%s clear of him" % frame.bounds)


func test_it_appears_just_outside_him_beside_or_above_his_upper_half() -> void:
	var above: Array[int] = [0, 0]
	var beside: Array[int] = [0, 0]
	for flight: Dictionary in _flights:
		var square: Rect2 = flight.square
		var big: int = 0 if flight.screen.size == SCREENS[0] else 1
		for seen: Dictionary in flight.callouts:
			var rect: Rect2 = seen.callout.drawn_rect(square, 0.0)
			var gap: float = maxf(maxf(square.position.x - rect.end.x, rect.position.x - square.end.x),
					square.position.y - rect.end.y)
			assert_between(gap, EffectCallout.GAP - 1.0, EffectCallout.GAP + 1.0, "just outside his square")
			assert_lte(rect.get_center().y, EffectCallout.upper_middle(square).y + 1.0, "level with his upper half or above")
			if rect.end.y <= square.position.y:
				above[big] += 1
			else:
				beside[big] += 1
	assert_gt(above[0], 0, "some above him on a big screen")
	assert_gt(beside[0], 0, "and some beside him")
	assert_eq(above[1], 0, "none above him at the smallest, where his head is at the screen's top")


func test_it_floats_straight_away_from_his_upper_half_slowing() -> void:
	for flight: Dictionary in _flights:
		for seen: Dictionary in flight.callouts:
			var callout: EffectCallout = seen.callout
			var away: Vector2 = callout.direction()
			var start: Vector2 = callout.middle(flight.square, 0.0)
			assert_almost_eq((start - EffectCallout.upper_middle(flight.square)).angle_to(away), 0.0, 0.001,
					"out from his upper half's middle")
			var gone: float = 0.0
			var speed: float = INF
			for step: int in range(1, 21):
				var along: float = (callout.middle(flight.square, step * 0.1) - start).dot(away)
				assert_lt(along - gone, speed, "slowing")
				speed = along - gone
				gone = along
			assert_almost_eq(gone, EffectCallout.DRIFT, 0.01, "%d px in two seconds" % EffectCallout.DRIFT)


func test_it_wiggles_across_its_way_and_rocks_back_and_forth_a_little() -> void:
	for flight: Dictionary in _flights:
		for seen: Dictionary in flight.callouts:
			var callout: EffectCallout = seen.callout
			var across: Vector2 = callout.direction().orthogonal()
			var start: Vector2 = callout.middle(flight.square, 0.0)
			var wiggles: Array[float] = []
			var rocks: Array[float] = []
			for step: int in range(0, 121):
				var age: float = step * EffectCallout.SECONDS / 120
				wiggles.append((callout.middle(flight.square, age) - start).dot(across))
				rocks.append(callout.angle(age))
			assert_almost_eq(wiggles[0], 0.0, 0.001, "still as it appears")
			assert_almost_eq(rocks[0], 0.0, 0.001, "level as it appears")
			for wiggle: float in wiggles:
				assert_lte(absf(wiggle), EffectCallout.SWAY + 0.001)
			for rock: float in rocks:
				assert_lte(absf(rock), EffectCallout.ROCK + 0.001)
			assert_gte(_turns(wiggles, 0.5), 3, "it wiggles")
			assert_gte(_turns(rocks, deg_to_rad(0.5)), 2, "it rocks back and forth")


func test_it_fades_in_over_his_flash_and_out_to_nothing_in_two_seconds_then_is_gone() -> void:
	var callout: EffectCallout = _flights[0].callouts[0].callout

	assert_eq(callout.opacity(0.0), 0.0)
	assert_gt(callout.opacity(EffectCallout.FADE_IN), 0.7, "there as the flash ends")
	assert_lt(callout.opacity(1.0), callout.opacity(0.5), "fading")
	assert_eq(callout.opacity(EffectCallout.SECONDS), 0.0)
	for flight: Dictionary in _flights:
		for seen: Dictionary in flight.callouts:
			assert_between(seen.frames.back().age, EffectCallout.SECONDS - STEP - 0.001, EffectCallout.SECONDS,
					"shown until it has faded out")


func test_the_same_seed_brings_the_same_callouts() -> void:
	var again: Dictionary = _fly(3, SCREENS[0])

	for at: int in again.callouts.size():
		assert_eq(again.callouts[at].frames.size(), _flights[3].callouts[at].frames.size())
		for frame: int in again.callouts[at].frames.size():
			assert_eq(again.callouts[at].frames[frame].rect, _flights[3].callouts[at].frames[frame].rect)


func test_it_goes_with_him_if_the_screen_is_resized() -> void:
	var sequence: SoldierSequence = SoldierSequence.new(_random(5))
	var callouts: EffectCallouts = EffectCallouts.new(sequence, _random(1005))
	callouts.set_ground(_square(SCREENS[0]), Rect2(Vector2.ZERO, SCREENS[0]))
	sequence.advance(sequence.seconds_until_flash() + 0.5)
	var callout: EffectCallout = callouts.shown()[0]
	var before: Vector2 = callout.middle(callouts.square(), callouts.age_of(callout))

	callouts.set_ground(_square(SCREENS[1]), Rect2(Vector2.ZERO, SCREENS[1]))

	var moved: Vector2 = _square(SCREENS[1]).position - _square(SCREENS[0]).position
	assert_eq(callouts.square(), _square(SCREENS[1]))
	assert_almost_eq(callout.middle(callouts.square(), callouts.age_of(callout)), before + moved, Vector2.ONE * 0.001)


func test_none_appears_before_it_knows_where_he_stands() -> void:
	var sequence: SoldierSequence = SoldierSequence.new(_random(5))
	var callouts: EffectCallouts = EffectCallouts.new(sequence, _random(1005))

	sequence.advance(sequence.seconds_until_flash() + 0.5)

	assert_eq(callouts.shown().size(), 0)


## A flight with [param seed] on a screen of [param screen]'s size, flown until [constant EFFECTS]
## effects' callouts have come and gone, each frame recorded.
func _fly(seed: int, screen: Vector2) -> Dictionary:
	var sequence: SoldierSequence = SoldierSequence.new(_random(seed))
	var callouts: EffectCallouts = EffectCallouts.new(sequence, _random(seed + 1000))
	var square: Rect2 = _square(screen)
	callouts.set_ground(square, Rect2(Vector2.ZERO, screen))
	var frame: Array[int] = [0]
	var coming: Array[String] = [sequence.next_effect()]
	var first_flashes: Array[Dictionary] = []
	sequence.next_effect_changed.connect(func(next: String) -> void:
		first_flashes.append({"frame": frame[0], "effect": coming[0]})
		coming[0] = next)
	var flashes: int = 0
	var showing: String = sequence.frame()
	var seen: Dictionary = {}
	var recorded: Array[Dictionary] = []
	while first_flashes.size() < EFFECTS or (frame[0] - first_flashes.back().frame) * STEP < EffectCallout.SECONDS + 0.5:
		frame[0] += 1
		sequence.advance(STEP)
		if sequence.frame() != showing and SoldierAnimations.FLASH_COLORS.has(sequence.frame()):
			flashes += 1
		showing = sequence.frame()
		for callout: EffectCallout in callouts.shown():
			if not seen.has(callout):
				seen[callout] = {"callout": callout, "appeared": frame[0], "frames": []}
				recorded.append(seen[callout])
			var age: float = callouts.age_of(callout)
			seen[callout].frames.append({
				"age": age,
				"rect": callout.drawn_rect(square, age),
				"bounds": callout.bounds(square, age),
				"opacity": callout.opacity(age),
			})
	return {
		"square": square,
		"screen": Rect2(Vector2.ZERO, screen),
		"first_flashes": first_flashes,
		"flashes": flashes,
		"callouts": recorded,
	}


## His square on a screen of [param size], as the main menu sets it: he on the window, the two
## centered together.
func _square(size: Vector2) -> Rect2:
	var his: float = MenuSoldier.SPRITE_SIZE * MenuSoldier.SCALE
	var top: float = floorf((size.y - (his - MenuSoldier.SCALE + WINDOW_SIZE.y)) / 2)
	return Rect2(Vector2(floorf((size.x - his) / 2), top), Vector2.ONE * his)


## How many times [param values] turn from one side of nothing to the other, counting only
## those further from it than [param least].
func _turns(values: Array[float], least: float) -> int:
	var turns: int = 0
	var side: float = 0.0
	for value: float in values:
		if absf(value) <= least:
			continue
		if side != 0.0 and signf(value) != side:
			turns += 1
		side = signf(value)
	return turns


func _random(seed: int) -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed
	return random
