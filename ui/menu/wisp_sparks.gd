class_name WispSparks
extends RefCounted
## The Wisp Sparks: the trail of sparks the Wisp leaves wherever it goes. Each appears in
## the Wisp's middle, in the Wisp's color as it is emitted and as faint as the Wisp then
## is, and flies out of it at a random angle all the way round, drifting a little off
## straight and with none of the Wisp's own motion, falling ever faster as it fades out.
## One that falls onto the main menu's window comes to rest on its top, on the step of a
## stepped corner, and fades out there; one that misses falls on past it, and none drifts
## onto the window's side.

## A spark is one of the Wisp's pixels, square.
const SIZE: float = MenuSoldier.SCALE
## How many sparks it leaves a second.
const PER_SECOND: float = 16.0
## How long a spark takes to fade out, at least and at most.
const LIFE: Vector2 = Vector2(0.8, 1.4)
## How fast a spark flies straight out of the Wisp at first, at least and at most, and the
## fastest it drifts in a random direction besides.
const SPEED: Vector2 = Vector2(20.0, 40.0)
const DRIFT: float = 40.0
## How fast a spark's fall quickens, in pixels a second each second.
const GRAVITY: float = 260.0


## One spark: where its middle is and how it moves, in screen pixels.
class Spark:
	var position: Vector2
	var velocity: Vector2
	var color: Color
	## How strongly it showed as it was emitted, the Wisp's own opacity then.
	var strength: float
	var age: float = 0.0
	var life: float
	var is_landed: bool = false

	## How strongly it shows now: fading from its strength to nothing over its life.
	func opacity() -> float:
		return strength * (1.0 - clampf(age / life, 0.0, 1.0))

	## Where it is drawn now, on whole pixels.
	func drawn_rect() -> Rect2:
		return Rect2((position - Vector2.ONE * WispSparks.SIZE / 2).round(), Vector2.ONE * WispSparks.SIZE)


var _random: RandomNumberGenerator
var _sparks: Array[Spark] = []
## How many sparks are owed but not yet emitted, in parts of one.
var _owed: float = 0.0


## Sparks that make their random choices with [param random].
func _init(random: RandomNumberGenerator) -> void:
	_random = random


## The sparks still showing, oldest first.
func sparks() -> Array[Spark]:
	return _sparks


## Leaves as many sparks as are due over [param seconds] about the Wisp's middle
## [param at], in [param color], as strong as [param strength].
func trail(seconds: float, at: Vector2, color: Color, strength: float) -> void:
	_owed += seconds * PER_SECOND
	while _owed >= 1.0:
		_owed -= 1.0
		emit(at, color, strength)


## Leaves one spark in the middle of the Wisp, [param at], flying out of it at a random
## angle and drifting, in [param color], as strong as [param strength].
func emit(at: Vector2, color: Color, strength: float) -> void:
	var made: Spark = Spark.new()
	var outward: Vector2 = Vector2.from_angle(_random.randf() * TAU)
	var drift: Vector2 = Vector2.from_angle(_random.randf() * TAU) * DRIFT * sqrt(_random.randf())
	made.position = at
	made.velocity = outward * _random.randf_range(SPEED.x, SPEED.y) + drift
	made.color = color
	made.strength = strength
	made.life = _random.randf_range(LIFE.x, LIFE.y)
	_sparks.append(made)


## Moves every spark on by [param seconds], landing those that fall onto [param window]'s
## top, and lets go of those that have faded out.
func advance(seconds: float, window: Rect2) -> void:
	var kept: Array[Spark] = []
	for spark: Spark in _sparks:
		spark.age += seconds
		if spark.age >= spark.life:
			continue
		kept.append(spark)
		if not spark.is_landed:
			_fall(spark, seconds, window)
	_sparks = kept


## The height of [param window]'s top at the column [param x] across the screen: lower on
## its stepped corners, and INF off its sides.
static func top_at(window: Rect2, x: float) -> float:
	var column: int = floori(x - window.position.x)
	var width: int = int(window.size.x)
	if column < 0 or column >= width:
		return INF
	@warning_ignore("integer_division")
	var steps_up: int = mini(column, width - 1 - column) / WindowLook.RIM_BAND
	return window.position.y + maxi(WindowLook.CORNER_STEPS - steps_up, 0) * WindowLook.RIM_BAND


func _fall(spark: Spark, seconds: float, window: Rect2) -> void:
	var half: float = SIZE / 2
	spark.velocity.y += GRAVITY * seconds
	var next: Vector2 = spark.position + spark.velocity * seconds
	var top: float = _highest_under(window, next.x)
	if top < INF:
		if spark.position.y + half > top:
			# Beside the window and below its top: it slides down the side, never onto it.
			next.x = window.position.x - half if spark.position.x < window.get_center().x else window.end.x + half
			spark.velocity.x = 0.0
		elif next.y + half >= top:
			spark.position = Vector2(next.x, top - half)
			spark.velocity = Vector2.ZERO
			spark.is_landed = true
			return
	spark.position = next


## The highest the window's top comes under a spark whose middle is at [param x]: the
## column under it nearest the window's middle. INF if it is wholly off the window.
func _highest_under(window: Rect2, x: float) -> float:
	var left: float = x - SIZE / 2
	var right: float = x + SIZE / 2 - 1
	if right < window.position.x or left >= window.end.x:
		return INF
	return top_at(window, clampf(window.get_center().x, left, right))

