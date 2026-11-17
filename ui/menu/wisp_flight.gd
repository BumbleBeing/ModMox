class_name WispFlight
extends RefCounted
## The Wisp's flight about the main menu: where it is, in what color and how strongly it
## shows at any moment, worked out from the Menu Soldier's sequence so that it reaches his
## chest on the frame he first flashes each Effect Animation's color. After each touch it
## drifts on through him to the side of the window opposite the one it came from, wanders
## there lazily through two or three random points, slowest at its far turn, and comes back
## in time for the next. On the way it bobs a little in random directions, and it turns
## slowly to the next effect's color. Its first route is already under way when the menu
## opens, and it fades in.
##
## A route is planned at each touch for the time until the next, kept relative to where he
## stands so that it still reaches him if the screen is resized, and drawn again until it
## keeps to the screen, off the window and above its bottom, and turns and changes speed
## gently.

## The Wisp's width and height on the screen.
const SIZE: float = MenuWisp.SPRITE_SIZE * MenuSoldier.SCALE
## How far inside the screen's edges the Wisp always stays.
const MARGIN: float = 48.0
## How far its sides always stay from the window.
const CLEARANCE: float = 8.0
## The farthest it bobs from its route, and how long each bob takes, at least and at most.
const BOB: float = 16.0
const BOB_SECONDS: Vector2 = Vector2(1.0, 2.0)
## How long its bob takes to die away before a touch, and to start again after one.
const BOB_SETTLE: float = 1.5
## How fast it goes as it touches him, and how much slower than that at its far turn.
const TOUCH_SPEED: float = 90.0
const FAR_SLOWING: float = 0.7
## The fastest it may go, how quickly it may change speed, and how tightly it may turn.
const TOP_SPEED: float = 320.0
const STEEPEST_CHANGE: float = 240.0
const TIGHTEST_TURN: float = 32.0
## How long it takes to turn to the next effect's color after a touch, and to fade in.
const COLOR_SECONDS: float = 5.0
const FADE_SECONDS: float = 2.0
## How many random points a route passes through on the far side, at least and at most.
const FAR_POINTS: Vector2i = Vector2i(2, 3)
## How far past the window's side a route crosses over its corner, at least and at most,
## and how far above the window it keeps there.
const CORNER_REACH: Vector2 = Vector2(24.0, 160.0)
const CORNER_HEIGHT: float = 24.0
## How far in from the edges of where it may go the far side's points are put, so that the
## route curving round them stays inside.
const INSET: float = 40.0
const SAMPLES_PER_LEG: int = 40
const TRIES: int = 200

var _sequence: SoldierSequence
var _random: RandomNumberGenerator
## The bob's own generator, so that the routes do not depend on when the Wisp is looked at.
var _bob_random: RandomNumberGenerator
var _has_ground: bool = false
## His chest, the window and the screen, as last told.
var _touch: Vector2
var _window: Rect2
var _screen: Rect2
## The side it wanders on until the next touch: -1 left, 1 right.
var _side: int
## How many touches there have been; the first route is the one under way as the menu opens.
var _touches: int = 0
## How long this route takes, from the last touch to the next.
var _seconds: float
## How far into the first route the menu opened.
var _opened_at: float
## The route's points from his chest, and how long after the touch it passes each.
var _points: PackedVector2Array = PackedVector2Array()
var _times: PackedFloat64Array = PackedFloat64Array()
## The flash frame of the effect it brought last, and of the one it is bringing.
var _flash_from: String
var _flash_to: String
## The bob's clock at this route's start, and its next turns: where to and when.
var _bob_start: float
var _bob_keys: Array[Vector2] = []
var _bob_times: Array[float] = []


## A flight timed by [param sequence], making its random choices with [param random].
func _init(sequence: SoldierSequence, random: RandomNumberGenerator) -> void:
	_sequence = sequence
	_random = random
	_bob_random = RandomNumberGenerator.new()
	_bob_random.seed = random.randi()
	_side = -1 if random.randi_range(0, 1) == 0 else 1
	_flash_to = SoldierAnimations.flash_of(sequence.next_effect())
	_flash_from = _flash_to
	# The first route is a whole one, the menu opening partway through it.
	_seconds = maxf(SoldierAnimations.SECONDS * 2.0, sequence.seconds_until_flash())
	_opened_at = _seconds - sequence.seconds_until_flash()
	_bob_start = -_opened_at
	sequence.next_effect_changed.connect(_on_touch)


## Tells it where he is touched, [param touch], and where the window and the screen are on
## the screen. Its first route is planned the first time the window has a size.
func set_ground(touch: Vector2, window: Rect2, screen: Rect2) -> void:
	if window.size == Vector2.ZERO:
		return
	_touch = touch
	_window = window
	_screen = screen
	if not _has_ground:
		_has_ground = true
		_plan()


## Whether it has a route yet, which it has once it knows where he stands.
func is_flying() -> bool:
	return not _points.is_empty()


## The middle of the Wisp on the screen now.
func position() -> Vector2:
	if not is_flying():
		return Vector2.ZERO
	var box: Rect2 = _screen.grow(-(MARGIN + SIZE / 2))
	return (_touch + _route_at(_since_touch()) + bob()).clamp(box.position, box.end)


## How far it is bobbing off its route now: never at a touch.
func bob() -> Vector2:
	var since: float = _since_touch()
	var settled: float = smoothstep(0.0, BOB_SETTLE, minf(since, _seconds - since))
	return _bob_at(_bob_start + since) * settled


## The side it wanders on until the next touch: -1 left of the window, 1 right.
func side() -> int:
	return _side


## Its color now: the effect's it brought last, turning to the one it is bringing.
func color() -> Color:
	var turned: float = blend()
	if turned <= 0.0:
		return SoldierAnimations.FLASH_COLORS[_flash_from]
	if turned >= 1.0:
		return SoldierAnimations.FLASH_COLORS[_flash_to]
	return SoldierAnimations.FLASH_COLORS[_flash_from].lerp(SoldierAnimations.FLASH_COLORS[_flash_to], turned)


## The flash frame of the effect it brought last, whose color it is turning from.
func flash_from() -> String:
	return _flash_from


## The flash frame of the effect it is bringing, whose color it is turning to.
func flash_to() -> String:
	return _flash_to


## How far it has turned to [method flash_to]'s color, from 0 to 1.
func blend() -> float:
	if _touches == 0:
		return 0.0
	return smoothstep(0.0, COLOR_SECONDS, _since_touch())


## How strongly it shows, from 0 as the menu opens to 1 once it has faded in.
func opacity() -> float:
	if _touches > 0:
		return 1.0
	return clampf((_since_touch() - _opened_at) / FADE_SECONDS, 0.0, 1.0)


func _on_touch(_effect: String) -> void:
	_bob_start += _seconds
	_touches += 1
	_side = -_side
	_flash_from = _flash_to
	_flash_to = SoldierAnimations.flash_of(_sequence.next_effect())
	_seconds = _sequence.seconds_until_flash()
	if _has_ground:
		_plan()


## How long since the last touch, on this route's clock.
func _since_touch() -> float:
	return clampf(_seconds - _sequence.seconds_until_flash(), 0.0, _seconds)


## Where the route is [param since] seconds after the touch, from his chest.
func _route_at(since: float) -> Vector2:
	var after: int = clampi(_times.bsearch(since) - 1, 0, _times.size() - 2)
	var span: float = _times[after + 1] - _times[after]
	var through: float = 0.0 if span <= 0.0 else clampf((since - _times[after]) / span, 0.0, 1.0)
	return _points[after].lerp(_points[after + 1], through)


## Draws routes until one keeps to every rule. Should none, the last one drawn is flown.
func _plan() -> void:
	var drawn: PackedVector2Array = PackedVector2Array()
	for attempt: int in TRIES:
		drawn = _curve_through(_waypoints())
		if not _keeps_to_the_rules(drawn):
			continue
		var times: PackedFloat64Array = _timed(drawn)
		if not times.is_empty():
			_take(drawn, times)
			return
	_take(drawn, _timed(drawn, true))


func _take(drawn: PackedVector2Array, times: PackedFloat64Array) -> void:
	_points = PackedVector2Array()
	for point: Vector2 in drawn:
		_points.append(point - _touch)
	_times = times


## The points a route passes through, on the screen: his chest, over the window's corner,
## two or three points round the far side, back over the corner and his chest again.
func _waypoints() -> PackedVector2Array:
	var box: Rect2 = _route_box()
	var keep_out: Rect2 = _keep_out()
	# How far out from his middle, toward the far side, each part of the far side lies.
	var screen_edge: float = (box.end.x - _touch.x) if _side > 0 else (_touch.x - box.position.x)
	var window_side: float = _window.size.x / 2
	var past_window: float = keep_out.size.x / 2 + INSET
	var over_top: Vector2 = Vector2(box.position.y, keep_out.position.y - CORNER_HEIGHT)
	var lowest: float = minf(box.end.y, _lowest()) - INSET
	var corner: Vector2 = Vector2(window_side + CORNER_REACH.x, minf(window_side + CORNER_REACH.y, screen_edge))
	var over_corner: Vector2 = Vector2(_random.randf_range(corner.x, corner.y), _random.randf_range(over_top.x, over_top.y))
	var points: PackedVector2Array = PackedVector2Array([_touch, _out(over_corner.x, over_corner.y)])
	var far: Array[Vector2] = []
	for point: int in _random.randi_range(FAR_POINTS.x, FAR_POINTS.y):
		far.append(Vector2(_random.randf_range(past_window, screen_edge - INSET),
				_random.randf_range(box.position.y + INSET, lowest)))
	# Round the far side from the corner: out along the top, down its outside, back along the
	# bottom and up its inside, so that it wanders in a loop and never doubles back.
	var middle: Vector2 = Vector2((past_window + screen_edge) / 2, (box.position.y + lowest) / 2)
	var start: float = (over_corner - middle).angle()
	far.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return posmod((a - middle).angle() - start, TAU) < posmod((b - middle).angle() - start, TAU))
	for point: Vector2 in far:
		points.append(_out(point.x, point.y))
	points.append(_out(_random.randf_range(corner.x, corner.y), _random.randf_range(over_top.x, over_top.y)))
	points.append(_touch)
	return points


## The point [param out] from his middle toward the far side, at [param y] down the screen.
func _out(out: float, y: float) -> Vector2:
	return Vector2(_touch.x + _side * out, y)


## A smooth curve through [param points], sampled: leaving his chest toward the far side
## and coming back to it toward the other, level both times. Through each point between, it
## heads halfway between the ways in and out, and each leg leans on its ends only as hard as
## it is long, so that a short leg cannot loop.
func _curve_through(points: PackedVector2Array) -> PackedVector2Array:
	var last: int = points.size() - 1
	var headings: PackedVector2Array = PackedVector2Array()
	headings.resize(points.size())
	headings[0] = Vector2(_side, 0)
	headings[last] = Vector2(-_side, 0)
	for at: int in range(1, last):
		var way_in: Vector2 = (points[at] - points[at - 1]).normalized()
		var way_out: Vector2 = (points[at + 1] - points[at]).normalized()
		var between: Vector2 = way_in + way_out
		headings[at] = between.normalized() if between.length() > 0.001 else way_out
	var samples: PackedVector2Array = PackedVector2Array()
	for leg: int in last:
		var length: float = points[leg].distance_to(points[leg + 1])
		var leaving: Vector2 = headings[leg] * length
		var arriving: Vector2 = headings[leg + 1] * length
		for step: int in SAMPLES_PER_LEG:
			var t: float = float(step) / SAMPLES_PER_LEG
			var t2: float = t * t
			var t3: float = t2 * t
			samples.append(points[leg] * (2 * t3 - 3 * t2 + 1) + leaving * (t3 - 2 * t2 + t)
					+ points[leg + 1] * (-2 * t3 + 3 * t2) + arriving * (t3 - t2))
	samples.append(points[last])
	return samples


## Whether [param samples] keep to the screen, off the window, above its bottom and on their
## own side of him, turning nowhere sharply.
func _keeps_to_the_rules(samples: PackedVector2Array) -> bool:
	var box: Rect2 = _route_box()
	var keep_out: Rect2 = _keep_out()
	var lowest: float = _lowest()
	for point: Vector2 in samples:
		if point.x < box.position.x or point.x > box.end.x or point.y < box.position.y or point.y > box.end.y:
			return false
		if keep_out.has_point(point) or point.y > lowest:
			return false
		if _side * (point.x - _touch.x) < -0.01:
			return false
	for at: int in range(1, samples.size() - 1):
		var before: Vector2 = samples[at] - samples[at - 1]
		var after: Vector2 = samples[at + 1] - samples[at]
		var length: float = (before.length() + after.length()) / 2
		if length < 0.001 or absf(before.angle_to(after)) > length / TIGHTEST_TURN:
			return false
	return true


## How long after the touch the Wisp passes each of [param samples], paced so that it leaves
## and reaches him at [constant TOUCH_SPEED], is slowest at its far turn and arrives on time;
## empty if no such pace is gentle enough, unless [param anyway].
func _timed(samples: PackedVector2Array, anyway: bool = false) -> PackedFloat64Array:
	var count: int = samples.size()
	var along: PackedFloat64Array = PackedFloat64Array([0.0])
	var far: int = 0
	for at: int in range(1, count):
		along.append(along[at - 1] + samples[at].distance_to(samples[at - 1]))
		if samples[at].distance_squared_to(_touch) > samples[far].distance_squared_to(_touch):
			far = at
	var whole: float = along[count - 1]
	var turn: float = along[far]
	if not anyway and (turn <= 0.0 or turn >= whole):
		return PackedFloat64Array()
	# Each leg's pace is its base, slowing toward the far turn, and a share of a lift that
	# is found to make the whole route take as long as it has.
	var lengths: PackedFloat64Array = PackedFloat64Array()
	var bases: PackedFloat64Array = PackedFloat64Array()
	var lifts: PackedFloat64Array = PackedFloat64Array()
	for at: int in count - 1:
		var middle: float = (along[at] + along[at + 1]) / 2
		var toward_turn: float = middle / maxf(turn, 0.001) if middle <= turn else (whole - middle) / maxf(whole - turn, 0.001)
		lengths.append(along[at + 1] - along[at])
		bases.append(TOUCH_SPEED * (1.0 - (1.0 - FAR_SLOWING) * toward_turn * toward_turn))
		lifts.append(pow(sin(PI * toward_turn), 2))
	if not anyway and _duration(lengths, bases, lifts, 0.0) < _seconds:
		return PackedFloat64Array()
	var low: float = 0.0
	var high: float = 1.0
	while _duration(lengths, bases, lifts, high) > _seconds and high < 100000.0:
		high *= 2.0
	for halving: int in 40:
		var lift: float = (low + high) / 2
		if _duration(lengths, bases, lifts, lift) > _seconds:
			low = lift
		else:
			high = lift
	var times: PackedFloat64Array = PackedFloat64Array([0.0])
	var speeds: PackedFloat64Array = PackedFloat64Array()
	for at: int in lengths.size():
		var speed: float = bases[at] + high * lifts[at]
		speeds.append(speed)
		times.append(times[at] + lengths[at] / speed)
	if not anyway:
		for at: int in speeds.size():
			if speeds[at] > TOP_SPEED:
				return PackedFloat64Array()
			if at > 0 and absf(speeds[at] - speeds[at - 1]) / (times[at + 1] - times[at - 1]) * 2 > STEEPEST_CHANGE:
				return PackedFloat64Array()
	# Exactly as long as it has, whatever the halving left over.
	var scale: float = _seconds / times[times.size() - 1]
	for at: int in times.size():
		times[at] *= scale
	return times


static func _duration(lengths: PackedFloat64Array, bases: PackedFloat64Array, lifts: PackedFloat64Array, lift: float) -> float:
	var total: float = 0.0
	for at: int in lengths.size():
		total += lengths[at] / (bases[at] + lift * lifts[at])
	return total


## Where a route's middle may go on the screen: far enough inside its edges that the Wisp,
## bobbing, stays inside the margin.
func _route_box() -> Rect2:
	return _screen.grow(-(MARGIN + SIZE / 2 + BOB))


## Where a route's middle may never go: so near the window that the Wisp, bobbing, would
## come closer to it than [constant CLEARANCE].
func _keep_out() -> Rect2:
	return _window.grow(SIZE / 2 + BOB + CLEARANCE)


## The lowest a route's middle may go: high enough that the Wisp, bobbing, stays above the
## window's bottom.
func _lowest() -> float:
	return _window.end.y - SIZE / 2 - BOB


## Where the bob has drifted to at [param seconds] on its own clock: between one random point
## and the next, eased, a new one every second or two.
func _bob_at(seconds: float) -> Vector2:
	if _bob_times.is_empty():
		_bob_times.append(minf(seconds, 0.0))
		_bob_keys.append(_random_bob())
	while _bob_times.back() <= seconds:
		_bob_times.append(_bob_times.back() + _bob_random.randf_range(BOB_SECONDS.x, BOB_SECONDS.y))
		_bob_keys.append(_random_bob())
	while _bob_times.size() > 2 and _bob_times[1] <= seconds:
		_bob_times.pop_front()
		_bob_keys.pop_front()
	return _bob_keys[0].lerp(_bob_keys[1], smoothstep(_bob_times[0], _bob_times[1], seconds))


func _random_bob() -> Vector2:
	return Vector2.from_angle(_bob_random.randf() * TAU) * BOB * sqrt(_bob_random.randf())
