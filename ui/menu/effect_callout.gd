class_name EffectCallout
extends RefCounted
## One Effect Callout: an Effect Animation's words in its flash's color, appearing just
## outside the Menu Soldier's square in a direction out from the middle of his upper half,
## anywhere from level with it on either side to straight over his head. They float on that
## way for two seconds, slowing, wiggling across their way and rocking a little as they go,
## and fade in over his flash and out to nothing. A callout is placed relative to his square,
## so that it goes with him if the screen is resized.

const FONT_SIZE: int = 24
## How strongly the words show at most: ghostly.
const STRENGTH: float = 0.75
## How far outside his square the words' nearest edge is as they appear.
const GAP: float = 8.0
## How far inside the screen's edges they stay for their whole flight.
const MARGIN: float = 16.0
## How far they float, and for how long.
const DRIFT: float = 64.0
const SECONDS: float = 2.0
## How long they take to fade in: about as long as his flash.
const FADE_IN: float = 0.12
## The farthest they wiggle across their way, and the lengths of the two wiggles that make
## it, a slow one and a quick one.
const SWAY: float = 6.0
const SWAY_SECONDS: Vector2 = Vector2(0.9, 0.37)
const QUICK_SWAY: float = 0.5
## The farthest they rock either way (5 degrees), and how long a rock there and back takes.
const ROCK: float = PI / 36.0
const ROCK_SECONDS: float = 1.3
## How long the wiggling and rocking take to build up after they appear.
const SETTLE: float = 0.4
## How many places are tried before giving up and putting them level beside him, and how
## many moments of each flight are checked.
const TRIES: int = 200
const SAMPLES: int = 40

var _words: String
var _color: Color
var _born: float
var _direction: Vector2
var _size: Vector2
## Where their middle is as they appear, from the middle of his upper half.
var _start: Vector2
## Where in its wiggle or rock each of the slow wiggle, the quick one and the rock starts.
var _phases: Array[float]


## A callout of [param words] in [param color], appearing [param born] seconds into his
## sequence and floating off at [param angle] (0 to the right, a half turn to the left, a
## quarter turn straight up), its wiggles and rock starting at [param phases].
func _init(words: String, color: Color, born: float, angle: float, phases: Array[float]) -> void:
	_words = words
	_color = color
	_born = born
	_direction = Vector2(cos(angle), -sin(angle))
	_size = UiText.bold().get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).ceil()
	_phases = phases
	# Out along its way until the words clear his side, or his top, by the gap.
	var his: float = MenuSoldier.SPRITE_SIZE * MenuSoldier.SCALE
	var out: float = INF
	if absf(_direction.x) > 0.0001:
		out = (his / 2 + _size.x / 2 + GAP) / absf(_direction.x)
	if _direction.y < -0.0001:
		out = minf(out, (his / 4 + _size.y / 2 + GAP) / -_direction.y)
	_start = _direction * out


## The callout for [param effect], which he flashed [param born] seconds into his sequence,
## standing in [param square] on [param screen]: placed at random where the whole of its
## flight keeps clear of him and inside the screen, or level beside him if nowhere does.
static func placed(effect: String, born: float, square: Rect2, screen: Rect2, random: RandomNumberGenerator) -> EffectCallout:
	var words: String = SoldierAnimations.words_of(effect)
	var color: Color = SoldierAnimations.color_of(effect)
	for _try: int in TRIES:
		var made: EffectCallout = EffectCallout.new(words, color, born, random.randf_range(0.0, PI), _phases_from(random))
		if made.keeps_to(square, screen):
			return made
	return EffectCallout.new(words, color, born, PI * random.randi_range(0, 1), _phases_from(random))


## The middle of the upper half of [param square], his square, from which callouts float off.
static func upper_middle(square: Rect2) -> Vector2:
	return square.position + Vector2(square.size.x / 2, square.size.y / 4)


func words() -> String:
	return _words


func color() -> Color:
	return _color


## How far into his sequence it appeared, in seconds: the moment he flashed.
func born() -> float:
	return _born


## The way it floats off, as a step of one pixel.
func direction() -> Vector2:
	return _direction


## Whether it has faded out, [param age] seconds after it appeared.
func is_over(age: float) -> bool:
	return age >= SECONDS


## Where the words' middle is [param age] seconds after they appeared, with him standing in
## [param square].
func middle(square: Rect2, age: float) -> Vector2:
	var gone: float = clampf(age / SECONDS, 0.0, 1.0)
	var travelled: float = DRIFT * (1.0 - (1.0 - gone) * (1.0 - gone))
	return upper_middle(square) + _start + _direction * travelled + _direction.orthogonal() * _sway(age)


## Where the words are drawn then, on whole pixels, before they are turned as they rock.
func drawn_rect(square: Rect2, age: float) -> Rect2:
	return Rect2((middle(square, age) - _size / 2).round(), _size)


## How far the words are turned then, in radians, as they rock about their middle.
func angle(age: float) -> float:
	return ROCK * _settled(age) * sin(TAU * age / ROCK_SECONDS + _phases[2])


## The box the words cover then, turned as they are.
func bounds(square: Rect2, age: float) -> Rect2:
	var drawn: Rect2 = drawn_rect(square, age)
	var turn: float = angle(age)
	var across: float = absf(cos(turn))
	var up: float = absf(sin(turn))
	var reach: Vector2 = Vector2(_size.x * across + _size.y * up, _size.x * up + _size.y * across)
	return Rect2(drawn.get_center() - reach / 2, reach)


## How strongly the words show then.
func opacity(age: float) -> float:
	if age <= 0.0 or is_over(age):
		return 0.0
	return STRENGTH * minf(age / FADE_IN, 1.0) * (1.0 - smoothstep(0.0, SECONDS, age))


## Whether the whole of its flight keeps clear of [param square] and inside [param screen].
func keeps_to(square: Rect2, screen: Rect2) -> bool:
	var inside: Rect2 = screen.grow(-MARGIN)
	for sample: int in SAMPLES + 1:
		var covered: Rect2 = bounds(square, SECONDS * sample / SAMPLES)
		if not inside.encloses(covered) or covered.intersects(square):
			return false
	return true


## How far the words have wiggled across their way then.
func _sway(age: float) -> float:
	var slow: float = sin(TAU * age / SWAY_SECONDS.x + _phases[0])
	var quick: float = sin(TAU * age / SWAY_SECONDS.y + _phases[1])
	return SWAY * _settled(age) * (slow + QUICK_SWAY * quick) / (1.0 + QUICK_SWAY)


## How far the wiggling and rocking have built up then.
func _settled(age: float) -> float:
	return smoothstep(0.0, SETTLE, age)


static func _phases_from(random: RandomNumberGenerator) -> Array[float]:
	return [random.randf_range(0.0, TAU), random.randf_range(0.0, TAU), random.randf_range(0.0, TAU)]
